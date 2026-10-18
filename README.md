# linux-tools

Herramientas personales y configuración de Fish para Alpine Linux y Debian.

**Primera entrega (rama de desarrollo):** configuración de Fish y migración de las funciones de rotación de pantalla/táctil desde [rotate](https://github.com/agusc01/rotate). Todavía no están migrados Rofi, dbar, audio, Wi-Fi, Bluetooth ni dshortcuts.

Fish es obligatorio, pero lo instalará más adelante [linux-setup](https://github.com/agusc01/linux-setup) mediante apk/apt. linux-tools no instala paquetes del sistema ni cambia la shell predeterminada.

## Instalar sin root

```sh
git clone https://github.com/agusc01/linux-tools.git
cd linux-tools
sh install.sh --list
sh install.sh --modules fish,rotate --dry-run
sh install.sh --modules fish,rotate
```

Si ya tenés la configuración del repositorio anterior de Fish o las funciones de rotate, se detendrá con un conflicto. Para migrar **voluntariamente**, guardando backup:

```sh
sh install.sh --modules fish,rotate --migrate-fish --migrate-rotate
```

Los backups se guardan bajo ~/.local/state/linux-tools/backups/. No se borran archivos extra (fish_aliases.fish, fish_variables, etc.).

```sh
sh uninstall.sh --modules fish,rotate --dry-run
sh uninstall.sh --modules fish,rotate
sh tests/check.sh
```

## Rotación

Comandos Fish: r0, r90, r180, r270; también rotar normal|derecha|invertida|izquierda. Requiere Xorg, xrandr, xinput. Permite configurar ROTATE_OUTPUT y ROTATE_TOUCH, y no conserva IDs del táctil entre reinicios.

## Diseño

La configuración de Fish no carga alias Bash. Cada módulo tiene propiedad identificable; se rechazan enlaces simbólicos y archivos no administrados. El repositorio original rotate permanece intacto hasta finalizar la migración. Repositorios archivados dbar, dmenu y surf no se copiarán. Las funcionalidades de dbar y menús Rofi se migrarán desde los scripts activos de Bash.

**No usar en producción sin revisar antes el dry-run.**
