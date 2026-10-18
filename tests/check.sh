#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

for script in install.sh uninstall.sh lib/common.sh tests/check.sh; do sh -n "$root/$script"; done
sh "$root/install.sh" --list | grep -q '^rotate '
for f in "$root/fish/conf.d/linux-tools.fish" "$root"/fish/functions/*.fish; do
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$f"
    if command -v fish >/dev/null 2>&1; then fish -n "$f"; fi
done
sh "$root/install.sh" --modules fish,rotate --dry-run >/dev/null

if [ "$(id -u)" -eq 0 ] || ! command -v fish >/dev/null 2>&1; then
    echo 'Integración omitida (requiere Fish y usuario no root).'
else
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' 0
    mkdir -p "$tmp/home/config/fish"

    setup_env() {
        HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/config" XDG_STATE_HOME="$tmp/home/state" "$@"
    }
    # config.fish antiguo debe permanecer intacto, incluso después de instalar.
    printf '%s\n' '# Alias antiguos' > "$tmp/home/config/fish/config.fish"
    setup_env sh "$root/install.sh" --modules fish,rotate >/dev/null
    test -f "$tmp/home/config/fish/conf.d/linux-tools.fish"
    grep -Fqx '# Alias antiguos' "$tmp/home/config/fish/config.fish"
    for name in r0 r90 r180 r270 rotar; do
        test -f "$tmp/home/config/fish/functions/$name.fish"
    done

    # Segunda instalación no cambia nada.
    setup_env sh "$root/install.sh" --modules fish,rotate | grep -q 'Sin cambios'
    setup_env sh "$root/uninstall.sh" --modules fish,rotate >/dev/null
    test ! -e "$tmp/home/config/fish/conf.d/linux-tools.fish"
    test ! -e "$tmp/home/config/fish/functions/rotar.fish"
    grep -Fqx '# Alias antiguos' "$tmp/home/config/fish/config.fish"

    # Si conf.d/linux-tools.fish ya existía, abortar sin instalar ninguna función.
    mkdir -p "$tmp/home/config/fish/conf.d"
    printf '%s\n' '# Archivo ajeno' > "$tmp/home/config/fish/conf.d/linux-tools.fish"
    if setup_env sh "$root/install.sh" --modules fish,rotate >/dev/null 2>&1; then
        echo 'FALLO: sobrescribió archivo ajeno.' >&2
        exit 1
    fi
    grep -Fqx '# Archivo ajeno' "$tmp/home/config/fish/conf.d/linux-tools.fish"
    test ! -e "$tmp/home/config/fish/functions/rotar.fish"
    rm "$tmp/home/config/fish/conf.d/linux-tools.fish"

    # La migración del antiguo rotate necesita permiso expreso y backup.
    mkdir -p "$tmp/home/config/fish/functions"
    printf '%s\n' '# rotate-managed: agusc01/rotate' 'function r90; end' > "$tmp/home/config/fish/functions/r90.fish"
    if setup_env sh "$root/install.sh" --modules rotate >/dev/null 2>&1; then
        echo 'FALLO: sobrescribió rotate sin permiso.' >&2
        exit 1
    fi
    test ! -e "$tmp/home/config/fish/functions/rotar.fish"
    setup_env sh "$root/install.sh" --modules rotate --migrate-rotate >/dev/null
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$tmp/home/config/fish/functions/r90.fish"
    saved=$(find "$tmp/home/state/linux-tools/backups" -name r90.fish -print -quit)
    test -n "$saved"
    grep -Fqx '# rotate-managed: agusc01/rotate' "$saved"

    # Rechazar enlaces simbólicos (también aunque se solicite migrar).
    setup_env sh "$root/uninstall.sh" --modules rotate >/dev/null
    printf '%s\n' '# externo' > "$tmp/home/external"
    ln -s "$tmp/home/external" "$tmp/home/config/fish/functions/r0.fish"
    if setup_env sh "$root/install.sh" --modules rotate --migrate-rotate >/dev/null 2>&1; then
        echo 'FALLO: siguió enlace simbólico.' >&2
        exit 1
    fi
    grep -Fqx '# externo' "$tmp/home/external"
    test -L "$tmp/home/config/fish/functions/r0.fish"
    grep -Fqx '# Alias antiguos' "$tmp/home/config/fish/config.fish"
fi
echo 'OK: sintaxis, propiedad, dry-run, idempotencia, conflictos, backups y desinstalación.'
