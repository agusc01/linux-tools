#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Pruebas headless: ninguna acción real sobre hardware, energía o dwm.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/mock" "$tmp/config/linux-tools/rofi"
export ROFI_SYSTEM_LOG="$tmp/log" ROFI_SYSTEM_QUEUE="$tmp/queue"
XDG_CONFIG_HOME="$tmp/config"
export XDG_CONFIG_HOME DISPLAY=:99
: > "$ROFI_SYSTEM_LOG"
# Los temas del repositorio no importan rutas del HOME antiguo.
. "$root/lib/common.sh"
for name in askpass brightness camera confirm global internet layout menu microphone power rofi rotation volume; do
    src="$root/rasi/$name.rasi"
    lt_source_owned "$src" || { echo "FALLO: tema sin marcador: $name" >&2; exit 1; }
    if grep -Fq '~/.bash_scripts/' "$src"; then
        echo "FALLO: ruta Bash absoluta en $name.rasi" >&2; exit 1
    fi
    cp "$src" "$tmp/config/linux-tools/rofi/$name.rasi"
done
cat > "$tmp/mock/rofi" <<'EOF'
#!/bin/sh
printf 'rofi:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
case " $* " in
    *" -dmenu "*)
        cat > "${ROFI_SYSTEM_LOG}.options"
        [ -s "$ROFI_SYSTEM_QUEUE" ] || exit 1
        IFS= read -r selected < "$ROFI_SYSTEM_QUEUE" || :
        tail -n +2 "$ROFI_SYSTEM_QUEUE" > "${ROFI_SYSTEM_QUEUE}.tmp"
        mv "${ROFI_SYSTEM_QUEUE}.tmp" "$ROFI_SYSTEM_QUEUE"
        [ "$selected" = CANCEL ] && exit 1
        printf '%s\n' "$selected" ;;
esac
EOF
cat > "$tmp/mock/xsetroot" <<'EOF'
#!/bin/sh
printf 'xsetroot:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
EOF
cat > "$tmp/mock/wpctl" <<'EOF'
#!/bin/sh
printf 'wpctl:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
[ "${ROFI_SYSTEM_NO_WPCTL:-0}" = 0 ] || exit 1
[ "$1" != get-volume ] || printf '%s\n' 'Volume: 0.75'
EOF
cat > "$tmp/mock/pactl" <<'EOF'
#!/bin/sh
printf 'pactl:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
[ "$1" != get-source-mute ] || printf '%s\n' 'Mute: no'
EOF
cat > "$tmp/mock/loginctl" <<'EOF'
#!/bin/sh
printf 'loginctl:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
EOF
cat > "$tmp/mock/slock" <<'EOF'
#!/bin/sh
printf 'slock:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
sleep 3
EOF
cat > "$tmp/mock/xset" <<'EOF'
#!/bin/sh
printf 'xset:%s\n' "$*" >> "$ROFI_SYSTEM_LOG"
EOF
chmod 755 "$tmp/mock/"*
PATH="$tmp/mock:$PATH"
export PATH
for name in rofi_layout rofi_microphone rofi_camera rofi_power; do
    sh -n "$root/bin/$name"
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$root/bin/$name"
    if sh "$root/bin/$name" unexpected >/dev/null 2>&1; then
        echo "FALLO: $name aceptó argumentos imprevistos." >&2; exit 1
    fi
done
# El layout usa las señales reales del fork; layout deck y dwindle
# intercambian señales respecto del índice (3 y 4).
printf 'H[] | Deck\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_layout"
grep -Fqx 'xsetroot:-name fsignal:3' "$ROFI_SYSTEM_LOG"
grep -Fq 'layout.rasi' "$ROFI_SYSTEM_LOG"
printf '%s\n' '[\] | Dwindle' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_layout"
grep -Fqx 'xsetroot:-name fsignal:4' "$ROFI_SYSTEM_LOG"
: > "$ROFI_SYSTEM_LOG"
printf 'CANCEL\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_layout"
! grep -Fq 'xsetroot:' "$ROFI_SYSTEM_LOG"
# Micrófono: el backend de entrada NO altera la salida de altavoces.
printf 'Silenciar micrófono\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_microphone"
grep -Fqx 'wpctl:set-mute @DEFAULT_AUDIO_SOURCE@ 1' "$ROFI_SYSTEM_LOG"
ROFI_SYSTEM_NO_WPCTL=1
export ROFI_SYSTEM_NO_WPCTL
printf 'Activar micrófono\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_microphone"
grep -Fqx 'pactl:set-source-mute @DEFAULT_SOURCE@ 0' "$ROFI_SYSTEM_LOG"
unset ROFI_SYSTEM_NO_WPCTL
# Nunca descargar un driver del kernel en pruebas: confirmar cancelación.
: > "$ROFI_SYSTEM_LOG"
printf 'Desactivar cámara USB (uvcvideo)\nCancelar\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_camera"
grep -Fq 'selected-row 0' "$ROFI_SYSTEM_LOG"
! grep -Fq 'pkexec:' "$ROFI_SYSTEM_LOG"
# En energía también se requiere doble confirmación. loginctl está simulado.
: > "$ROFI_SYSTEM_LOG"
printf 'Apagar equipo\nCancelar\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_power"
! grep -Fq 'loginctl:' "$ROFI_SYSTEM_LOG"
printf 'Reiniciar equipo\nConfirmar\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_power"
grep -Fqx 'loginctl:reboot' "$ROFI_SYSTEM_LOG"
printf 'Salir de dwm (pendiente)\n' > "$ROFI_SYSTEM_QUEUE"
sh "$root/bin/rofi_power"
! grep -Fq 'pkill:' "$ROFI_SYSTEM_LOG"
echo 'OK: temas RASI, layouts, entrada micrófono, cancelación de cámara y energía confirmada (mocks).'
