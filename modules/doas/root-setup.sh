#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Configurador aislado de privilegios. Uso directo: su - ; sh root-setup.sh --user TU_USUARIO
set -eu
umask 077

username=''
dry_run=0
assume_yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --user)
            [ "$#" -ge 2 ] || { echo 'Error: falta usuario.' >&2; exit 2; }
            username=$2; shift ;;
        --dry-run) dry_run=1 ;;
        --yes) assume_yes=1 ;;
        *) echo "Error: argumento desconocido: $1" >&2; exit 2 ;;
    esac
    shift
done

if ! printf '%s\n' "$username" | grep -Eq '^[a-z_][a-z0-9_-]*$'; then
    echo 'Error: indicá un usuario local válido con --user.' >&2
    exit 2
fi
[ "$username" != root ] || { echo 'Error: no se configura doas para root.' >&2; exit 2; }
id -u "$username" >/dev/null 2>&1 || { echo "Error: el usuario $username no existe." >&2; exit 1; }

release=/etc/os-release
# Un override solo para pruebas en dry-run; nunca cambia un sistema real.
if [ "$dry_run" -eq 1 ] && [ -n "$(printenv LT_DOAS_OS_RELEASE || :)" ]; then
    release=$(printenv LT_DOAS_OS_RELEASE)
fi
[ -r "$release" ] || { echo 'Error: no se puede leer os-release.' >&2; exit 1; }
. "$release"
case "$ID" in
    alpine) manager=apk; destination=/etc/doas.d/90-linux-tools.conf ;;
    debian|ubuntu) manager=apt-get; destination=/etc/doas.conf ;;
    *) echo "Error: distribución no soportada: $ID" >&2; exit 1 ;;
esac

rule="permit $username as root"
echo "Distribución: $ID; gestor: $manager"
echo "Paquete: doas; destino: $destination"
echo "Política: $rule (solicita contraseña de $username; acceso administrativo completo)"
if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: no se modificó ningún archivo.'
    exit 0
fi
[ "$(id -u)" -eq 0 ] || { echo 'Error: este módulo necesita root. Usá su - o el instalador normal.' >&2; exit 1; }

if [ "$assume_yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Error: usá --yes tras confirmar los privilegios.' >&2; exit 2; }
    printf '¿Conceder privilegios administrativos a %s? [s/N]: ' "$username"
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi

# Evita romper una configuración de doas preexistente, nunca borra sus reglas.
if [ "$ID" = alpine ] && [ -e "$destination" ]; then
    [ ! -L "$destination" ] && [ -f "$destination" ] || {
        echo "Conflicto: $destination no es un archivo normal." >&2; exit 1;
    }
    if grep -Fxq "$rule" "$destination" && grep -Fxq '# linux-tools-managed: agusc01/linux-tools' "$destination"; then
        echo 'Configuración de doas ya administrada; no hay cambios.'
        exit 0
    fi
    echo "Conflicto: $destination existe y no coincide. No se sobrescribe." >&2
    exit 1
fi
if [ "$ID" != alpine ] && [ -e "$destination" ]; then
    [ ! -L "$destination" ] && [ -f "$destination" ] || {
        echo "Conflicto: $destination no es un archivo normal." >&2; exit 1;
    }
    if grep -Fxq "$rule" "$destination"; then
        echo 'La regla ya existe en doas.conf; no hay cambios.'
        exit 0
    fi
fi

if ! command -v doas >/dev/null 2>&1; then
    if [ "$manager" = apk ]; then
        apk add doas
    else
        apt-get install -y doas
    fi
fi
command -v doas >/dev/null 2>&1 || { echo 'Error: el paquete se instaló, pero doas no está en PATH.' >&2; exit 1; }

directory=$(dirname "$destination")
mkdir -p "$directory"
temporary=$(mktemp "$directory/.linux-tools-doas.XXXXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM
if [ "$ID" = alpine ]; then
    printf '%s\n' '# linux-tools-managed: agusc01/linux-tools' "$rule" > "$temporary"
else
    if [ -f "$destination" ]; then
        cat "$destination" > "$temporary"
        printf '\n' >> "$temporary"
    fi
    printf '%s\n' '# linux-tools-managed: agusc01/linux-tools' "$rule" >> "$temporary"
fi
chmod 600 "$temporary"

# Validar ANTES de publicar para no bloquear las próximas elevaciones.
doas -C "$temporary" >/dev/null || {
    echo 'Error: doas rechazó la política; no se modificó la configuración.' >&2
    exit 1
}

if [ -f "$destination" ]; then
    backupdir=/var/backups/linux-tools
    mkdir -p "$backupdir"
    chmod 700 "$backupdir"
    backup=$(mktemp "$backupdir/doas.XXXXXXXX")
    cp -p "$destination" "$backup"
    chmod 600 "$backup"
    echo "Backup guardado: $backup"
fi
mv -f "$temporary" "$destination"
trap - EXIT HUP INT TERM
echo "Configuración instalada en $destination"
echo 'La próxima vez podés ejecutar: doas apk add PAQUETE (o doas apt-get install PAQUETE).'
