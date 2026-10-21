#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Comandos de acceso directo: probar con motores simulados, nunca tocar audio/X11/Git real.
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin"
export LT_SHORT_COMMANDS_LOG="$tmp/commands.log"
for tool in lt-volume lt-brightness lt-rofi git; do
    cat > "$tmp/bin/$tool" <<'EOF'
#!/bin/sh
printf '%s:%s\n' "$(basename "$0")" "$*" >> "$LT_SHORT_COMMANDS_LOG"
EOF
    chmod 755 "$tmp/bin/$tool"
done
PATH="$tmp/bin:$PATH"; export PATH
check() {
    name=$1; expected=$2; shift 2
    : > "$LT_SHORT_COMMANDS_LOG"
    sh "$root/bin/$name" "$@"
    grep -Fqx "$expected" "$LT_SHORT_COMMANDS_LOG" || {
        echo "FALLO: $name no produjo $expected" >&2; exit 1
    }
}
check s0 'lt-volume:down --notify'
check s1 'lt-volume:up --notify'
check smute 'lt-volume:mute --notify'
check sunmute 'lt-volume:unmute --notify'
check stogglemute 'lt-volume:toggle --notify'
check b0 'lt-brightness:down --notify'
check b1 'lt-brightness:up --notify'
check rofi_launcher 'lt-rofi:apps'
check rofi_runner 'lt-rofi:run'
check rofi_window 'lt-rofi:windows'
check rofi_menu 'lt-rofi:menu'
check g 'git:status' status
check ga 'git:add a.txt' a.txt
check gaA 'git:add -A'
check gau 'git:add -u'
check gs 'git:status'
check gss 'git:status -s'
check gct 'git:commit'
check gctm 'git:commit -m Un mensaje' 'Un mensaje'
check gpull 'git:pull'
check gpullremote 'git:pull'
check gamend 'git:commit --amend'
if sh "$root/bin/s0" '--notify' > /dev/null 2>&1; then
    echo 'FALLO: un acceso directo aceptó argumentos silenciosamente.' >&2; exit 1
fi
# Al pasar un argumento arbitrario a Git, nunca se interpreta como código shell.
check ga 'git:add ; touch /tmp/should-not-execute' '; touch /tmp/should-not-execute'
for name in s0 s1 smute sunmute stogglemute b0 b1 rofi_launcher rofi_runner rofi_window rofi_menu \
    g ga gaA gau gs gss gct gctm gpull gpullremote gamend; do
    sh -n "$root/bin/$name"
    grep -Fqx '# linux-tools-managed: agusc01/linux-tools' "$root/bin/$name"
done
echo 'OK: accesos directos Bash/sh independientes, argumentos seguros y motores reutilizados.'
