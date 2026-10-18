#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Ejecutar SIEMPRE como usuario normal: eleva solo el módulo de doas.
set -eu

base=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
dry_run=0
assume_yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --yes) assume_yes=1 ;;
        *) echo "Error: argumento desconocido: $1" >&2; exit 2 ;;
    esac
    shift
done

username=$(id -un)
if [ "$username" = root ]; then
    echo 'Error: no ejecutes linux-tools completo como root.' >&2
    echo 'Usá el instalador como usuario normal; para ejecución manual como root consultá modules/doas/root-setup.sh.' >&2
    exit 1
fi
# Evita interpolar nombres peligrosos en el comando que ejecutará su.
if ! printf '%s\n' "$username" | grep -Eq '^[a-z_][a-z0-9_-]*$'; then
    echo "Error: nombre de usuario no admitido para configuración automática: $username" >&2
    exit 1
fi

if [ "$dry_run" -eq 1 ]; then
    sh "$base/modules/doas/root-setup.sh" --user "$username" --dry-run
    exit 0
fi

printf 'Se configurará doas para que %s pueda ejecutar órdenes como root CON contraseña.\n' "$username"
echo 'La política solo autoriza a este usuario; no habilita nopass ni modifica wheel.'
if [ "$assume_yes" -eq 0 ]; then
    if [ ! -t 0 ]; then
        echo 'Error: se requiere terminal interactiva o --yes para confirmar.' >&2
        exit 2
    fi
    printf '¿Instalar doas y conceder estos permisos? [s/N]: '
    IFS= read -r confirmacion || confirmacion=''
    case "$confirmacion" in
        s|S|si|Si|SI) : ;;
        *) echo 'Operación cancelada.'; exit 2 ;;
    esac
fi

# Usa la contraseña de root (su), porque doas todavía no está configurado.
# El módulo con privilegios se envía por stdin para evitar interpolar rutas
# del usuario en la orden ejecutada por root.
if ! command -v su >/dev/null 2>&1; then
    echo 'Error: falta su. Ingresá como root y ejecutá modules/doas/root-setup.sh --user TU_USUARIO.' >&2
    exit 1
fi
echo 'Autenticación: ingresá la contraseña de root solicitada por su.'
su -c "sh -s -- --user $username --yes" root < "$base/modules/doas/root-setup.sh"

echo 'Verificación final:'
if command -v doas >/dev/null 2>&1; then
    doas id -u
else
    echo 'Aviso: doas se instaló pero no aparece en PATH. Abrí otra terminal.' >&2
    exit 1
fi
