#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
# El instalador debe verificar dependencias de /sbin incluso antes de que
# la sesión Fish actual haya recargado linux-tools.fish.
PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"
export PATH
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$root/lib/common.sh"

modules=fish,rotate
dry_run=0
verify_only=0
migrate_rotate=0
skip_deps=0
assume_yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --list) lt_print_modules; exit 0 ;;
        --help|-h)
            printf '%s\n' 'Uso: sh install.sh [--modules fish,rotate,audio,brightness,wifi,bluetooth,rofi,shortcuts,aliases] [--dry-run] [--verify] [--migrate-rotate] [--no-deps] [--yes]' 'Por defecto se instalan Fish y las cinco funciones de rotación táctil.'
            exit 0 ;;
        --modules)
            [ "$#" -ge 2 ] || { echo 'Falta valor para --modules.' >&2; exit 2; }
            modules=$2; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --verify) verify_only=1; shift ;;
        --migrate-rotate) migrate_rotate=1; shift ;;
        --no-deps) skip_deps=1; shift ;;
        --yes) assume_yes=1; shift ;;
        *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
    esac
done
lt_parse_modules "$modules"
if [ "$verify_only" -eq 1 ] && [ "$dry_run" -eq 1 ]; then
    echo 'Error: --verify y --dry-run no pueden combinarse.' >&2
    exit 2
fi
if [ "$dry_run" -eq 0 ] && [ "$verify_only" -eq 0 ]; then
    lt_require_user
    command -v fish >/dev/null 2>&1 || { echo 'Error: Fish es obligatorio. Instalalo mediante apk/apt o linux-setup.' >&2; exit 1; }
fi

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
config_target="$config_home/fish/conf.d/linux-tools.fish"
plan=''
add_plan() {
    plan="$plan
$1|$2"
}
add_plan 'fish/conf.d/linux-tools.fish' "$config_target"
if [ "$want_rotate" -eq 1 ]; then
    for name in rotar r0 r90 r180 r270; do
        add_plan "fish/functions/$name.fish" "$config_home/fish/functions/$name.fish"
    done
fi
if [ "$want_audio" -eq 1 ]; then
    add_plan 'bin/lt-volume' "$HOME/.local/bin/lt-volume"
    add_plan 'bin/lt-audio-save' "$HOME/.local/bin/lt-audio-save"
    add_plan 'lib/admin-paths.sh' "$HOME/.local/share/linux-tools/lib/admin-paths.sh"
    add_plan 'lib/audio-hardware.sh' "$HOME/.local/share/linux-tools/lib/audio-hardware.sh"
    add_plan 'fish/functions/lt_audio.fish' "$config_home/fish/functions/lt_audio.fish"
    for name in s0 s1 smute sunmute stogglemute; do
        add_plan "bin/$name" "$HOME/.local/bin/$name"
    done
fi
if [ "$want_brightness" -eq 1 ]; then
    add_plan 'bin/lt-brightness' "$HOME/.local/bin/lt-brightness"
    add_plan 'fish/functions/lt_brightness.fish' "$config_home/fish/functions/lt_brightness.fish"
    for name in b0 b1; do
        add_plan "bin/$name" "$HOME/.local/bin/$name"
    done
fi
if [ "$want_wifi" -eq 1 ]; then
    add_plan 'bin/lt-wifi' "$HOME/.local/bin/lt-wifi"
    add_plan 'fish/functions/lt_wifi.fish' "$config_home/fish/functions/lt_wifi.fish"
fi
if [ "$want_bluetooth" -eq 1 ]; then
    add_plan 'bin/lt-bluetooth' "$HOME/.local/bin/lt-bluetooth"
    add_plan 'fish/functions/lt_bluetooth.fish' "$config_home/fish/functions/lt_bluetooth.fish"
fi
if [ "$want_rofi" -eq 1 ]; then
    add_plan 'bin/lt-rofi' "$HOME/.local/bin/lt-rofi"
    add_plan 'fish/functions/lt_rofi.fish' "$config_home/fish/functions/lt_rofi.fish"
    for name in rofi_launcher rofi_runner rofi_window rofi_menu; do
        add_plan "bin/$name" "$HOME/.local/bin/$name"
    done
    # Los nuevos menús dependen de motores instalados de forma independiente.
    for name in rofi_internet rofi_volume rofi_brightness; do
        add_plan "bin/$name" "$HOME/.local/bin/$name"
    done
    for name in rofi_power rofi_layout rofi_microphone rofi_camera; do
        add_plan "bin/$name" "$HOME/.local/bin/$name"
    done
    # Themes isolated from ~/.config/rofi and personal legacy ~/.bash_scripts.
    for name in askpass brightness camera confirm global internet layout menu microphone power rofi rotation volume; do
        add_plan "rasi/$name.rasi" "$config_home/linux-tools/rofi/$name.rasi"
    done
fi
if [ "$want_shortcuts" -eq 1 ]; then
    add_plan 'bin/lt-shortcut' "$HOME/.local/bin/lt-shortcut"
    add_plan 'bin/fsignal' "$HOME/.local/bin/fsignal"
fi
if [ "$want_aliases" -eq 1 ]; then
    for name in g ga gaA gau gs gss gct gctm gpull gpullremote gamend; do
        add_plan "bin/$name" "$HOME/.local/bin/$name"
    done
    for name in dw dk dc pic cdwm cst cslock cdshortcuts; do
        add_plan "fish/functions/$name.fish" "$config_home/fish/functions/$name.fish"
    done
fi

# Verificación de instalación REAL: no ejecuta r90, evita rotar la pantalla.
# Fish se inicia en un proceso nuevo, con el mismo HOME y XDG_CONFIG_HOME.
verify_functions() {
    failed=0
    if ! command -v fish >/dev/null 2>&1; then
        echo 'Error: Fish no está disponible en PATH.' >&2
        return 1
    fi
    if [ ! -f "$config_target" ] || ! lt_source_owned "$config_target"; then
        echo "Error: falta la configuración administrada: $config_target" >&2
        failed=1
    fi
    if [ "$want_rotate" -eq 1 ]; then
        for name in rotar r0 r90 r180 r270; do
            target="$config_home/fish/functions/$name.fish"
            if [ ! -f "$target" ] || ! lt_source_owned "$target"; then
                echo "Error: falta la función instalada: $target" >&2
                failed=1
            elif fish -c "type -q $name"; then
                echo "OK: Fish reconoce $name"
            else
                echo "Error: existe $target, pero Fish no reconoce $name." >&2
                failed=1
            fi
        done
    else
        echo 'Rotación: no seleccionada (--modules fish,rotate para incluirla).'
    fi
    if [ "$want_audio" -eq 1 ]; then
        if [ ! -x "$HOME/.local/bin/lt-volume" ] || ! lt_source_owned "$HOME/.local/bin/lt-volume" ||
             [ ! -x "$HOME/.local/bin/lt-audio-save" ] || ! lt_source_owned "$HOME/.local/bin/lt-audio-save"; then
            echo 'Error: falta lt-volume o lt-audio-save.' >&2
            failed=1
        elif [ ! -f "$HOME/.local/share/linux-tools/lib/admin-paths.sh" ] ||
             ! lt_source_owned "$HOME/.local/share/linux-tools/lib/admin-paths.sh" ||
             [ ! -f "$HOME/.local/share/linux-tools/lib/audio-hardware.sh" ] ||
             ! lt_source_owned "$HOME/.local/share/linux-tools/lib/audio-hardware.sh"; then
            echo 'Error: faltan las bibliotecas instaladas de lt-audio-save.' >&2
            failed=1
        elif ! "$HOME/.local/bin/lt-audio-save" status >/dev/null 2>&1; then
            echo 'Error: lt-audio-save está instalado pero no puede cargar sus bibliotecas.' >&2
            failed=1
        elif ! fish -c 'type -q lt_audio; and command -sq lt-volume'; then
            echo 'Error: Fish no reconoce lt_audio.' >&2
            failed=1
        else
            echo 'OK: lt_audio y ejecutable lt-volume'
            if "$HOME/.local/bin/lt-volume" status >/dev/null 2>&1; then
                echo "OK: backend de audio operativo: $("$HOME/.local/bin/lt-volume" status)"
            else
                echo 'Error: el comando está instalado, pero no hay audio operativo.' >&2
                echo 'Diagnóstico: aplay -l; alsamixer; id -nG' >&2
                echo 'Reparación: sh install.sh --modules audio' >&2
                echo 'Cherry Trail: tras instalar firmware SOF es obligatorio reiniciar; verificá BIOS LPE Audio ACPI mode.' >&2
                failed=1
            fi
        fi
    fi
    if [ "$want_brightness" -eq 1 ]; then
        if [ ! -x "$HOME/.local/bin/lt-brightness" ] || ! lt_source_owned "$HOME/.local/bin/lt-brightness"; then
            echo 'Error: falta el ejecutable lt-brightness.' >&2
            failed=1
        elif ! fish -c 'type -q lt_brightness; and command -sq lt-brightness'; then
            echo 'Error: Fish no reconoce lt_brightness.' >&2
            failed=1
        else
            echo 'OK: lt_brightness y ejecutable lt-brightness'
        fi
    fi
    if [ "$want_wifi" -eq 1 ]; then
        if [ ! -x "$HOME/.local/bin/lt-wifi" ] || ! lt_source_owned "$HOME/.local/bin/lt-wifi" ||
           ! fish -c 'type -q lt_wifi' ||
           { ! command -v nmcli >/dev/null 2>&1 && ! command -v iw >/dev/null 2>&1; }; then
            echo 'Error: falta lt-wifi, función Fish o un backend compatible (nmcli/iw).' >&2
            failed=1
        else
            echo 'OK: lt-wifi instalado.'
            if "$HOME/.local/bin/lt-wifi" status >/dev/null 2>&1; then
                echo 'OK: lt-wifi reconoce el gestor Wi-Fi activo.'
            else
                echo 'Aviso: no se pudo comprobar un gestor Wi-Fi activo; no se cambió la red existente.' >&2
            fi
        fi
    fi
    if [ "$want_bluetooth" -eq 1 ]; then
        if [ ! -x "$HOME/.local/bin/lt-bluetooth" ] || ! lt_source_owned "$HOME/.local/bin/lt-bluetooth" ||
           ! fish -c 'type -q lt_bluetooth' || ! command -v bluetoothctl >/dev/null 2>&1; then
            echo 'Error: falta lt-bluetooth, función Fish o dependencia bluetoothctl.' >&2
            failed=1
        else
            echo 'OK: lt-bluetooth y BlueZ instalados; la presencia de adaptador se comprueba por separado.'
        fi
    fi
    if [ "$want_rofi" -eq 1 ]; then
        if [ ! -x "$HOME/.local/bin/lt-rofi" ] || ! lt_source_owned "$HOME/.local/bin/lt-rofi" ||
           ! fish -c 'type -q lt_rofi' || ! command -v rofi >/dev/null 2>&1; then
            echo 'Error: falta lt-rofi, función Fish o ejecutable rofi.' >&2
            failed=1
        else
            echo 'OK: lt-rofi preparado. Los menús volumen/brillo necesitan los motores correspondientes.'
            if ! command -v xsetroot >/dev/null 2>&1; then
                echo 'Aviso: rofi_layout requiere xsetroot; reinstalá el módulo rofi sin --no-deps.' >&2
            fi
        fi
    fi
    if [ "$want_shortcuts" -eq 1 ]; then
        if [ ! -x "$HOME/.local/bin/lt-shortcut" ] ||
           ! lt_source_owned "$HOME/.local/bin/lt-shortcut" ||
           [ ! -x "$HOME/.local/bin/fsignal" ] ||
           ! lt_source_owned "$HOME/.local/bin/fsignal"; then
            echo 'Error: faltan lt-shortcut/fsignal o no están administrados por linux-tools.' >&2
            failed=1
        else
            echo 'OK: dispatcher lt-shortcut y fsignal instalados.'
            if ! command -v xsetroot >/dev/null 2>&1; then
                echo 'Aviso: xsetroot no está instalado; fsignal requiere preparar el módulo shortcuts.' >&2
            fi
        fi
    fi
    # Solo verificar nombres: no ejecutar acciones de audio/brillo/Rofi/Git.
    if [ "$want_audio" -eq 1 ]; then
        for name in s0 s1 smute sunmute stogglemute; do
            if [ ! -x "$HOME/.local/bin/$name" ] || ! lt_source_owned "$HOME/.local/bin/$name"; then
                echo "Error: falta acceso directo de audio: $name" >&2
                failed=1
            fi
        done
    fi
    if [ "$want_brightness" -eq 1 ]; then
        for name in b0 b1; do
            if [ ! -x "$HOME/.local/bin/$name" ] || ! lt_source_owned "$HOME/.local/bin/$name"; then
                echo "Error: falta acceso directo de brillo: $name" >&2
                failed=1
            fi
        done
    fi
    if [ "$want_rofi" -eq 1 ]; then
        for name in rofi_launcher rofi_runner rofi_window rofi_menu rofi_internet rofi_volume rofi_brightness rofi_power rofi_layout rofi_microphone rofi_camera; do
            if [ ! -x "$HOME/.local/bin/$name" ] || ! lt_source_owned "$HOME/.local/bin/$name"; then
                echo "Error: falta acceso directo de Rofi: $name" >&2
                failed=1
            fi
        done
    fi
    if [ "$want_rofi" -eq 1 ]; then
        for name in askpass brightness camera confirm global internet layout menu microphone power rofi rotation volume; do
            theme="$config_home/linux-tools/rofi/$name.rasi"
            if [ ! -f "$theme" ] || ! lt_source_owned "$theme"; then
                echo "Error: falta tema RASI administrado: $name.rasi" >&2
                failed=1
            fi
        done
    fi
    if [ "$want_aliases" -eq 1 ]; then
        for name in g ga gaA gau gs gss gct gctm gpull gpullremote gamend; do
            if [ ! -x "$HOME/.local/bin/$name" ] || ! lt_source_owned "$HOME/.local/bin/$name"; then
                echo "Error: falta alias ejecutable de Git: $name" >&2
                failed=1
            fi
        done
        for name in dw dk dc pic cdwm cst cslock cdshortcuts; do
            target="$config_home/fish/functions/$name.fish"
            if [ ! -f "$target" ] || ! lt_source_owned "$target" ||
               ! fish -c "functions -q -- $name"; then
                echo "Error: falta función Fish: $name" >&2
                failed=1
            fi
        done
    fi
    if [ "$failed" -ne 0 ]; then
        echo 'Diagnóstico: ejecutá fish -c "printf \"%s\\n\" \$fish_function_path" para ver dónde busca Fish.' >&2
        return 1
    fi
    echo 'Verificación correcta.'
}
if [ "$verify_only" -eq 1 ]; then
    verify_functions
    exit $?
fi

migration_kind() {
    target=$1
    if [ "$migrate_rotate" -eq 1 ] && lt_old_rotate "$target"; then
        printf '%s\n' rotate
    else
        printf '%s\n' ''
    fi
}

# Verificar TODOS los destinos antes de efectuar cambios.
while IFS='|' read -r relative target; do
    [ -n "$relative" ] || continue
    source_file="$root/$relative"
    if ! lt_source_owned "$source_file"; then
        echo "Error: archivo fuente no administrado o ausente: $relative" >&2
        exit 1
    fi
    if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
        echo "Conflicto: $target no es un archivo regular. No se modifica." >&2
        exit 1
    fi
    if [ -f "$target" ] && ! lt_source_owned "$target"; then
        kind=$(migration_kind "$target")
        if [ -z "$kind" ]; then
            echo "Conflicto: $target existe y es ajeno. Usá --migrate-rotate solamente para funciones antiguas de rotate." >&2
            exit 1
        fi
    fi
done <<EOF
$plan
EOF

# Las dependencias forman parte de la instalación, no son solo advertencias.
# Primero se comprueban conflictos. Después se instala el backend del sistema.
# --no-deps sirve para entornos controlados/pruebas y NO garantiza audio usable.
if [ "$want_audio" -eq 1 ] && [ "$skip_deps" -eq 0 ]; then
    if [ "$dry_run" -eq 1 ]; then
        sh "$root/lib/audio-setup.sh" --dry-run
    elif [ "$assume_yes" -eq 1 ]; then
        sh "$root/lib/audio-setup.sh" --yes
    else
        sh "$root/lib/audio-setup.sh"
    fi
fi
if [ "$skip_deps" -eq 0 ]; then
    for connectivity in wifi bluetooth; do
        if { [ "$connectivity" = wifi ] && [ "$want_wifi" -eq 1 ]; } ||
           { [ "$connectivity" = bluetooth ] && [ "$want_bluetooth" -eq 1 ]; }; then
            if [ "$dry_run" -eq 1 ]; then
                sh "$root/lib/connectivity-setup.sh" --module "$connectivity" --dry-run
            elif [ "$assume_yes" -eq 1 ]; then
                sh "$root/lib/connectivity-setup.sh" --module "$connectivity" --yes
            else
                sh "$root/lib/connectivity-setup.sh" --module "$connectivity"
            fi
        fi
    done
fi
# rofi_layout y los atajos de dshortcuts usan señales X11.
if [ "$skip_deps" -eq 0 ] && { [ "$want_rofi" -eq 1 ] || [ "$want_shortcuts" -eq 1 ]; }; then
    if [ "$dry_run" -eq 1 ]; then
        sh "$root/lib/xsetroot-setup.sh" --dry-run
    elif [ "$assume_yes" -eq 1 ]; then
        sh "$root/lib/xsetroot-setup.sh" --yes
    else
        sh "$root/lib/xsetroot-setup.sh"
    fi
fi
if [ "$want_rofi" -eq 1 ] && [ "$skip_deps" -eq 0 ]; then
    if [ "$dry_run" -eq 1 ]; then
        sh "$root/lib/rofi-setup.sh" --dry-run
    elif [ "$assume_yes" -eq 1 ]; then
        sh "$root/lib/rofi-setup.sh" --yes
    else
        sh "$root/lib/rofi-setup.sh"
    fi
fi
if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: no se modificará ningún archivo.'
fi
backup_dir=''
tempfile=''
trap 'if [ -n "$tempfile" ]; then rm -f "$tempfile"; fi' 0
while IFS='|' read -r relative target; do
    [ -n "$relative" ] || continue
    source_file="$root/$relative"
    mode=644
    case "$relative" in bin/*) mode=755 ;; esac
    if [ -f "$target" ] && cmp -s "$source_file" "$target" && { [ "$mode" -ne 755 ] || [ -x "$target" ]; }; then
        echo "Sin cambios: $target"
        continue
    fi
    kind=''
    if [ -f "$target" ] && ! lt_source_owned "$target"; then
        kind=$(migration_kind "$target")
    fi
    if [ "$dry_run" -eq 1 ]; then
        if [ -n "$kind" ]; then
            echo "Migraría ($kind con backup): $target"
        else
            echo "Instalaría: $target"
        fi
        continue
    fi
    if [ -n "$kind" ]; then
        if [ -z "$backup_dir" ]; then
            backup_base=${XDG_STATE_HOME:-"$HOME/.local/state"}/linux-tools/backups
            mkdir -p "$backup_base"
            backup_dir=$(mktemp -d "$backup_base/migration.XXXXXXXX")
        fi
        cp -p "$target" "$backup_dir/$(basename "$target")"
        echo "Backup: $backup_dir/$(basename "$target")"
    fi
    mkdir -p "$(dirname "$target")"
    tempfile=$(mktemp "$(dirname "$target")/.linux-tools.XXXXXXXX")
    cp "$source_file" "$tempfile"
    chmod "$mode" "$tempfile"
    mv -f "$tempfile" "$target"
    tempfile=''
    echo "Instalado: $target"
done <<EOF
$plan
EOF

if [ "$want_rotate" -eq 1 ]; then
    for dependency in xrandr xinput; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            echo "Aviso: falta $dependency para rotación X11." >&2
        fi
    done
fi
selected='fish'
[ "$want_rotate" -eq 0 ] || selected="$selected, rotate"
[ "$want_audio" -eq 0 ] || selected="$selected, audio"
[ "$want_brightness" -eq 0 ] || selected="$selected, brightness"
[ "$want_wifi" -eq 0 ] || selected="$selected, wifi"
[ "$want_bluetooth" -eq 0 ] || selected="$selected, bluetooth"
[ "$want_rofi" -eq 0 ] || selected="$selected, rofi"
[ "$want_shortcuts" -eq 0 ] || selected="$selected, shortcuts"
[ "$want_aliases" -eq 0 ] || selected="$selected, aliases"
if [ "$dry_run" -eq 1 ]; then
    echo "Módulos simulados: $selected."
    exit 0
fi
echo "Módulos instalados: $selected."
if [ "$skip_deps" -eq 1 ] && { [ "$want_audio" -eq 1 ] || [ "$want_wifi" -eq 1 ] ||
    [ "$want_bluetooth" -eq 1 ] || [ "$want_rofi" -eq 1 ]; }; then
    echo 'Aviso: --no-deps omitió deliberadamente la configuración del sistema de audio.'
    echo 'Para completar la instalación: sh install.sh --modules audio'
    # Comprobar que los ejecutables se instalaron sin fingir que hay audio operativo.
    if [ "$want_audio" -eq 1 ]; then [ -x "$HOME/.local/bin/lt-volume" ] || exit 1; fi
    if [ "$want_wifi" -eq 1 ]; then [ -x "$HOME/.local/bin/lt-wifi" ] || exit 1; fi
    if [ "$want_bluetooth" -eq 1 ]; then [ -x "$HOME/.local/bin/lt-bluetooth" ] || exit 1; fi
    if [ "$want_rofi" -eq 1 ]; then [ -x "$HOME/.local/bin/lt-rofi" ] || exit 1; fi
    if [ "$want_shortcuts" -eq 1 ]; then [ -x "$HOME/.local/bin/lt-shortcut" ] && [ -x "$HOME/.local/bin/fsignal" ] || exit 1; fi
    if [ "$want_aliases" -eq 1 ]; then [ -x "$HOME/.local/bin/gs" ] || exit 1; fi
else
    verify_functions || exit 1
fi
echo 'Listo. Las funciones de Fish están disponibles sin reiniciar la sesión.'
