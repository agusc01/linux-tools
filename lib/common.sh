#!/bin/sh
# linux-tools-managed: agusc01/linux-tools

lt_source_owned() {
    [ -f "$1" ] && [ ! -L "$1" ] && {
        grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$1" ||
        grep -Fqx '/* linux-tools-managed: agusc01/linux-tools */' "$1"
    }
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
    want_fish=0
    want_rotate=0
    want_audio=0
    want_brightness=0
    want_wifi=0
    want_bluetooth=0
    want_rofi=0
    want_shortcuts=0
    want_aliases=0
    [ -n "$requested" ] || { echo 'Error: --modules requiere lista.' >&2; exit 2; }
    remaining=$requested
    while [ -n "$remaining" ]; do
        case "$remaining" in
            *,*) part=${remaining%%,*}; remaining=${remaining#*,} ;;
            *) part=$remaining; remaining='' ;;
        esac
        case "$part" in
            fish) want_fish=1 ;;
            rotate) want_rotate=1 ;;
            audio) want_audio=1 ;;
            brightness) want_brightness=1 ;;
            wifi) want_wifi=1 ;;
            bluetooth) want_bluetooth=1 ;;
            rofi) want_rofi=1 ;;
            shortcuts) want_shortcuts=1 ;;
            aliases) want_aliases=1 ;;
            *) echo "Error: módulo desconocido: $part" >&2; exit 2 ;;
        esac
    done
}
lt_print_modules() {
    printf '%s\n' 'fish    Obligatorio: configuración mínima de Fish' 'rotate      Rotación X11 de pantalla y táctil' 'audio       Volumen con pulsemixer, wpctl o pactl' 'brightness  Brillo lógico X11 mediante xrandr' 'wifi        NetworkManager mediante nmcli (migración explícita)' 'bluetooth   Controlador BlueZ y servicios' 'rofi        Lanzador y menús de dwm (X11)' 'shortcuts   Comandos para el menú dshortcuts C' 'aliases     Nombres cortos Git y navegación Fish (opcional)'
}
