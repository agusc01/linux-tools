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
for cmd in lt-volume lt-brightness lt-rofi lt-wifi lt-bluetooth rofi fish fsignal; do
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
check layout t 'fsignal:14'
check layout m 'fsignal:1'
check layout s 'fsignal:2'
check layout w 'fsignal:3'
check layout d 'fsignal:4'
check layout b 'fsignal:5'
check layout B 'fsignal:6'
check layout g 'fsignal:7'
check layout r 'fsignal:8'
check layout h 'fsignal:9'
check layout l 'fsignal:10'
check layout M 'fsignal:11'
check layout F 'fsignal:12'
check layout f 'fsignal:13'
check gap t 'fsignal:56'
check gap i 'fsignal:55'
check gap s 'fsignal:74'
check gap j 'fsignal:40'
check gap J 'fsignal:41'
check gap k 'fsignal:42'
check gap K 'fsignal:43'
check gap u 'fsignal:44'
check gap U 'fsignal:45'
check gap 1 'fsignal:46'
check gap 2 'fsignal:47'
check gap 3 'fsignal:48'
check gap 4 'fsignal:49'
check gap 5 'fsignal:51'
check gap 6 'fsignal:52'
check gap 7 'fsignal:53'
check gap 8 'fsignal:54'
check border j 'fsignal:30'
check border k 'fsignal:31'
check border s 'fsignal:32'
if sh "$root/bin/lt-shortcut" volume ';rm -rf ~' >/dev/null 2>&1; then
    echo 'FALLO: aceptó clave arbitraria.' >&2; exit 1
fi
if sh "$root/bin/lt-shortcut" layout 99 >/dev/null 2>&1 ||
   sh "$root/bin/lt-shortcut" gap ';touch /tmp/bad' >/dev/null 2>&1 ||
   sh "$root/bin/lt-shortcut" border 0 >/dev/null 2>&1; then
    echo 'FALLO: aceptó señales o teclas no autorizadas.' >&2; exit 1
fi
if sh "$root/bin/lt-shortcut" power off >/dev/null 2>&1; then
    echo 'FALLO: comando peligroso no declarado.' >&2; exit 1
fi
echo 'OK: despachador dshortcuts sin Bash ni comandos arbitrarios.'
