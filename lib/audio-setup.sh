#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Prepara audio; solo solicita privilegios para operaciones del sistema.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/admin-paths.sh"
. "$root/lib/audio-hardware.sh"
dry_run=0
yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --yes) yes=1 ;;
        *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
    esac
    shift
done

os_release=${LT_OS_RELEASE:-/etc/os-release}
[ -r "$os_release" ] || { echo 'Error: falta /etc/os-release.' >&2; exit 1; }
. "$os_release"
case "${ID:-}" in
    alpine) manager=apk ;;
    debian|ubuntu) manager=apt-get ;;
    *) echo "Error: distribución no soportada: ${ID:-desconocida}" >&2; exit 1 ;;
esac

# Detectar hardware ANTES de considerar suficiente el HDMI u otro backend.
# Un servidor de audio operativo puede ocultar que faltan parlantes internos.
audio_ready() { "$root/bin/lt-volume" status >/dev/null 2>&1; }
sof_missing=0
if [ "$manager" = apk ] && lt_cherrytrail_nau8824; then
    lt_audio_cherrytrail_report
    if ! lt_audio_sof_ready; then sof_missing=1; fi
fi
if audio_ready && [ "$sof_missing" -eq 0 ]; then
    echo 'Audio: backend operativo y firmware requerido presente.'
    echo 'Para conservar tus ajustes del mezclador: lt-audio-save save (después de probar los parlantes).'
    exit 0
fi

packages=''
if ! command -v amixer >/dev/null 2>&1; then
    packages='alsa-utils'
    if [ "$manager" = apk ] && lt_admin_path rc-service >/dev/null 2>&1; then
        packages="$packages alsa-utils-openrc"
    fi
fi
username=$(id -un)
case "$username" in
    ''|*[!a-zA-Z0-9_-]*) echo 'Error: usuario no válido.' >&2; exit 1 ;;
esac

needs_group=0
if [ "$manager" = apk ] && grep -q '^audio:' /etc/group 2>/dev/null; then
    # Consultar la base de grupos, NO solo grupos activos del proceso.
    # Evita ejecutar addgroup de nuevo hasta que el usuario cierre sesión.
    group_line=$(grep '^audio:' /etc/group | head -n 1)
    members=${group_line##*:}
    case ",$members," in
        *,"$username",*) : ;;
        *) needs_group=1 ;;
    esac
    case " $(id -nG) " in
        *' audio '*) : ;;
        *) echo 'Aviso: el grupo audio todavía no está activo en esta sesión.' >&2 ;;
    esac
fi
needs_service=0
if [ "$manager" = apk ] && lt_admin_path rc-service >/dev/null 2>&1; then
    needs_service=1
fi

echo "Audio: $manager; ALSA (en el repositorio main de Alpine)." 
sof_repo=''
if [ "$sof_missing" -eq 1 ]; then
    # No mezclar paquetes de edge y stable; obtener la rama desde os-release.
    major=${VERSION_ID%%.*}
    minor_part=${VERSION_ID#*.}
    minor=${minor_part%%.*}
    case "$major:$minor" in
        *[!0-9:]*|:*|*:) echo 'Error: no se pudo determinar la versión estable de Alpine para instalar sof-firmware.' >&2; exit 1 ;;
    esac
    sof_repo="https://dl-cdn.alpinelinux.org/alpine/v$major.$minor/community"
    echo "Firmware SOF necesario: sof-firmware (repositorio temporal $sof_repo)."
    echo 'No se habilitará community permanentemente.'
fi
if [ -n "$packages" ]; then
    echo "Paquetes a instalar: $packages"
else
    echo 'Paquetes: alsa-utils ya está presente.'
fi
if [ "$needs_group" -eq 1 ]; then echo "Permisos: agregar $username al grupo audio."; fi
if [ "$needs_service" -eq 1 ]; then echo 'OpenRC: habilitar e iniciar alsa cuando exista el servicio.'; fi

if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: sin cambios de paquetes, permisos ni servicios.'
    exit 0
fi
if [ "$yes" -eq 0 ]; then
    if [ ! -t 0 ]; then
        echo 'Error: sin terminal interactiva. Usá --yes para autorizar los cambios.' >&2
        exit 2
    fi
    printf '¿Aplicar estos cambios de audio? [s/N]: '
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|Si|SI|sí|Sí) : ;; *) echo 'Cancelado sin cambiar el sistema.'; exit 2 ;; esac
fi
as_root() {
    [ "$#" -gt 0 ] || return 2
    # La elevación puede restringir PATH: nunca invocar 'apk' por nombre.
    # Ej.: Alpine mantiene apk en /sbin/apk, fuera del PATH de doas.
    binary=$(lt_admin_path "$1") || return 1
    shift
    if [ "$(id -u)" -eq 0 ]; then
        "$binary" "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$binary" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$binary" "$@"
    elif command -v su >/dev/null 2>&1; then
        # Argumentos limitados a opciones, paquetes y usuario validado,
        # sin interpretar caracteres de shell.
        for argument in "$binary" "$@"; do
            case "$argument" in
                *[!a-zA-Z0-9_./:-]*|'') echo 'Error: argumento administrativo no permitido.' >&2; return 2 ;;
            esac
        done
        # El comando es una ruta absoluta y todos sus argumentos son seguros.
        su -c "$binary $*"
    else
        echo 'Error: se requiere doas, sudo o su para configurar audio.' >&2
        return 1
    fi
}

if [ -n "$packages" ]; then
    if [ "$manager" = apk ]; then
        as_root apk add --no-cache $packages
    else
        as_root apt-get install -y $packages
    fi
fi
if [ "$sof_missing" -eq 1 ]; then
    # --repository afecta solamente esta operación; preserva /etc/apk/repositories.
    as_root apk add --no-cache --repository "$sof_repo" sof-firmware
    if lt_audio_sof_ready; then
        echo 'OK: firmware sof-cht.ri y topología sof-cht-nau8824.tplg encontrados.'
    else
        echo 'Error: sof-firmware se instaló pero no proporciona los dos archivos requeridos.' >&2
        exit 1
    fi
    echo 'IMPORTANTE: reiniciá para que SOF vuelva a detectar la tarjeta NAU8824.'
fi
if [ "$needs_group" -eq 1 ]; then
    if lt_admin_path addgroup >/dev/null 2>&1; then
        as_root addgroup "$username" audio
    else
        echo 'Aviso: falta addgroup; configurá el grupo audio manualmente.' >&2
    fi
    echo 'IMPORTANTE: cerrá sesión y volvé a entrar para actualizar los grupos.'
fi
if [ "$needs_service" -eq 1 ]; then
    if [ -f /etc/init.d/alsa ]; then
        as_root rc-update add alsa default || echo 'Aviso: no se pudo habilitar alsa en OpenRC.' >&2
        as_root rc-service alsa start || echo 'Aviso: no arrancó alsa, revisá /dev/snd.' >&2
    else
        echo 'Aviso: no existe el servicio /etc/init.d/alsa.' >&2
    fi
fi
if audio_ready; then
    echo 'OK: lt-volume ya reconoce un backend operativo.'
else
    echo 'Aviso: dependencias preparadas pero todavía no hay una salida de audio accesible.' >&2
    echo 'Probá: aplay -l; alsamixer; id -nG; cat /proc/asound/cards' >&2
    echo 'Si se modificó el grupo audio, iniciá una nueva sesión y repetí lt-volume status.' >&2
    echo 'Los archivos de linux-tools se instalarán, pero la verificación final seguirá marcando el audio como no disponible.' >&2
fi
if [ "$manager" = apk ] && lt_cherrytrail_nau8824; then
    if [ "$(lt_audio_acpi_status)" != 15 ]; then
        echo 'ATENCIÓN: configurá LPE Audio ACPI mode desde la BIOS; no es posible automatizarlo.' >&2
    fi
    if ! lt_audio_internal_card; then
        echo 'ATENCIÓN: aún no aparece NAU8824 en ALSA. Reiniciá y verificá con aplay -l.' >&2
    else
        echo 'NAU8824 detectado. Probá alsamixer -c 0, speaker-test, y guardá con lt-audio-save save.'
    fi
fi
