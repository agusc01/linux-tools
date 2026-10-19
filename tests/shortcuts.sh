#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/bin/lt-shortcut"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin"
export LT_SHORTCUT_LOG="$tmp/log"
: > "$LT_SHORTCUT_LOG"
for cmd in lt-volume lt-brightness lt-rofi lt-wifi lt-bluetooth rofi fish; do
    cat > "$tmp/bin/$cmd" <<'EOF'
#!/bin/sh
printf '%s:%s\n' "$(basename "$0")" "$*" >> "$LT_SHORTCUT_LOG"
printf '%s\n' 'mock result'
EOF
    chmod +x "$tmp/bin/$cmd"
done
PATH="$tmp/bin:$PATH"; export PATH
check() {
    sh "$root/bin/lt-shortcut" "$1" "$2" >/dev/null
    grep -Fqx "$3" "$LT_SHORTCUT_LOG" || {
        echo "FALLO: $1/$2, falta $3" >&2; exit 1
    }
}
check volume j 'lt-volume:down --notify'
check volume k 'lt-volume:up --notify'
check volume 5 'lt-volume:set 50 --notify'
check volume m 'lt-volume:toggle --notify'
check brightness j 'lt-brightness:down --notify'
check brightness 9 'lt-brightness:set 90 --notify'
check rotate r 'fish:-c rotar derecha'
check rotate n 'fish:-c rotar normal'
check wifi l 'lt-rofi:wifi'
check wifi c 'lt-wifi:connections'
check bluetooth d 'lt-rofi:bluetooth'
check bluetooth s 'lt-bluetooth:scan 8'
check rofi a 'lt-rofi:apps'
check rofi w 'lt-rofi:windows'
if sh "$root/bin/lt-shortcut" volume ';rm -rf ~' >/dev/null 2>&1; then
    echo 'FALLO: aceptó clave arbitraria.' >&2; exit 1
fi
if sh "$root/bin/lt-shortcut" power off >/dev/null 2>&1; then
    echo 'FALLO: comando peligroso no declarado.' >&2; exit 1
fi
echo 'OK: despachador dshortcuts sin Bash ni comandos arbitrarios.'
