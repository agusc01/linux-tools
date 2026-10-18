#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/bin/lt-audio-save"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
# Ninguna prueba usa la tarjeta de sonido ni modifica el estado ALSA real.
sh "$root/bin/lt-audio-save" --dry-run | grep -q 'alsactl store'
if sh "$root/bin/lt-audio-save" export ruta/relativa >/dev/null 2>&1; then
    echo 'FALLO: export aceptó ruta relativa.' >&2; exit 1
fi
if sh "$root/bin/lt-audio-save" restore /ruta/inexistente >/dev/null 2>&1; then
    echo 'FALLO: restore aceptó archivo inexistente.' >&2; exit 1
fi
echo 'OK: validación de perfiles ALSA sin escribir hardware.'
