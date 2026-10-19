#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Instala dependencias explícitas sin sustituir una red Wi-Fi ya conectada.
set -eu
# También al ejecutar directamente desde una shell con PATH mínimo de Alpine.
PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"
export PATH
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$root/lib/admin-paths.sh"
module=''
dry_run=0
yes=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --module) [ "$#" -gt 1 ] || exit 2; module=$2; shift ;;
        --dry-run) dry_run=1 ;;
        --yes) yes=1 ;;
        *) echo "Opción desconocida: $1" >&2; exit 2 ;;
    esac
    shift
done
case "$module" in wifi|bluetooth) : ;; *) echo 'Error: elegí wifi o bluetooth.' >&2; exit 2 ;; esac
release=${LT_OS_RELEASE:-/etc/os-release}
[ -r "$release" ] || exit 1
. "$release"
repo=''
# Si ya hay conexión administrada por wpa_supplicant, no instalar
# NetworkManager ni cambiar el backend: para consultas basta iw (main).
wifi_wpa_active() {
    if command -v pidof >/dev/null 2>&1 && pidof wpa_supplicant >/dev/null 2>&1; then
        return 0
    fi
    if command -v pgrep >/dev/null 2>&1 && pgrep -x wpa_supplicant >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
wifi_legacy=0
if [ "$module" = wifi ] && wifi_wpa_active; then
    wifi_legacy=1
fi
case "$ID" in
    alpine)
        package_manager=apk
        if [ "$module" = wifi ]; then
            major=${VERSION_ID%%.*}
            tail_version=${VERSION_ID#*.}
            minor=${tail_version%%.*}
            case "$major:$minor" in
                *[!0-9:]*|:*|*:) echo 'Error: versión Alpine no reconocida.' >&2; exit 1 ;;
            esac
            if [ "$wifi_legacy" -eq 1 ]; then
                packages='iw'
            else
                repo="https://dl-cdn.alpinelinux.org/alpine/v$major.$minor/community"
                packages='networkmanager networkmanager-cli networkmanager-wifi networkmanager-openrc wpa_supplicant'
            fi
        else
            packages='bluez bluez-openrc dbus dbus-openrc'
        fi ;;
    debian|ubuntu)
        package_manager=apt-get
        if [ "$module" = wifi ]; then
            if [ "$wifi_legacy" -eq 1 ]; then packages=iw
            else packages=network-manager; fi
        else packages='bluez dbus'; fi ;;
    *) echo "Error: distribución no soportada: $ID" >&2; exit 1 ;;
esac
if [ "$module" = wifi ]; then
    if [ "$wifi_legacy" -eq 1 ]; then
        echo 'Wi-Fi: wpa_supplicant ya está activo. Solo se necesita iw; no se instala ni activa NetworkManager.'
    else
        echo 'Wi-Fi: se instalará nmcli, pero NO se reemplazará el gestor de red actual.'
        echo 'Migrar desde wpa_supplicant requiere un paso manual para evitar cortar Internet.'
    fi
else
    echo 'Bluetooth: se prepararán BlueZ y D-Bus; en Alpine se habilitarán sus servicios OpenRC.'
fi
echo "Paquetes: $packages"
[ -z "$repo" ] || echo "Repositorio temporal: $repo (no modifica /etc/apk/repositories)"
if [ "$dry_run" -eq 1 ]; then
    echo 'Simulación: ningún cambio de paquetes ni servicios.'
    exit 0
fi
if [ "$yes" -eq 0 ]; then
    [ -t 0 ] || { echo 'Error: confirmación interactiva requerida o usá --yes.' >&2; exit 2; }
    printf '¿Aplicar cambios de dependencias? [s/N]: '
    IFS= read -r answer || answer=''
    case "$answer" in s|S|si|Si|SI) : ;; *) echo 'Cancelado.'; exit 2 ;; esac
fi
admin() {
    binary=$(lt_admin_path "$1") || return 1
    shift
    if [ "$(id -u)" -eq 0 ]; then
        "$binary" "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$binary" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$binary" "$@"
    elif command -v su >/dev/null 2>&1; then
        for argument in "$binary" "$@"; do
            case "$argument" in
                *[!a-zA-Z0-9_./:-]*|'') echo 'Argumento administrativo inseguro.' >&2; return 2 ;;
            esac
        done
        su -c "$binary $*"
    else
        echo 'Error: se necesita su, doas o sudo para instalar paquetes.' >&2
        return 1
    fi
}
if [ "$package_manager" = apk ]; then
    if [ -n "$repo" ]; then
        admin apk add --no-cache --repository "$repo" $packages
    else
        admin apk add --no-cache $packages
    fi
else
    admin apt-get install -y $packages
fi
if [ "$module" = bluetooth ]; then
    if [ "$ID" = alpine ] && [ -f /etc/init.d/bluetooth ] && [ -f /etc/init.d/dbus ]; then
        admin rc-update add dbus default
        admin rc-service dbus start || admin rc-service dbus status
        admin rc-update add bluetooth default
        admin rc-service bluetooth start || admin rc-service bluetooth status
    fi
    if ! command -v bluetoothctl >/dev/null 2>&1; then
        echo 'Error: BlueZ fue instalado pero bluetoothctl no aparece en PATH.' >&2
        exit 1
    fi
    echo 'Bluetooth preparado. Si no hay adaptador, comprobá bluetoothctl list y rfkill.'
else
    if [ "$wifi_legacy" -eq 1 ]; then
        if ! command -v iw >/dev/null 2>&1; then
            echo 'Error: falta el comando iw después de instalar su paquete.' >&2
            exit 1
        fi
        echo 'OK: Wi-Fi existente conservado; ahora lt-wifi status/list puede utilizar iw.'
    else
        if ! command -v nmcli >/dev/null 2>&1; then
            echo 'Error: se instalaron paquetes pero no está disponible nmcli.' >&2
            exit 1
        fi
        if nmcli -t -f RUNNING general 2>/dev/null | grep -qx running; then
            echo 'OK: NetworkManager ya está funcionando.'
        else
            echo 'AVISO: NetworkManager no está en ejecución. No se modifica la red existente.'
            echo 'Para migrar sin perder Internet, revisá https://wiki.alpinelinux.org/wiki/NetworkManager .'
        fi
    fi
fi
