#!/bin/sh
# linux-tools-managed: agusc01/linux-tools

lt_source_owned() {
    [ -f "$1" ] && grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$1"
}
lt_old_rotate() {
    [ -f "$1" ] && grep -Fqx '# rotate-managed: agusc01/rotate' "$1"
}
lt_require_user() {
    if [ "$(id -u)" -eq 0 ]; then
        echo 'Error: ejecutá como usuario normal, sin sudo ni su.' >&2
        exit 1
    fi
}
lt_parse_modules() {
    requested=$1
    want_rotate=0
    [ -n "$requested" ] || { echo 'Error: --modules requiere lista.' >&2; exit 2; }
    remaining=$requested
    while [ -n "$remaining" ]; do
        case "$remaining" in
            *,*) part=\${remaining%%,*}; remaining=\${remaining#*,} ;;
            *) part=$remaining; remaining='' ;;
        esac
        case "$part" in
            fish) : ;;
            rotate) want_rotate=1 ;;
            *) echo "Error: módulo desconocido: $part" >&2; exit 2 ;;
        esac
    done
}
lt_print_modules() {
    printf '%s\n' 'fish    Obligatorio: configuración mínima de Fish' 'rotate  Opcional: rotación X11 de pantalla y táctil'
}
