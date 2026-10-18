#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/bin/lt-wifi"
sh -n "$root/bin/lt-bluetooth"
sh -n "$root/lib/connectivity-setup.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/mock"
export MOCK_CONNECT_LOG="$tmp/commands"
: > "$MOCK_CONNECT_LOG"
cat > "$tmp/mock/nmcli" <<'EOF'
#!/bin/sh
printf 'wifi:%s\n' "$*" >> "$MOCK_CONNECT_LOG"
if [ "$*" = "-t -f RUNNING general" ]; then
    echo running
    exit 0
fi
echo "NM $*"
EOF
cat > "$tmp/mock/bluetoothctl" <<'EOF'
#!/bin/sh
printf 'bt:%s\n' "$*" >> "$MOCK_CONNECT_LOG"
case "$1" in
    show) echo 'Powered: yes' ;;
    devices) echo 'Device AA:BB:CC:DD:EE:FF Headphones' ;;
    *) echo "BT $*" ;;
esac
EOF
chmod +x "$tmp/mock/nmcli" "$tmp/mock/bluetoothctl"
PATH="$tmp/mock:$PATH"
export PATH

sh "$root/bin/lt-wifi" status | grep -q 'NM'
sh "$root/bin/lt-wifi" list | grep -q 'NM'
sh "$root/bin/lt-wifi" connect 'Red con espacios' >/dev/null
grep -Fq 'wifi:--ask device wifi connect Red con espacios' "$MOCK_CONNECT_LOG"
sh "$root/bin/lt-wifi" off >/dev/null
grep -Fq 'wifi:radio wifi off' "$MOCK_CONNECT_LOG"
if sh "$root/bin/lt-wifi" connect >/dev/null 2>&1; then
    echo 'Error: SSID faltante aceptado.' >&2; exit 1
fi
sh "$root/bin/lt-bluetooth" status | grep -q 'Powered: yes'
sh "$root/bin/lt-bluetooth" scan 10 >/dev/null
grep -Fq 'bt:--timeout 10 scan on' "$MOCK_CONNECT_LOG"
sh "$root/bin/lt-bluetooth" connect AA:BB:CC:DD:EE:FF >/dev/null
grep -Fq 'bt:connect AA:BB:CC:DD:EE:FF' "$MOCK_CONNECT_LOG"
if sh "$root/bin/lt-bluetooth" connect 'AA:BB:CC;rm' >/dev/null 2>&1; then
    echo 'Error: dirección Bluetooth maliciosa aceptada.' >&2; exit 1
fi
if sh "$root/bin/lt-bluetooth" scan 100 >/dev/null 2>&1; then
    echo 'Error: escaneo Bluetooth ilimitado aceptado.' >&2; exit 1
fi

printf 'ID=alpine\nVERSION_ID=3.24.2\n' > "$tmp/os-release"
LT_OS_RELEASE="$tmp/os-release" sh "$root/lib/connectivity-setup.sh" --module wifi --dry-run > "$tmp/plan"
grep -q 'v3.24/community' "$tmp/plan"
grep -q 'networkmanager-cli' "$tmp/plan"
grep -q 'NO se reemplazará' "$tmp/plan"
LT_OS_RELEASE="$tmp/os-release" sh "$root/lib/connectivity-setup.sh" --module bluetooth --dry-run > "$tmp/plan"
grep -q 'bluez bluez-openrc dbus dbus-openrc' "$tmp/plan"
if grep -q '/community' "$tmp/plan"; then
    echo 'Error: bluetooth requiere community inesperadamente.' >&2; exit 1
fi

printf 'ID=debian\nVERSION_ID=13\n' > "$tmp/os-release"
LT_OS_RELEASE="$tmp/os-release" sh "$root/lib/connectivity-setup.sh" --module wifi --dry-run | grep -q 'network-manager'
LT_OS_RELEASE="$tmp/os-release" sh "$root/lib/connectivity-setup.sh" --module bluetooth --dry-run | grep -q 'bluez dbus'
echo 'OK: Wi-Fi y BlueZ con mocks, SSID, MAC, timeout, Alpine main/community y Debian.'
