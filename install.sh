#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
. "$root/lib/common.sh"

modules=fish,rotate
dry_run=0
verify_only=0
migrate_rotate=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --list) lt_print_modules; exit 0 ;;
        --help|-h)
            printf '%s\n' 'Uso: sh install.sh [--modules fish,rotate] [--dry-run] [--verify] [--migrate-rotate]' 'Por defecto se instalan Fish y las cinco funciones de rotación táctil.'
            exit 0 ;;
        --modules)
            [ "$#" -ge 2 ] || { echo 'Falta valor para --modules.' >&2; exit 2; }
            modules=$2; shift 2 ;;
        --dry-run) dry_run=1; shift ;;
        --verify) verify_only=1; shift ;;
        --migrate-rotate) migrate_rotate=1; shift ;;
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

if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: no se modificará ningún archivo.'
fi
backup_dir=''
tempfile=''
trap 'if [ -n "$tempfile" ]; then rm -f "$tempfile"; fi' 0
while IFS='|' read -r relative target; do
    [ -n "$relative" ] || continue
    source_file="$root/$relative"
    if [ -f "$target" ] && cmp -s "$source_file" "$target"; then
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
    chmod 644 "$tempfile"
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
if [ "$dry_run" -eq 1 ]; then
    echo "Módulos simulados: fish$([ "$want_rotate" -eq 1 ] && printf ', rotate')."
    exit 0
fi
echo "Módulos instalados: fish$([ "$want_rotate" -eq 1 ] && printf ', rotate')."
verify_functions || exit 1
echo 'Listo. Las funciones de Fish están disponibles sin reiniciar la sesión.'
