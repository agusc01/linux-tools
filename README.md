# linux-tools

Herramientas personales y configuración de Fish para Alpine Linux y Debian.

**Disponible en main:** Fish, rotación táctil, controles de volumen y brillo. El audio prepara ALSA automáticamente cuando falta un backend operativo (con permiso previo). Todavía faltan Rofi, dbar, Wi-Fi, Bluetooth y dshortcuts.

Fish es obligatorio, pero lo instalará más adelante [linux-setup](https://github.com/agusc01/linux-setup) mediante apk/apt. En Alpine 3.24, Fish se encuentra en el repositorio **main**; no requiere community. linux-tools puede instalar paquetes del sistema cuando se selecciona un módulo que los necesita y el usuario lo autoriza. No cambia la shell predeterminada ni requiere ejecutar el instalador completo como root.

## Instalación

La configuración personal se instala como usuario normal. Los paquetes del sistema se gestionan mediante permisos elevados solamente cuando hace falta:

```sh
git clone https://github.com/agusc01/linux-tools.git
cd linux-tools
sh install.sh --list
sh install.sh --dry-run
sh install.sh # Fish y rotación
sh install.sh --verify
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

## Audio y brillo

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

Audio detecta `pulsemixer`, `wpctl` (PipeWire), `pactl` (PulseAudio) o `amixer` (ALSA); permite `LT_AUDIO_BACKEND` para elegir. Brillo es atenuación lógica de X11 (requiere `xrandr` y sesión X11), con mínimo de 10% y `LT_DISPLAY_OUTPUT` para elegir monitor. Al seleccionar `audio`, el instalador detecta una salida de audio operativa y, si no existe, propone instalar ALSA (`alsa-utils` y, en Alpine/OpenRC, `alsa-utils-openrc`) usando **solo los repositorios habilitados**, sin activar community; con permiso del usuario puede ajustar el grupo `audio` y el servicio ALSA. Usa `doas`, `sudo` o `su` para los cambios privilegiados. `--dry-run` muestra el plan y `--yes` lo confirma sin interacción. `--no-deps` omite deliberadamente este paso (solo para pruebas o preparación manual). No fuerza PulseAudio ni PipeWire si ya existe audio funcional.

**Nota:** instalación de los paquetes no garantiza hardware de audio detectado. Si no hay tarjeta, permisos activos o dispositivo de salida, la instalación avisa y devuelve error. Tras agregar el usuario al grupo `audio`, es necesario cerrar la sesión y volver a entrar.

Para reparar una instalación anterior:

```sh
git pull --ff-only origin main
sh install.sh --modules audio --dry-run
sh install.sh --modules audio
lt-volume status
```
 Los módulos se pueden desinstalar por separado con `sh uninstall.sh --modules audio,brightness`, que conserva Fish y rotate.

Pruebas con servicios simulados: `sh tests/audio-brightness.sh`.

**Comando correcto:** `lt-volume status` (con guion y sin traducir `volume`). Si instalaste una versión anterior, actualizá `main` y ejecutá `sh install.sh --modules audio`. Esta operación conserva las funciones Fish, detecta el sistema de audio y ofrece instalar ALSA mediante `apk` o `apt-get`; no habilita `community` por su cuenta.


## Reinstalación del audio Cherry Trail + NAU8824 (Intel Atom x5-Z8350)

Este procedimiento reproduce el caso comprobado con Alpine en la notebook Cherry Trail: ACPI `808622A8:00`, códec I²C `10508824:00` y SOF `sof-cht.ri` + `sof-cht-nau8824.tplg`.

1. **Una sola vez en BIOS/UEFI:** `Chipset → Audio Configuration → LPE Audio Support → LPE Audio ACPI mode`. **No** cambiar automáticamente la BIOS ni usar `driver_override`. Si quedó en PCI Mode, el script advierte estado ACPI `0`; debería ser `15`.
2. Instalación como usuario normal, con `doas`, `sudo` o `su` ya configurado:
   ```sh
   sh install.sh --modules audio --dry-run
   sh install.sh --modules audio
   ```
   Detecta el hardware por los dos IDs; instala paquetes ALSA y, **solo si a este hardware le falta el firmware**, instala `sof-firmware` de `community` de la **misma versión estable de Alpine**, con `apk --repository` temporal. No modifica los repositorios configurados ni instala firmware Cherry Trail en otros equipos.
3. **Reiniciar** si se acaba de instalar `sof-firmware`, y comprobar `aplay -l`; debe aparecer `nau8824` además de HDMI.
4. **Ajustar los controles reales una vez** con `alsamixer -c 0` (F5, localizar `Speaker`, quitar `MM` con M y subir gradualmente) y comprobar la salida con `speaker-test -D plughw:0,0 -c 2 -r 48000 -t wav -l 1`, volumen moderado.
5. **Guardar la mezcla que comprobaste**, como usuario normal: `lt-audio-save save`. Usa `alsactl store` mediante elevación puntual y el servicio OpenRC `alsa` la restaurará en los próximos arranques. `lt-audio-save status` muestra el estado del hardware y el firmware.

No se fijan valores de volumen desconocidos ni se fuerza `Speaker` sobre todas las máquinas. El estado guardado en `/var/lib/alsa/asound.state` pertenece a esa instalación: **en una reinstalación con disco nuevo habrá que volver a ajustar el mezclador una vez**, a menos que se conserve también ese estado mediante un backup propio. El instalador puede automatizar los paquetes y la detección, pero no adivinar una mezcla que nunca se exportó al repositorio.

El módulo **no instala ni configura doas**. Un comando `doas: apk: command not found` está resuelto mediante rutas absolutas (`/sbin/apk`).


### Conservar exactamente los controles de la notebook para una reinstalación

Una vez que los parlantes funcionen, además de `lt-audio-save save` (estado persistente local), exportá la mezcla:

```sh
lt-audio-save export "$HOME/nau8824-working.state"
```

El respaldo se genera con permiso 0600, **no sobrescribe uno existente** y no requiere root si el usuario tiene acceso a ALSA. Guardalo en otra unidad o repositorio privado. No se incluye un estado de volumen genérico, porque algunos controles de entrada/salida dependen de la placa.

Luego de una **nueva instalación** con LPE Audio ACPI, firmware SOF y `nau8824` visibles en `aplay -l`, restauralo voluntariamente:

```sh
lt-audio-save restore "$HOME/nau8824-working.state"
```

El programa comprueba que haya una tarjeta NAU8824, pide confirmación, conserva el estado anterior y guarda la restauración para los próximos reinicios. No restaura respaldos automáticamente ni escribe perfiles para hardware desconocido.

### Comando de audio instalado y sus dependencias

El módulo `audio` instala `lt-audio-save` en `~/.local/bin` y las bibliotecas `admin-paths.sh` / `audio-hardware.sh` en `~/.local/share/linux-tools/lib/`. El comando localiza estas bibliotecas por su ubicación (no depende de ejecutar desde el repositorio ni de Bash). `sh install.sh --modules audio --verify` confirma que el comando instalado puede iniciarse realmente.

Si instalaste una versión antigua que mostraba `can't open .../.local/lib/admin-paths.sh`, actualizá `main` y repetí `sh install.sh --modules audio`: instalará las bibliotecas faltantes sin tocar tus controles ALSA existentes. Después ejecutá `lt-audio-save save` y `lt-audio-save export \"$HOME/nau8824-working.state\"`.
