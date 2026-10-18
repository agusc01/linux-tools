#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Prepara audio; solo solicita privilegios para operaciones del sistema.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
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

# Comprueba audio REAL, no basta con que el comando exista.
audio_ready() { "$root/bin/lt-volume" status >/dev/null 2>&1; }
if audio_ready; then
    echo 'Audio: backend operativo. No hace falta instalar otro.'
    exit 0
fi

packages=''
if ! command -v amixer >/dev/null 2>&1; then
    packages='alsa-utils'
    if [ "$manager" = apk ] && command -v rc-service >/dev/null 2>&1; then
        packages="$packages alsa-utils-openrc"
    fi
fi
username=$(id -un)
case "$username" in
    ''|*[!a-zA-Z0-9_-]*) echo 'Error: usuario no válido.' >&2; exit 1 ;;
esac

needs_group=0
if [ "$manager" = apk ] && grep -q '^audio:' /etc/group 2>/dev/null; then
    case " $(id -nG) " in
        *' audio '*) : ;;
        *) needs_group=1 ;;
    esac
fi
needs_service=0
if [ "$manager" = apk ] && command -v rc-service >/dev/null 2>&1; then
    needs_service=1
fi

echo "Audio: $manager; ALSA (en el repositorio main de Alpine)."
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
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v su >/dev/null 2>&1; then
        # Solo ejecuta subcomandos con nombres predefinidos.
        su -c "$*"
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
if [ "$needs_group" -eq 1 ]; then
    if command -v addgroup >/dev/null 2>&1; then
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
