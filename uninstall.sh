#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$root/lib/common.sh"

modules=fish,rotate
dry_run=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) echo 'Uso: sh uninstall.sh [--modules fish,rotate] [--dry-run]'; exit 0 ;;
        --modules)
            [ "$#" -ge 2 ] || { echo 'Falta valor para --modules.' >&2; exit 2; }
            modules=$2; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
    esac
done
lt_parse_modules "$modules"
[ "$dry_run" -eq 1 ] || lt_require_user

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
plan="$config_home/fish/conf.d/linux-tools.fish"
if [ "$want_rotate" -eq 1 ]; then
    for name in rotar r0 r90 r180 r270; do
        plan="$plan
$config_home/fish/functions/$name.fish"
    done
fi
while IFS= read -r target; do
    [ -n "$target" ] || continue
    if [ -L "$target" ]; then
        echo "Omitido (enlace simbólico): $target"
    elif lt_source_owned "$target"; then
        if [ "$dry_run" -eq 1 ]; then
            echo "Eliminaría: $target"
        else
            rm "$target"
            echo "Eliminado: $target"
        fi
    elif [ -e "$target" ]; then
        echo "Omitido (no administrado): $target"
    fi
done <<EOF
$plan
EOF
echo 'Listo. No se desinstaló Fish ni se borraron backups.'
