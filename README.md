# linux-tools

Herramientas personales y configuración de Fish para Alpine Linux y Debian.

**Entregas:** Fish y rotación táctil integrados en main. Esta nueva rama incorpora audio y brillo X11 independientes de Bash. Todavía faltan Rofi, dbar, Wi-Fi, Bluetooth y dshortcuts.

Fish es obligatorio, pero lo instalará más adelante [linux-setup](https://github.com/agusc01/linux-setup) mediante apk/apt. En Alpine 3.24, Fish se encuentra en el repositorio **main**; no requiere community. linux-tools no instala paquetes del sistema ni cambia la shell predeterminada.

## Probar sin root

El siguiente ejemplo usa la rama de audio/brillo mientras se revisa el PR:

```sh
git clone -b feat/audio-brightness-tools https://github.com/agusc01/linux-tools.git
cd linux-tools
sh install.sh --list
sh install.sh --dry-run
sh install.sh --verify # Diagnóstico: comprueba archivos y comandos Fish instalados
```

La instalación predeterminada `sh install.sh` incorpora **Fish + rotate**, y luego ejecuta una verificación con Fish de que `r0`, `r90`, `r180`, `r270` y `rotar` son reconocidos. Para instalar únicamente Fish usá `sh install.sh --modules fish`. Instala una configuración adicional en `~/.config/fish/conf.d/linux-tools.fish`, **sin reemplazar config.fish** ni los alias actuales. Si se detectan funciones de rotación antiguas, se interrumpe para evitar sobrescribirlas.

Para migrar expresamente las cinco funciones originales de rotate, guardando copia de seguridad de las que se reemplacen:

```sh
sh install.sh --modules fish,rotate --migrate-rotate
```

Los backups se guardan en `~/.local/state/linux-tools/backups/` (o `$XDG_STATE_HOME/linux-tools/backups/`). No se borran `config.fish`, `fish_aliases.fish`, `fish_variables` ni ningún otro archivo ajeno.

```sh
sh install.sh --verify
sh uninstall.sh --dry-run
sh uninstall.sh --modules fish,rotate
sh tests/check.sh
```

## Rotación

Comandos Fish: `r0`, `r90`, `r180`, `r270` y `rotar normal|derecha|invertida|izquierda`. Requiere Xorg, xrandr y xinput. Permite `ROTATE_OUTPUT` y `ROTATE_TOUCH`; los IDs del táctil se detectan dinámicamente.

## Diseño y pendientes

La configuración **nueva** no carga Bash, pero la configuración **antigua** de Fish sigue intacta hasta que migremos sus alias y utilidades. El instalador hace verificación previa de propiedad de todos los archivos, rechaza enlaces simbólicos y archivos ajenos, y permite simular operaciones sin cambios. Los repositorios originales no se archivan aún.

Los antiguos repositorios archivados dbar, dmenu y surf no se copian. Se migrará **la barra propia desde los scripts activos de Bash**, junto con menús Rofi y demás utilidades.

**No usar en producción sin revisar antes el dry-run.**

## Audio y brillo (nueva rama)

Instalá los módulos opcionales sin modificar los alias que ya tenés:

```sh
sh install.sh --modules fish,rotate,audio,brightness --dry-run
sh install.sh --modules fish,rotate,audio,brightness
sh install.sh --modules fish,rotate,audio,brightness --verify
```

Comandos independientes de Bash/Fish:

```sh
lt-volume get
lt-volume up --notify
lt-volume down
lt-volume set 45
lt-volume toggle
lt-brightness status
lt-brightness down
lt-brightness set 70 --notify
```

También están las funciones Fish `lt_audio` y `lt_brightness` con los mismos argumentos. Esto **no reemplaza** todavía las funciones antiguas `s0`, `setsound`, `b0`, etc. La migración de dshortcuts/dwm será posterior.

Audio detecta `pulsemixer`, `wpctl` (PipeWire) o `pactl` (PulseAudio); permite `LT_AUDIO_BACKEND` para elegir. Brillo es atenuación lógica de X11 (requiere `xrandr` y sesión X11), con mínimo de 10% y `LT_DISPLAY_OUTPUT` para elegir monitor. La instalación no agrega paquetes ni toca configuración de audio ni servicios del sistema. Los módulos se pueden desinstalar por separado con `sh uninstall.sh --modules audio,brightness`, que conserva Fish y rotate.

Pruebas con servicios simulados: `sh tests/audio-brightness.sh`.
