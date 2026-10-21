#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/bin/lt-rofi"
sh -n "$root/lib/rofi-setup.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/mock"
export ROFI_TEST_LOG="$tmp/log"
: > "$ROFI_TEST_LOG"
cat > "$tmp/mock/rofi" <<'EOF'
#!/bin/sh
printf 'rofi:%s\n' "$*" >> "$ROFI_TEST_LOG"
if [ "$1" = -dmenu ]; then
    [ "${ROFI_TEST_CANCEL:-0}" = 0 ] || exit 1
    printf '%s\n' "${ROFI_TEST_SELECTION:-Aplicaciones}"
fi
EOF
cat > "$tmp/mock/lt-wifi" <<'EOF'
#!/bin/sh
printf 'wifi:%s\n' "$*" >> "$ROFI_TEST_LOG"
echo 'TeleCentro-76d7'
echo 'Otra red'
EOF
cat > "$tmp/mock/lt-bluetooth" <<'EOF'
#!/bin/sh
printf 'bluetooth:%s\n' "$*" >> "$ROFI_TEST_LOG"
echo 'Device AA:BB:CC:DD:EE:FF'
EOF
for script in rofi_internet rofi_volume rofi_brightness; do
    cat > "$tmp/mock/$script" <<'EOF'
#!/bin/sh
printf 'menu:%s\n' "$(basename "$0")" >> "$ROFI_TEST_LOG"
EOF
done
chmod +x "$tmp/mock/"*
PATH="$tmp/mock:$PATH"
export PATH DISPLAY=:99

sh "$root/bin/lt-rofi" apps
grep -Fqx 'rofi:-show drun' "$ROFI_TEST_LOG"
sh "$root/bin/lt-rofi" run
grep -Fqx 'rofi:-show run' "$ROFI_TEST_LOG"
sh "$root/bin/lt-rofi" windows
grep -Fqx 'rofi:-show window' "$ROFI_TEST_LOG"
sh "$root/bin/lt-rofi" wifi
grep -Fq 'wifi:list' "$ROFI_TEST_LOG"
grep -Fq 'rofi:-e Wi-Fi' "$ROFI_TEST_LOG"
sh "$root/bin/lt-rofi" bluetooth
grep -Fq 'bluetooth:devices' "$ROFI_TEST_LOG"
sh "$root/bin/lt-rofi" menu
grep -Fq 'rofi:-dmenu -no-custom -p linux-tools' "$ROFI_TEST_LOG"
ROFI_TEST_SELECTION='Redes Wi-Fi' sh "$root/bin/lt-rofi" menu
for name in rofi_internet rofi_volume rofi_brightness; do
    case "$name" in
        rofi_internet) label='Internet (marcadores)' ;;
        rofi_volume) label='Volumen' ;;
        rofi_brightness) label='Brillo' ;;
    esac
    ROFI_TEST_SELECTION="$label" sh "$root/bin/lt-rofi" menu
    grep -Fqx "menu:$name" "$ROFI_TEST_LOG"
done
grep -Fq 'wifi:list' "$ROFI_TEST_LOG"
ROFI_TEST_CANCEL=1 sh "$root/bin/lt-rofi" menu
if ROFI_TEST_SELECTION=';rm -rf /' sh "$root/bin/lt-rofi" menu >/dev/null 2>&1; then
    echo 'FALLO: selección arbitraria aceptada.' >&2
    exit 1
fi
if sh "$root/bin/lt-rofi" unknown >/dev/null 2>&1; then
    echo 'FALLO: comando no reconocido aceptado.' >&2
    exit 1
fi

# No tocar ninguna pantalla ni instalar nada real en tests; verificar módulos con mocks.
if ! command -v rofi >/dev/null 2>&1; then
    echo 'FALLO: faltó el mock rofi.' >&2
    exit 1
fi
printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/release"
LT_OS_RELEASE="$tmp/release" sh "$root/lib/rofi-setup.sh" --dry-run | grep -q 'ya está instalado'

echo 'OK: Rofi apps/run/window, menú interactivo validado y consultas no destructivas.'
