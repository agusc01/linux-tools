# linux-tools

Herramientas personales y configuración de Fish para Alpine Linux y Debian.

**Primera entrega (rama de desarrollo):** configuración modular Fish y migración de las funciones de rotación de pantalla/táctil desde [rotate](https://github.com/agusc01/rotate). Todavía no están migrados Rofi, dbar, audio, Wi-Fi, Bluetooth ni dshortcuts.

Fish es obligatorio, pero lo instalará más adelante [linux-setup](https://github.com/agusc01/linux-setup) mediante apk/apt. En Alpine 3.24, Fish se encuentra en el repositorio **main**; no requiere community. linux-tools no instala paquetes del sistema ni cambia la shell predeterminada.

## Probar sin root

Mientras el PR está abierto, clonar la rama de desarrollo:

```sh
git clone -b feat/fish-rotate-core https://github.com/agusc01/linux-tools.git
cd linux-tools
sh install.sh --list
sh install.sh --modules fish,rotate --dry-run
```

La instalación es optativa: `sh install.sh --modules fish,rotate`. Instala una configuración adicional en `~/.config/fish/conf.d/linux-tools.fish`, **sin reemplazar config.fish** ni los alias actuales. Si se detectan funciones de rotación antiguas, se interrumpe para evitar sobrescribirlas.

Para migrar expresamente las cinco funciones originales de rotate, guardando copia de seguridad de las que se reemplacen:

```sh
sh install.sh --modules fish,rotate --migrate-rotate
```

Los backups se guardan en `~/.local/state/linux-tools/backups/` (o `$XDG_STATE_HOME/linux-tools/backups/`). No se borran `config.fish`, `fish_aliases.fish`, `fish_variables` ni ningún otro archivo ajeno.

```sh
sh uninstall.sh --modules fish,rotate --dry-run
sh uninstall.sh --modules fish,rotate
sh tests/check.sh
```

## Rotación

Comandos Fish: `r0`, `r90`, `r180`, `r270` y `rotar normal|derecha|invertida|izquierda`. Requiere Xorg, xrandr y xinput. Permite `ROTATE_OUTPUT` y `ROTATE_TOUCH`; los IDs del táctil se detectan dinámicamente.

## Diseño y pendientes

La configuración **nueva** no carga Bash, pero la configuración **antigua** de Fish sigue intacta hasta que migremos sus alias y utilidades. El instalador hace verificación previa de propiedad de todos los archivos, rechaza enlaces simbólicos y archivos ajenos, y permite simular operaciones sin cambios. Los repositorios originales no se archivan aún.

Los antiguos repositorios archivados dbar, dmenu y surf no se copian. Se migrará **la barra propia desde los scripts activos de Bash**, junto con menús Rofi y demás utilidades.

**No usar en producción sin revisar antes el dry-run.**
