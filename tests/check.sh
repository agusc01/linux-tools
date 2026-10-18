#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

for script in install.sh uninstall.sh lib/common.sh tests/check.sh; do
    sh -n "$root/$script"
done
if ! sh "$root/install.sh" --list | grep -q '^rotate '; then
    echo 'FALLO: falta el módulo rotate.' >&2
    exit 1
fi
for f in "$root/fish/config.fish" "$root"/fish/functions/*.fish; do
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$f"
    if command -v fish >/dev/null 2>&1; then
        fish -n "$f"
    fi
done

# Dry-run sin necesidad de root, Fish ni Xorg.
sh "$root/install.sh" --modules fish,rotate --dry-run >/dev/null

# Nunca tocar la configuración real del desarrollador.
if [ "$(id -u)" -eq 0 ] || ! command -v fish >/dev/null 2>&1; then
    echo 'Integración omitida (requiere Fish y usuario no root).'
else
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' 0
    mkdir -p "$tmp/home"

    setup_env() {
        HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/config" XDG_STATE_HOME="$tmp/home/state" "$@"
    }
    setup_env sh "$root/install.sh" --modules fish,rotate >/dev/null
    for f in config.fish; do test -f "$tmp/home/config/fish/$f"; done
    for name in r0 r90 r180 r270 rotar; do
        test -f "$tmp/home/config/fish/functions/$name.fish"
    done

    # Repetir instalación = sin cambios.
    setup_env sh "$root/install.sh" --modules fish,rotate | grep -q 'Sin cambios'
    setup_env sh "$root/uninstall.sh" --modules fish,rotate >/dev/null
    test ! -e "$tmp/home/config/fish/config.fish"
    test ! -e "$tmp/home/config/fish/functions/rotar.fish"

    # Los archivos ajenos se mantienen intactos.
    mkdir -p "$tmp/home/config/fish"
    printf '%s\n' '# No tocar' > "$tmp/home/config/fish/config.fish"
    if setup_env sh "$root/install.sh" --modules fish,rotate >/dev/null 2>&1; then
        echo 'FALLO: sobrescribió archivo ajeno.' >&2
        exit 1
    fi
    grep -Fqx '# No tocar' "$tmp/home/config/fish/config.fish"
    test ! -e "$tmp/home/config/fish/functions/rotar.fish"

    # La migración expresa conserva backup del archivo previo.
    setup_env sh "$root/install.sh" --modules fish --migrate-fish >/dev/null
    saved=$(find "$tmp/home/state/linux-tools/backups" -name config.fish -print -quit)
    test -n "$saved"
    grep -Fqx '# No tocar' "$saved"

    # Migración rotate desde el identificador de propiedad antiguo.
    mkdir -p "$tmp/home/config/fish/functions"
    printf '%s\n' '# rotate-managed: agusc01/rotate' 'function r90; end' > "$tmp/home/config/fish/functions/r90.fish"
    if setup_env sh "$root/install.sh" --modules rotate >/dev/null 2>&1; then
        echo 'FALLO: sobrescribió rotate sin permiso.' >&2
        exit 1
    fi
    setup_env sh "$root/install.sh" --modules rotate --migrate-rotate >/dev/null
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$tmp/home/config/fish/functions/r90.fish"
    saved=$(find "$tmp/home/state/linux-tools/backups" -name r90.fish -print -quit)
    test -n "$saved"
    grep -Fqx '# rotate-managed: agusc01/rotate' "$saved"

    # Nunca seguir un enlace simbólico del usuario.
    setup_env sh "$root/uninstall.sh" --modules rotate >/dev/null
    printf '%s\n' '# externo' > "$tmp/home/external"
    ln -s "$tmp/home/external" "$tmp/home/config/fish/functions/r0.fish"
    if setup_env sh "$root/install.sh" --modules rotate >/dev/null 2>&1; then
        echo 'FALLO: siguió un enlace simbólico.' >&2
        exit 1
    fi
    grep -Fqx '# externo' "$tmp/home/external"
    test -L "$tmp/home/config/fish/functions/r0.fish"
fi
echo 'OK: sintaxis, propiedad, dry-run, reinstalación, conflictos, backups y uninstall.'
