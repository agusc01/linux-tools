#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/admin-paths.sh"

# Con PATH mínimo, la resolución NO debe depender de /sbin.
if [ -x /sbin/apk ]; then
    path=$(PATH=/usr/bin:/bin lt_admin_path apk)
    [ "$path" = /sbin/apk ] || { echo "Error: esperaba /sbin/apk, recibí $path" >&2; exit 1; }
    [ -x "$path" ]
fi
if lt_admin_path 'apk;sh' >/dev/null 2>&1; then
    echo 'Error: se permitió un comando externo al conjunto autorizado.' >&2
    exit 1
fi
if [ -x /usr/bin/apt-get ]; then
    path=$(PATH=/usr/bin:/bin lt_admin_path apt-get)
    [ "$path" = /usr/bin/apt-get ] || { echo "Error: ruta inesperada: $path" >&2; exit 1; }
fi
echo 'OK: comandos administrativos resueltos por ruta absoluta, sin depender de PATH.'
