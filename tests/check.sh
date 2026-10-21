#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

for script in install.sh uninstall.sh lib/common.sh lib/audio-setup.sh lib/audio-hardware.sh lib/admin-paths.sh lib/connectivity-setup.sh lib/rofi-setup.sh tests/check.sh tests/admin-paths.sh; do sh -n "$root/$script"; done
sh "$root/install.sh" --list | grep -q '^rotate '
for f in "$root/fish/conf.d/linux-tools.fish" "$root"/fish/functions/*.fish; do
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$f"
    if command -v fish >/dev/null 2>&1; then fish -n "$f"; fi
done
# Regresión: el instalador predeterminado DEBE seleccionar también rotate.
sh "$root/install.sh" --dry-run | grep -q 'r90.fish'
sh "$root/install.sh" --modules fish,rotate --dry-run >/dev/null
sh "$root/install.sh" --modules fish,rotate,audio,brightness --dry-run | grep -q lt-volume
sh "$root/install.sh" --modules aliases --dry-run | grep -q 'gaA'
sh "$root/tests/audio-brightness.sh"
sh "$root/tests/cherrytrail-audio.sh"
sh "$root/tests/audio-profiles.sh"
sh "$root/tests/admin-paths.sh"
sh "$root/tests/connectivity.sh"
sh "$root/tests/rofi.sh"
sh "$root/tests/rofi-menus.sh"
sh "$root/tests/rofi-system.sh"
sh "$root/tests/shortcuts.sh"
sh "$root/tests/friendly-commands.sh"

# Las dependencias se inspeccionan sin ejecutar apk/apt/doas/sudo ni alterar grupos.
tmp_os=$(mktemp)
trap 'rm -f "$tmp_os"' EXIT
printf '%s\n' 'ID=alpine' > "$tmp_os"
LT_OS_RELEASE="$tmp_os" LT_AUDIO_BACKEND=inexistente sh "$root/lib/audio-setup.sh" --dry-run | grep -q 'apk'
printf '%s\n' 'ID=debian' > "$tmp_os"
LT_OS_RELEASE="$tmp_os" LT_AUDIO_BACKEND=inexistente sh "$root/lib/audio-setup.sh" --dry-run | grep -q 'apt-get'
rm -f "$tmp_os"
trap - EXIT

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
    # El comando sin opciones instala también rotate (regresión del fallo original).
    setup_env sh "$root/install.sh" >/dev/null
    setup_env sh "$root/install.sh" --verify | grep -q 'OK: Fish reconoce r90'
    setup_env fish -c 'type -q r0; and type -q r90; and type -q r180; and type -q r270; and type -q rotar'
    test -f "$tmp/home/config/fish/conf.d/linux-tools.fish"
    # Simular PATH del usuario en Alpine sin sbin y comprobar el Fish instalado.
    setup_env env PATH=/usr/bin:/bin fish -c 'contains -- /sbin $PATH; and contains -- /usr/sbin $PATH'
    grep -Fqx '# Alias antiguos' "$tmp/home/config/fish/config.fish"
    for name in r0 r90 r180 r270 rotar; do
        test -f "$tmp/home/config/fish/functions/$name.fish"
    done

    # Segunda instalación no cambia nada.
    setup_env sh "$root/install.sh" --modules fish,rotate | grep -q 'Sin cambios'
    # Los módulos nuevos se instalan por separado sin borrar los originales.
    setup_env sh "$root/install.sh" --modules fish,rotate,audio,brightness --no-deps >/dev/null
    # La verificación comprueba un dispositivo ALSA utilizable, no solo el archivo.
    mkdir -p "$tmp/mock"
    cat > "$tmp/mock/amixer" <<'EOF'
#!/bin/sh
if [ "$1" = sget ] && [ "$2" = Master ]; then
    printf "Simple mixer control 'Master',0\n  Mono: Playback 0 [42%%] [on]\n"
else
    exit 1
fi
EOF
    chmod +x "$tmp/mock/amixer"
    PATH="$tmp/mock:$PATH"
    LT_AUDIO_BACKEND=alsa
    export PATH LT_AUDIO_BACKEND
    setup_env sh "$root/install.sh" --modules fish,rotate,audio,brightness --verify | grep -q 'OK: lt_audio'
    setup_env sh "$root/install.sh" --modules fish,rotate,audio,brightness --verify | grep -q 'OK: lt_brightness'
    test -x "$tmp/home/.local/bin/lt-audio-save"
    test -f "$tmp/home/.local/share/linux-tools/lib/admin-paths.sh"
    test -f "$tmp/home/.local/share/linux-tools/lib/audio-hardware.sh"
    # Regresión: ejecutable instalado fuera del checkout, incluso desde /tmp,
    # debe resolver sus bibliotecas y no solo tener permiso +x.
    ( cd / && setup_env sh "$tmp/home/.local/bin/lt-audio-save" status ) |
        grep -q 'Hardware Cherry Trail'
    ( cd / && setup_env sh "$tmp/home/.local/bin/lt-audio-save" --dry-run ) |
        grep -q 'alsactl store'
    test -x "$tmp/home/.local/bin/lt-volume"
    test -x "$tmp/home/.local/bin/lt-brightness"
    test -x "$tmp/home/.local/bin/s0"
    test -x "$tmp/home/.local/bin/b1"
    setup_env sh "$root/install.sh" --modules wifi,bluetooth --no-deps >/dev/null
    test -x "$tmp/home/.local/bin/lt-wifi"
    test -x "$tmp/home/.local/bin/lt-bluetooth"
    test -f "$tmp/home/config/fish/functions/lt_wifi.fish"
    test -f "$tmp/home/config/fish/functions/lt_bluetooth.fish"
    setup_env sh "$root/install.sh" --modules rofi --no-deps >/dev/null
    test -x "$tmp/home/.local/bin/lt-rofi"
    test -f "$tmp/home/config/fish/functions/lt_rofi.fish"
    test -x "$tmp/home/.local/bin/rofi_launcher"
    test -x "$tmp/home/.local/bin/rofi_menu"
    for menu in rofi_internet rofi_volume rofi_brightness; do
        test -x "$tmp/home/.local/bin/$menu"
    done
    for menu in rofi_power rofi_layout rofi_microphone rofi_camera; do
        test -x "$tmp/home/.local/bin/$menu"
    done
    for theme in askpass brightness camera confirm global internet layout menu microphone power rofi rotation volume; do
        test -f "$tmp/home/config/linux-tools/rofi/$theme.rasi"
    done
    setup_env sh "$root/install.sh" --modules aliases --no-deps >/dev/null
    setup_env sh "$root/install.sh" --modules aliases --verify | grep -Fq 'Verificación correcta.'
    setup_env fish -c 'command -sq g; and command -sq gs; and functions -q dw; and functions -q cdwm'
    test -x "$tmp/home/.local/bin/gaA"
    test -f "$tmp/home/config/fish/functions/cdshortcuts.fish"
    setup_env sh "$root/install.sh" --modules shortcuts --no-deps >/dev/null
    test -x "$tmp/home/.local/bin/lt-shortcut"
    setup_env sh "$root/uninstall.sh" --modules aliases >/dev/null
    test ! -e "$tmp/home/.local/bin/gs"
    test ! -e "$tmp/home/config/fish/functions/cdwm.fish"
    setup_env sh "$root/uninstall.sh" --modules shortcuts >/dev/null
    test ! -e "$tmp/home/.local/bin/lt-shortcut"
    setup_env sh "$root/uninstall.sh" --modules rofi >/dev/null
    test ! -e "$tmp/home/.local/bin/lt-rofi"
    test ! -e "$tmp/home/.local/bin/rofi_launcher"
    for menu in rofi_internet rofi_volume rofi_brightness; do
        test ! -e "$tmp/home/.local/bin/$menu"
    done
    for menu in rofi_power rofi_layout rofi_microphone rofi_camera; do
        test ! -e "$tmp/home/.local/bin/$menu"
    done
    for theme in askpass brightness camera confirm global internet layout menu microphone power rofi rotation volume; do
        test ! -e "$tmp/home/config/linux-tools/rofi/$theme.rasi"
    done
    setup_env sh "$root/uninstall.sh" --modules wifi,bluetooth >/dev/null
    test ! -e "$tmp/home/.local/bin/lt-wifi"
    test ! -e "$tmp/home/.local/bin/lt-bluetooth"
    setup_env sh "$root/uninstall.sh" --modules audio,brightness >/dev/null
    # Desinstalar módulos opcionales no debe eliminar la configuración Fish.
    test -f "$tmp/home/config/fish/conf.d/linux-tools.fish"
    test -f "$tmp/home/config/fish/functions/rotar.fish"
    test ! -e "$tmp/home/.local/bin/lt-audio-save"
    test ! -e "$tmp/home/.local/share/linux-tools/lib/admin-paths.sh"
    test ! -e "$tmp/home/.local/share/linux-tools/lib/audio-hardware.sh"
    test ! -e "$tmp/home/.local/bin/lt-volume"
    test ! -e "$tmp/home/.local/bin/lt-brightness"
    test ! -e "$tmp/home/.local/bin/s0"
    test ! -e "$tmp/home/.local/bin/b0"
    setup_env sh "$root/uninstall.sh" --modules fish,rotate >/dev/null
    test ! -e "$tmp/home/config/fish/conf.d/linux-tools.fish"
    test ! -e "$tmp/home/config/fish/functions/rotar.fish"
    grep -Fqx '# Alias antiguos' "$tmp/home/config/fish/config.fish"

    # Conflictos de alias: preservar un ejecutable personal y no instalar nada.
    printf '%s\n' '# Alias Git ajeno' > "$tmp/home/.local/bin/gs"
    if setup_env sh "$root/install.sh" --modules aliases --no-deps >/dev/null 2>&1; then
        echo 'FALLO: se sobrescribió gs ajeno.' >&2; exit 1
    fi
    grep -Fqx '# Alias Git ajeno' "$tmp/home/.local/bin/gs"
    test ! -e "$tmp/home/.local/bin/ga"
    rm "$tmp/home/.local/bin/gs"

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
