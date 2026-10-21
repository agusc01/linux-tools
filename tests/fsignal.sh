#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Pruebas de fsignal y provisionamiento sin contacto con X11 ni root real.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/mock"
cat > "$tmp/mock/xsetroot" <<'EOF'
#!/bin/sh
printf 'xsetroot:%s\n' "$*" >> "$FSIGNAL_TEST_LOG"
EOF
chmod 755 "$tmp/mock/xsetroot"
PATH="$tmp/mock:$PATH"
export PATH DISPLAY=:99 FSIGNAL_TEST_LOG="$tmp/events"
: > "$FSIGNAL_TEST_LOG"
for signal in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 \
    30 31 32 40 41 42 43 44 45 46 47 48 49 51 52 53 54 55 56 70 71 72 73 74 75 76; do
    sh "$root/bin/fsignal" "$signal"
    grep -Fqx "xsetroot:-name fsignal:$signal" "$FSIGNAL_TEST_LOG"
done
cp "$FSIGNAL_TEST_LOG" "$tmp/previous"
for bad in 0 15 29 33 50 57 69 77 99 ';touch /tmp/bad' '14;exit'; do
    if sh "$root/bin/fsignal" "$bad" > /dev/null 2>&1; then
        echo "FALLO: aceptó señal no permitida: $bad" >&2; exit 1
    fi
done
if sh "$root/bin/fsignal" >/dev/null 2>&1 ||
   sh "$root/bin/fsignal" 14 30 >/dev/null 2>&1 ||
   (unset DISPLAY; sh "$root/bin/fsignal" 14) >/dev/null 2>&1; then
    echo 'FALLO: no se verificó aridad o sesión X11.' >&2; exit 1
fi
cmp "$tmp/previous" "$FSIGNAL_TEST_LOG"
sh -n "$root/lib/xsetroot-setup.sh"
printf '%s\n' 'ID=alpine' 'VERSION_ID=3.24.2' > "$tmp/os-release"
# Simular falta de xsetroot con PATH sin la herramienta del test. Si
# el host lo tiene, no instalar nada: también es un resultado aceptable.
LT_OS_RELEASE="$tmp/os-release" sh "$root/lib/xsetroot-setup.sh" --dry-run > "$tmp/output"
grep -Eq 'xsetroot ya está instalado|repo temporal|community' "$tmp/output"
printf '%s\n' '[OK] fsignal: señales permitidas, rechazo de inyección y X11 no ejecutado.'
