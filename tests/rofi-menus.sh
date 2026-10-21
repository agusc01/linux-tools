#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Menús Rofi probados headless con herramientas simuladas, sin abrir navegador
# ni tocar pantalla/audio reales.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/mock"
export ROFI_MENUS_LOG="$tmp/log" ROFI_MENUS_QUEUE="$tmp/queue"
: > "$ROFI_MENUS_LOG"
cat > "$tmp/mock/rofi" <<'EOF'
#!/bin/sh
printf 'rofi:%s\n' "$*" >> "$ROFI_MENUS_LOG"
case " $* " in
    *" -dmenu "*)
        cat > "${ROFI_MENUS_LOG}.options"
        [ -s "$ROFI_MENUS_QUEUE" ] || exit 1
        IFS= read -r selected < "$ROFI_MENUS_QUEUE" || :
        tail -n +2 "$ROFI_MENUS_QUEUE" > "${ROFI_MENUS_QUEUE}.new"
        mv "${ROFI_MENUS_QUEUE}.new" "$ROFI_MENUS_QUEUE"
        [ "$selected" != CANCEL ] || exit 1
        printf '%s\n' "$selected"
        ;;
esac
EOF
cat > "$tmp/mock/firefox-esr" <<'EOF'
#!/bin/sh
printf 'browser:%s\n' "$*" >> "$ROFI_MENUS_LOG"
EOF
cat > "$tmp/mock/lt-volume" <<'EOF'
#!/bin/sh
printf 'volume:%s\n' "$*" >> "$ROFI_MENUS_LOG"
[ "$1" != status ] || echo 'Volumen: 42% (unmuted)'
EOF
cat > "$tmp/mock/lt-brightness" <<'EOF'
#!/bin/sh
printf 'brightness:%s\n' "$*" >> "$ROFI_MENUS_LOG"
[ "$1" != status ] || echo 'Brillo: 60% (eDP-1)'
EOF
chmod 755 "$tmp/mock/"*
PATH="$tmp/mock:$PATH"
export PATH DISPLAY=:99
for name in rofi_internet rofi_volume rofi_brightness; do
    sh -n "$root/bin/$name"
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$root/bin/$name"
    if sh "$root/bin/$name" unexpected >/dev/null 2>&1; then
        echo "FALLO: $name aceptó argumentos." >&2; exit 1
    fi
done
# URL del repositorio anterior, sin ejecutarse como shell string.
printf 'GitHub\nPrivada\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_internet"
sleep 0.2
grep -Fqx 'browser:--new-window --private-window https://github.com/' "$ROFI_MENUS_LOG"
grep -Fq 'IA (DuckDuckGo)' "${ROFI_MENUS_LOG}.options" || :
# Confirmación cancelada: no se abre ningún navegador.
: > "$ROFI_MENUS_LOG"
printf 'YouTube\nCANCEL\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_internet"
! grep -Fq 'browser:' "$ROFI_MENUS_LOG"
# Opción desconocida: rechazar, nunca abrir URLs o ejecutar texto de Rofi.
: > "$ROFI_MENUS_LOG"
printf '; touch /tmp/this-must-not-exist\n' > "$ROFI_MENUS_QUEUE"
if sh "$root/bin/rofi_internet" >/dev/null 2>&1; then
    echo 'FALLO: marcador web arbitrario aceptado.' >&2; exit 1
fi
! grep -Fq 'browser:' "$ROFI_MENUS_LOG"
# Corregir el antiguo typo de drive.googe.com y modo normal.
: > "$ROFI_MENUS_LOG"
printf 'Google Drive\nNormal\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_internet"
sleep 0.2
grep -Fqx 'browser:--new-window https://drive.google.com/' "$ROFI_MENUS_LOG"

: > "$ROFI_MENUS_LOG"
printf 'Subir 10%%\n50%%\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_volume"
grep -Fqx 'volume:up --notify' "$ROFI_MENUS_LOG"
grep -Fqx 'volume:unmute' "$ROFI_MENUS_LOG"
grep -Fqx 'volume:set 50 --notify' "$ROFI_MENUS_LOG"
test "$(grep -Fc 'volume:status' "$ROFI_MENUS_LOG")" -eq 2
: > "$ROFI_MENUS_LOG"
printf 'Silenciar\nCANCEL\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_volume"
grep -Fqx 'volume:mute --notify' "$ROFI_MENUS_LOG"
: > "$ROFI_MENUS_LOG"
printf '80%%\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_brightness"
grep -Fqx 'brightness:set 80 --notify' "$ROFI_MENUS_LOG"
: > "$ROFI_MENUS_LOG"
printf 'Bajar 10%%\nCANCEL\n' > "$ROFI_MENUS_QUEUE"
sh "$root/bin/rofi_brightness"
grep -Fqx 'brightness:down --notify' "$ROFI_MENUS_LOG"
: > "$ROFI_MENUS_LOG"
printf '0%%\n' > "$ROFI_MENUS_QUEUE"
if sh "$root/bin/rofi_brightness" >/dev/null 2>&1; then
    echo 'FALLO: brillo 0% no permitido.' >&2; exit 1
fi
! grep -Fq 'brightness:set' "$ROFI_MENUS_LOG"

echo 'OK: menús Rofi web/privado, volumen y brillo, cancelación y opciones cerradas.'
