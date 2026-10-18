#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/audio-hardware.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
export LT_AUDIO_SYSROOT="$tmp/sys" LT_AUDIO_FIRMROOT="$tmp/firmware"
export LT_AUDIO_CARDS_FILE="$tmp/cards"
mkdir -p "$tmp/sys/bus/acpi/devices" "$tmp/sys/bus/i2c/devices" "$tmp/firmware"
: > "$tmp/cards"

fail() { echo "FALLO: $*" >&2; exit 1; }
if lt_cherrytrail_nau8824; then fail 'no debería identificar hardware ausente'; fi
mkdir -p "$tmp/sys/bus/acpi/devices/808622A8:00" "$tmp/sys/bus/i2c/devices/i2c-10508824:00"
printf '0\n' > "$tmp/sys/bus/acpi/devices/808622A8:00/status"
lt_cherrytrail_nau8824 || fail 'no detectó dispositivo Cherry Trail/NAU8824'
[ "$(lt_audio_acpi_status)" = 0 ] || fail 'estado PCI desactivado'
if lt_audio_sof_ready; then fail 'detectó SOF ausente'; fi
if lt_audio_internal_card; then fail 'detectó tarjeta ALSA ausente'; fi

mkdir -p "$tmp/firmware/intel/sof" "$tmp/firmware/intel/sof-tplg"
: > "$tmp/firmware/intel/sof/sof-cht.ri.zst"
if lt_audio_sof_ready; then fail 'consideró suficiente solo el firmware'; fi
: > "$tmp/firmware/intel/sof-tplg/sof-cht-nau8824.tplg"
lt_audio_sof_ready || fail 'no aceptó archivos SOF comprimidos/no comprimidos'
printf '15\n' > "$tmp/sys/bus/acpi/devices/808622A8:00/status"
printf ' 0 [nau8824        ]: sof-bytcht nau8824\n' > "$tmp/cards"
lt_audio_internal_card || fail 'no detectó tarjeta NAU8824'

printf 'ID=alpine\nVERSION_ID=3.24.2\n' > "$tmp/os-release"
rm "$tmp/firmware/intel/sof/sof-cht.ri.zst"
LT_OS_RELEASE="$tmp/os-release" LT_AUDIO_BACKEND=missing \
    sh "$root/lib/audio-setup.sh" --dry-run > "$tmp/plan"
grep -q 'v3.24/community' "$tmp/plan" || fail 'repositorio temporal de versión equivocada'
grep -q 'sof-firmware' "$tmp/plan" || fail 'no ofrece firmware SOF'
grep -q 'LPE Audio ACPI' "$tmp/plan" || fail 'no documenta BIOS en reporte'

printf ' 1 [Audio          ]: HDMI-LPE\n' > "$tmp/cards"
: > "$tmp/firmware/intel/sof/sof-cht.ri.zst"
sh "$root/bin/lt-audio-save" status > "$tmp/report"
grep -q 'NAU8824 aún no detectada' "$tmp/report" || fail 'no advierte tarjeta ausente'
sh "$root/bin/lt-audio-save" --dry-run | grep -q 'alsactl store'

# Otro equipo nunca debe recibir la instalación de SOF, aun si faltan paquetes.
rm -rf "$tmp/sys/bus/i2c/devices/i2c-10508824:00"
rm "$tmp/firmware/intel/sof/sof-cht.ri.zst"
LT_OS_RELEASE="$tmp/os-release" LT_AUDIO_BACKEND=missing \
    sh "$root/lib/audio-setup.sh" --dry-run > "$tmp/plan"
if grep -q 'v3.24/community' "$tmp/plan"; then fail 'quería SOF en hardware ajeno'; fi
echo 'OK: Cherry Trail, SOF comprimido, firmware topología, BIOS y repo Alpine específico.'
