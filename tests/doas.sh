#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
sh -n "$root/modules/doas/bootstrap.sh"
sh -n "$root/modules/doas/root-setup.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
printf '%s\n' ID=alpine > "$tmp/os-release"
LT_DOAS_OS_RELEASE="$tmp/os-release" sh "$root/modules/doas/root-setup.sh" --user nobody --dry-run > "$tmp/result"
grep -q 'gestor: apk' "$tmp/result"
grep -q '/etc/doas.d/90-linux-tools.conf' "$tmp/result"
grep -q 'permit nobody as root' "$tmp/result"
printf '%s\n' ID=debian > "$tmp/os-release"
LT_DOAS_OS_RELEASE="$tmp/os-release" sh "$root/modules/doas/root-setup.sh" --user nobody --dry-run > "$tmp/result"
grep -q 'gestor: apt-get' "$tmp/result"
grep -q '/etc/doas.conf' "$tmp/result"
if sh "$root/modules/doas/root-setup.sh" --user root --dry-run >/dev/null 2>&1; then
    echo 'FALLO: aceptó autorización doas para root.' >&2; exit 1
fi
if sh "$root/modules/doas/root-setup.sh" --user 'bob;rm -rf /' --dry-run >/dev/null 2>&1; then
    echo 'FALLO: aceptó nombre de usuario peligroso.' >&2; exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
    sh "$root/install.sh" --modules doas --dry-run > "$tmp/result"
    grep -q 'permit ' "$tmp/result"
fi
echo 'OK: doas Alpine/Debian dry-run, seguridad de argumentos y bootstrap con su.'
