#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Rofi en Alpine está en community; usar repo temporal de la misma versión.
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
if command -v rofi >/dev/null 2>&1; then
    echo 'Rofi ya está instalado. No hace falta modificar paquetes.'
    exit 0
fi
release=${LT_OS_RELEASE:-/etc/os-release}
[ -r "$release" ] || { echo 'Error: no se puede identificar la distribución.' >&2; exit 1; }
. "$release"
case "$ID" in
    alpine)
        major=${VERSION_ID%%.*}
        tail_version=${VERSION_ID#*.}
        minor=${tail_version%%.*}
        case "$major:$minor" in
            *[!0-9:]*|:*|*:) echo 'Error: versión Alpine inválida.' >&2; exit 1 ;;
        esac
        repo="https://dl-cdn.alpinelinux.org/alpine/v$major.$minor/community"
        packages=rofi-x11-wayland
        echo "Alpine: $packages desde $repo (temporal)."
        ;;
    debian|ubuntu)
        packages=rofi
        echo 'Debian/Ubuntu: rofi desde apt.'
        ;;
    *) echo "Error: distro no soportada: $ID" >&2; exit 1 ;;
esac
if [ "$dry_run" -eq 1 ]; then echo 'Simulación: no se modificarán paquetes.'; exit 0; fi
if [ "$assume_yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Error: se requiere confirmación o --yes.' >&2; exit 2; }
    printf '¿Instalar Rofi? [s/N]: '
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi
admin() {
    binary=$(lt_admin_path "$1") || return 1
    shift
    if [ "$(id -u)" -eq 0 ]; then
        "$binary" "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$binary" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$binary" "$@"
    else
        echo 'Error: necesitás doas/sudo para instalar Rofi; no se configurará un elevador automáticamente.' >&2
        return 1
    fi
}
if [ "$ID" = alpine ]; then
    admin apk add --no-cache --repository "$repo" $packages
else
    admin apt-get install -y $packages
fi
command -v rofi >/dev/null 2>&1 || {
    echo 'Error: Rofi se instaló pero no apareció su ejecutable.' >&2
    exit 1
}
echo 'Rofi instalado. Los menús se abren dentro de una sesión gráfica mediante lt-rofi.'
