#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Solo localiza comandos administrativos conocidos por rutas absolutas.
# doas/sudo/su pueden ejecutar con un PATH más restringido que el usuario.
lt_admin_path() {
    [ "$#" -eq 1 ] || return 2
    case "$1" in
        apk|apt-get|rc-service|rc-update|addgroup) : ;;
        *) echo "Error: comando administrativo no permitido: $1" >&2; return 2 ;;
    esac
    for directory in /sbin /usr/sbin /usr/bin /bin; do
        if [ -x "$directory/$1" ]; then
            printf '%s\n' "$directory/$1"
            return 0
        fi
    done
    echo "Error: no se encontró el comando administrativo $1." >&2
    return 1
}
