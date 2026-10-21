#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# xsetroot para señales de dwm. Alpine lo empaqueta en community:
# solo se añade ese repositorio durante esta operación.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/admin-paths.sh"
dry_run=0
assume_yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --yes) assume_yes=1 ;;
        *) echo "Opción desconocida: $1" >&2; exit 2 ;;
    esac
    shift
done
if command -v xsetroot >/dev/null 2>&1; then
    echo 'xsetroot ya está instalado.'
    exit 0
fi
release=${LT_OS_RELEASE:-/etc/os-release}
[ -r "$release" ] || { echo 'Error: no se puede detectar la distribución.' >&2; exit 1; }
. "$release"
case "$ID" in
    alpine)
        major=${VERSION_ID%%.*}
        rest=${VERSION_ID#*.}
        minor=${rest%%.*}
        case "$major:$minor" in
            *[!0-9:]*|:*|*:) echo 'Error: versión Alpine inválida.' >&2; exit 1 ;;
        esac
        repository="https://dl-cdn.alpinelinux.org/alpine/v$major.$minor/community"
        echo "Alpine: xsetroot desde $repository (repo temporal)."
        ;;
    debian|ubuntu)
        echo 'Debian/Ubuntu: x11-xserver-utils desde apt.'
        ;;
    *) echo "Distribución no soportada: $ID" >&2; exit 1 ;;
esac
if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: se prepararía xsetroot sin modificar repositorios.'
    exit 0
fi
if [ "$assume_yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Se necesita confirmación o --yes.' >&2; exit 2; }
    printf '¿Instalar xsetroot para los atajos de dwm? [s/N]: '
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi
admin() {
    binary=$(lt_admin_path "$1") || return 1
    shift
    if [ "$(id -u)" -eq 0 ]; then "$binary" "$@"
    elif command -v doas >/dev/null 2>&1; then doas "$binary" "$@"
    elif command -v sudo >/dev/null 2>&1; then sudo "$binary" "$@"
    else echo 'Se requiere doas/sudo; no se cambia ninguna política de permisos.' >&2; return 1
    fi
}
case "$ID" in
    alpine) admin apk add --no-cache --repository "$repository" xsetroot ;;
    debian|ubuntu) admin apt-get install -y x11-xserver-utils ;;
esac
command -v xsetroot >/dev/null 2>&1 || {
    echo 'Error: el paquete no proporcionó xsetroot.' >&2
    exit 1
}
echo 'xsetroot listo para señales de dwm.'
