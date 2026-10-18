#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/bin/lt-volume"
sh -n "$root/bin/lt-brightness"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/mock" "$tmp/state"
printf '%s\n' 50 > "$tmp/state/volume"
printf '%s\n' 0 > "$tmp/state/mute"
printf '%s\n' 0.50 > "$tmp/state/screen"
printf '%s\n' 1.00 > "$tmp/state/external"
export MOCK_STATE="$tmp/state"
export LT_AUDIO_BACKEND=pulsemixer

cat > "$tmp/mock/pulsemixer" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
    --get-volume) x=$(cat "$MOCK_STATE/volume"); printf '%s %s\n' "$x" "$x" ;;
    --get-mute) cat "$MOCK_STATE/mute" ;;
    --set-volume) printf '%s\n' "$2" > "$MOCK_STATE/volume" ;;
    --mute) echo 1 > "$MOCK_STATE/mute" ;;
    --unmute) echo 0 > "$MOCK_STATE/mute" ;;
    --toggle-mute)
        if [ "$(cat "$MOCK_STATE/mute")" = 1 ]; then echo 0 > "$MOCK_STATE/mute"
        else echo 1 > "$MOCK_STATE/mute"; fi ;;
    *) echo "Comando mock no esperado: $*" >&2; exit 1 ;;
esac
EOF

cat > "$tmp/mock/xrandr" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
    --verbose)
        printf 'Screen 0: minimum 8 x 8\n'
        printf 'HDMI-1 connected 1920x1080+0+0\n\tBrightness: %s\n' "$(cat "$MOCK_STATE/external")"
        printf 'eDP-1 connected primary 1920x1080+0+0\n\tBrightness: %s\n' "$(cat "$MOCK_STATE/screen")"
        printf 'DP-2 disconnected\n'
        ;;
    --output)
        [ "$3" = --brightness ] || exit 2
        case "$2" in
            eDP-1) printf '%s\n' "$4" > "$MOCK_STATE/screen" ;;
            HDMI-1) printf '%s\n' "$4" > "$MOCK_STATE/external" ;;
            *) exit 3 ;;
        esac ;;
    *) echo "Comando xrandr inesperado: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/mock/pulsemixer" "$tmp/mock/xrandr"
PATH="$tmp/mock:$PATH"
export PATH

fail() { echo "FALLO: $1" >&2; exit 1; }
[ "$(sh "$root/bin/lt-volume" get)" = 50 ] || fail 'volumen inicial'
sh "$root/bin/lt-volume" set 95 >/dev/null
sh "$root/bin/lt-volume" up >/dev/null
[ "$(sh "$root/bin/lt-volume" get)" = 100 ] || fail 'volumen debe limitarse a 100'
sh "$root/bin/lt-volume" down >/dev/null
[ "$(sh "$root/bin/lt-volume" get)" = 90 ] || fail 'bajar volumen'
sh "$root/bin/lt-volume" toggle >/dev/null
sh "$root/bin/lt-volume" status | grep -q muted || fail 'mute'
sh "$root/bin/lt-volume" unmute >/dev/null
sh "$root/bin/lt-volume" status | grep -q unmuted || fail 'unmute'
if sh "$root/bin/lt-volume" set 101 >/dev/null 2>&1; then fail 'volumen inválido'; fi

[ "$(sh "$root/bin/lt-brightness" get)" = 50 ] || fail 'brillo inicial'
sh "$root/bin/lt-brightness" down >/dev/null
[ "$(sh "$root/bin/lt-brightness" get)" = 40 ] || fail 'bajar brillo'
sh "$root/bin/lt-brightness" set 95 >/dev/null
sh "$root/bin/lt-brightness" up >/dev/null
[ "$(sh "$root/bin/lt-brightness" get)" = 100 ] || fail 'brillo debe limitarse a 100'
sh "$root/bin/lt-brightness" set 10 >/dev/null
sh "$root/bin/lt-brightness" down >/dev/null
[ "$(sh "$root/bin/lt-brightness" get)" = 10 ] || fail 'brillo debe limitarse a 10'
if sh "$root/bin/lt-brightness" set 0 >/dev/null 2>&1; then fail 'brillo inválido'; fi
LT_DISPLAY_OUTPUT=HDMI-1 sh "$root/bin/lt-brightness" set 75 >/dev/null
[ "$(cat "$tmp/state/external")" = '0.75' ] || fail 'selección monitor externo'
[ "$(sh "$root/bin/lt-brightness" get)" = 10 ] || fail 'no modificar otro monitor'


# Mock ALSA: el entorno mínimo Alpine no dispone necesariamente de PulseAudio.
cat > "$tmp/mock/amixer" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
    sget)
        [ "$2" = Master ] || exit 1
        printf "Simple mixer control 'Master',0\n"
        if [ "$(cat "$MOCK_STATE/mute")" = 1 ]; then switch=off; else switch=on; fi
        v=$(cat "$MOCK_STATE/volume")
        printf '  Mono: Playback 0 [%s%%] [%s]\n' "$v" "$switch"
        ;;
    -q)
        [ "$2" = sset ] && [ "$3" = Master ] || exit 1
        case "$4" in
            mute) echo 1 > "$MOCK_STATE/mute" ;;
            unmute) echo 0 > "$MOCK_STATE/mute" ;;
            toggle)
                if [ "$(cat "$MOCK_STATE/mute")" = 1 ]; then echo 0 > "$MOCK_STATE/mute"
                else echo 1 > "$MOCK_STATE/mute"; fi
                ;;
            *%)
                v=$(printf '%s' "$4" | tr -d '%')
                echo "$v" > "$MOCK_STATE/volume"
                ;;
            *) exit 2 ;;
        esac
        ;;
    *) exit 2 ;;
esac
EOF
chmod +x "$tmp/mock/amixer"
export LT_AUDIO_BACKEND=alsa
printf '%s\n' 50 > "$tmp/state/volume"
printf '%s\n' 0 > "$tmp/state/mute"
[ "$(sh "$root/bin/lt-volume" get)" = 50 ] || fail 'ALSA: lectura inicial'
sh "$root/bin/lt-volume" set 100 >/dev/null
sh "$root/bin/lt-volume" up >/dev/null
[ "$(sh "$root/bin/lt-volume" get)" = 100 ] || fail 'ALSA: volumen máximo'
sh "$root/bin/lt-volume" down >/dev/null
[ "$(sh "$root/bin/lt-volume" get)" = 90 ] || fail 'ALSA: bajar volumen'
sh "$root/bin/lt-volume" mute >/dev/null
sh "$root/bin/lt-volume" status | grep -q '(muted)' || fail 'ALSA: mute'
sh "$root/bin/lt-volume" toggle >/dev/null
sh "$root/bin/lt-volume" status | grep -q '(unmuted)' || fail 'ALSA: unmute'
# Sin PulseAudio ni PipeWire: ALSA se detecta automáticamente.
unset LT_AUDIO_BACKEND
mv "$tmp/mock/pulsemixer" "$tmp/mock/pulsemixer.off"
sh "$root/bin/lt-volume" status | grep -q '90%' || fail 'ALSA: autodetección'

echo 'OK: PulseAudio y ALSA simulados, brillo X11 sin tocar hardware.'
