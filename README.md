# linux-tools

Herramientas personales y configuración de Fish para Alpine Linux y Debian.

**Disponible:** Fish, rotación táctil, controles de volumen y brillo, utilidades Wi-Fi/Bluetooth, Rofi y dispatcher de dshortcuts. Audio prepara ALSA cuando hace falta (con permiso previo). Dbar y los menús Rofi personalizados antiguos siguen pendientes.

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

## Primera migración de nombres cortos desde agusc01/bash

La lógica continúa en **POSIX sh**, accesible tanto desde Bash como Fish, dwm o dshortcuts a través de `~/.local/bin`. Fish sólo contiene las funciones que necesitan modificar el directorio de la consola (`cd`); no se importa ni ejecuta `.bash_aliases`. La migración es **opt-in por módulo**, no sobrescribe comandos personales ni altera `config.fish`.

| Módulo | Nuevos comandos directos | Motor reutilizado |
| --- | --- | --- |
| `audio` | `s0`, `s1`, `smute`, `sunmute`, `stogglemute` | `lt-volume` (notifica) |
| `brightness` | `b0`, `b1` | `lt-brightness` (notifica) |
| `rofi` | `rofi_launcher`, `rofi_runner`, `rofi_window`, `rofi_menu` | `lt-rofi` |
| `aliases` | `g`, `ga`, `gaA`, `gau`, `gs`, `gss`, `gct`, `gctm`, `gpull`, `gpullremote`, `gamend` | `git` |
| `aliases` | `dw`, `dk`, `dc`, `pic`, `cdwm`, `cst`, `cslock`, `cdshortcuts` | funciones Fish `cd` |

Se eligieron **nombres invocables sin parámetros** en las acciones cotidianas y autocompletables por Fish. Los comandos Git que necesitan destino o texto (por ejemplo `ga archivo` y `gctm "Mensaje"`) siguen aceptando los argumentos propios de Git. `--modules aliases` se instala independientemente, sin instalar paquetes ni modificar la configuración de Git.

Ejemplo en una instalación que ya tenga los módulos fundamentales:

```sh
sh install.sh --modules audio,brightness,rofi,aliases --dry-run
sh install.sh --modules audio,brightness,rofi,aliases
sh install.sh --modules audio,brightness,rofi,aliases --verify
s0
b1
rofi_launcher
gs
cdwm                 # función Fish: solo cambia de carpeta
```

Para desinstalar **únicamente archivos administrados**, `sh uninstall.sh --modules aliases` o seleccioná el módulo concreto de audio, brillo o Rofi. El instalador aborta si algún nombre ya existe como archivo ajeno o enlace, antes de escribir archivos. `gs` también es el nombre habitual del ejecutable Ghostscript: instalar nuestro acceso directo lo prioriza en `~/.local/bin` dentro de Fish; seleccioná el módulo sólo si querés ese comportamiento.

**No son migraciones completas de comportamiento:** `rofi_menu` usa el menú simplificado actual de linux-tools, no el antiguo menú de 16 opciones; `rofi_internet` sigue pendiente porque era un menú de marcadores web, **no un menú Wi-Fi**. Los controles de brillo sólo actúan sobre una salida, a diferencia del antiguo `b0`/`b1` multimonitor, y `cdwm` navega a fuentes persistentes pero no ejecuta automáticamente `git pull && nvim` para proteger ediciones locales. Otros alias, RASI, dbar, menús de energía y control del micrófono quedan para entregas posteriores.

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

También están las funciones Fish `lt_audio` y `lt_brightness` con los mismos argumentos. Los comandos cortos `s0`, `s1`, `b0` y `b1` se instalan ahora junto a esos motores. La migración de `setsound` y otras funciones será posterior.

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

## Wi-Fi y Bluetooth (independientes de Bash)

Los comandos antiguos se conservan sin sobrescribirse. Nuevos comandos portables:

```sh
sh install.sh --modules wifi,bluetooth --dry-run
sh install.sh --modules wifi,bluetooth
lt-wifi status
lt-wifi list
lt-wifi connect "NOMBRE DE RED"
lt-wifi off
lt-wifi on
lt-bluetooth status
lt-bluetooth devices
lt-bluetooth scan 8
lt-bluetooth power on
lt-bluetooth pair AA:BB:CC:DD:EE:FF
lt-bluetooth trust AA:BB:CC:DD:EE:FF
lt-bluetooth connect AA:BB:CC:DD:EE:FF
```

Fish expone `lt_wifi` y `lt_bluetooth`. La contraseña de Wi-Fi se introduce interactivamente con `nmcli --ask`: **no se escribe en el historial ni en un argumento del proceso**. Bluetooth utiliza direcciones MAC, no búsquedas por nombres aproximados. Los escaneos finalizan tras 1–30 segundos, sin matar procesos ajenos.

**Alpine**: BlueZ y D-Bus se instalan desde `main` y se habilitan sus servicios OpenRC si seleccionaste Bluetooth. Para Wi-Fi, NetworkManager/nmcli se instala con `community` de la **misma versión estable** de Alpine como repositorio temporal (sin alterar `/etc/apk/repositories`), solo con consentimiento.

**Importante, no perder conectividad:** instalar el cliente `nmcli` **no habilita ni sustituye automáticamente** `wpa_supplicant`, `networking` u otro servicio que ya gestiona Internet. Si NetworkManager no está operativo, `lt-wifi` explica el motivo y la migración queda pendiente. Consultá la [guía de NetworkManager de Alpine](https://wiki.alpinelinux.org/wiki/NetworkManager) antes de parar servicios o migrar conexiones. Tampoco se desinstalan los paquetes ni se apagan servicios al quitar funciones de linux-tools.

Bluetooth no instala audio inalámbrico en ALSA automáticamente: BlueZ gestiona el emparejamiento; el audio Bluetooth requiere configurar un servidor compatible (PipeWire/PulseAudio o bluez-alsa) por separado. El módulo `doas` continúa fuera de linux-tools.

## PATH administrativo de Fish en Alpine

La instalación básica añade automáticamente `/sbin`, `/usr/sbin` y `/usr/local/sbin` **al final** del `PATH` de las sesiones Fish cuando existan. Ahora se pueden ejecutar `wpa_cli`, `rc-service`, `modprobe` y `apk` sin rutas completas, siempre que el ejecutable esté instalado. No cambia `/etc/profile`, no añade rutas de root al principio, no crea aliases ni concede privilegios.

Después de `sh install.sh --modules fish --no-deps`, recargá `source ~/.config/fish/conf.d/linux-tools.fish` en tu terminal actual o abrí otra terminal. Probá `command -v wpa_cli`.

## Wi-Fi sobre wpa_supplicant activo, sin NetworkManager

Si el sistema usa `wpa_supplicant` para `wlan0` y `udhcpc` para DHCP, el instalador detecta el proceso existente y prepara únicamente `iw` desde el repositorio `main`, sin habilitar NetworkManager ni modificar la red conectada:

```sh
sh install.sh --modules fish,wifi --dry-run
sh install.sh --modules fish,wifi
lt-wifi status
lt-wifi list
```

`status` obtiene datos de asociación mediante `iw dev wlan0 link` incluso si `wpa_cli -i wlan0 ping` falla con `No such file or directory` (socket de control ausente). `list` realiza un escaneo con `iw` y, si necesita permisos, solicita elevación puntual con `doas` o `sudo`. No detiene el servicio y no lee ni muestra contraseñas.

Para `connect` y `connections` mediante `wpa_supplicant`, se requiere el socket de control habilitado y permiso para el usuario; solo se permiten redes **previamente configuradas**. Si falta, `lt-wifi` da instrucciones sin reiniciar el servicio ni escribir archivos sensibles. En Alpine la guía oficial explica `ctrl_interface=/run/wpa_supplicant` y `ctrl_interface_group=wheel`, que requieren una actualización deliberada del archivo de configuración y un reinicio programado del servicio. **No se cambia ese archivo desde linux-tools** y no se pide la contraseña mediante parámetros de línea de comandos.

Fuentes: [Alpine Wi-Fi](https://wiki.alpinelinux.org/wiki/Wi-Fi).

### Diagnóstico de Wi-Fi y BusyBox en Alpine

`lt-wifi status` usa `ip addr show dev wlan0`, compatible con BusyBox, en lugar de `ip -brief` (no disponible en la utilidad básica de Alpine). `lt-wifi list` usa `iw` para escanear sin cambiar de red.

Si `wpa_cli -i wlan0 ping` falla con `No such file or directory`, `lt-wifi doctor` comprueba de forma **solo lectura** el estado del control socket e informa qué claves globales faltan. El proceso `wpa_supplicant` no necesita reiniciarse para `status` y `list`.

Para habilitar la administración de redes guardadas, agregá si no existen estas dos directivas **al principio** de `/etc/wpa_supplicant/wpa_supplicant.conf`, fuera de `network={ ... }`, después de hacer una copia de seguridad privada:
```ini
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=wheel
```
**Precaución:** cualquier miembro de `wheel` podrá controlar redes a través del socket; asegurate de que ese acceso sea aceptable. Es necesario reiniciar el servicio **manualmente** cuando puedas permitir una desconexión breve. No pegar el archivo de configuración completo en tickets ni en un chat porque puede contener PSK. La opción `update_config=1` es **opcional** y solo es necesaria si posteriormente se quiere guardar cambios de redes con `wpa_cli save_config`; no se activa automáticamente.

## Menús Rofi restaurados desde el repositorio Bash (primera etapa)

`rofi_internet`, `rofi_volume` y `rofi_brightness` son ahora **ejecutables POSIX `sh` independientes** en `~/.local/bin`; Fish los reconoce con autocompletado sin argumentos. `rofi_menu` (menú principal) muestra accesos a los tres, conservando los otros accesos existentes. También pueden invocarse desde un atajo dwm o desde Bash, sin usar `fish -c`.

```sh
sh install.sh --modules rofi,audio,brightness --dry-run
sh install.sh --modules rofi,audio,brightness
rofi_internet
rofi_volume
rofi_brightness
rofi_menu
```

- **`rofi_internet`** recupera 12 marcadores (DuckDuckGo AI, GitHub, pestaña nueva, DuckDuckGo, Google, Gmail, YouTube, Spotify, Google Drive, traducción EN→ES/ES→EN y WhatsApp Web). Tras seleccionar, permite elegir entre navegación **normal** y **privada**; usa `firefox-esr`, `firefox` o `librewolf`, por ese orden, si están instalados. Firefox/LibreWolf **no se instalan automáticamente**: el instalador Rofi no requiere un navegador específico. Se corrige el error de URL antiguo de Drive. Cancelar cualquiera de los dos diálogos no abre el navegador.
- **`rofi_volume`** muestra el estado de `lt-volume`, permite subir/bajar 10 %, silenciar, activar sonido o fijar 0–100 % en incrementos de 10 %. Los ajustes rápidos mantienen abierto el menú, el porcentaje final lo cierra. Elegir un porcentaje positivo reactiva audio como el menú original. Reutiliza ALSA/PulseAudio/PipeWire; no depende de `pulsemixer`.
- **`rofi_brightness`** muestra la salida X11 y su brillo; permite subir/bajar 10 % o fijar 10–100 %. Usa el backend existente `lt-brightness`, que **solo ajusta una salida** (prioriza pantalla interna); no reproduce el ajuste multimonitor del Bash antiguo.

Ninguno de los menús interpreta texto libre como órdenes, evalúa código ni modifica tus fuentes de dwm. Se rechazan selecciones desconocidas y se conserva el menú Rofi del sistema **sin sobrescribir tus temas `.rasi` personales**. La migración de temas RASI originales y los demás menús especializados de Rofi quedará para otro paso. Los menús de volumen y brillo requieren además instalar sus módulos respectivos; un script puede estar instalado aunque su backend no esté todavía configurado.

## Menús Rofi en dwm (Alpine y Debian)

```sh
sh install.sh --modules rofi --dry-run
sh install.sh --modules rofi
lt-rofi             # menú principal
lt-rofi apps        # aplicaciones (drun)
lt-rofi run         # ejecutar comando (run)
lt-rofi windows     # cambiar de ventana (window)
lt-rofi wifi        # ver redes disponibles (solo consulta)
lt-rofi bluetooth   # ver dispositivos BlueZ (solo consulta)
rofi_internet       # 12 marcadores web + normal/privado
rofi_volume         # menú interactivo de audio
rofi_brightness     # menú interactivo de brillo
```

Los menús están implementados en **linux-tools** como scripts POSIX seguros, tomando la funcionalidad del Bash anterior como referencia, sin ejecutarlo. Se instala el ejecutable en `~/.local/bin/lt-rofi` y la función `lt_rofi` en Fish. Desde dwm se puede asociar una tecla a `lt-rofi` usando la ruta que resuelve el PATH de dwm o `/home/USUARIO/.local/bin/lt-rofi`; no se modifica automáticamente el `config.h` del fork.

En Alpine 3.24, `rofi-x11-wayland` se instala desde `community` temporal de la versión estable; en Debian `rofi` desde apt. No se cambia el gestor Wi-Fi ni se toca la configuración de Bluetooth. Rofi necesita una sesión X11/dwm (o display compatible).

**dshortcuts permanece en su propio repositorio C**. No se instala su configuración original de `items.h` automáticamente: actualmente contiene rutas hacia `~/.bash_scripts/...` y comandos de otro entorno. Esa migración se realizará después de adaptar sus atajos a los comandos actuales de linux-tools.

## Integración con dshortcuts en C

`lt-shortcut` es un dispatcher POSIX sin `eval` ni interpretación libre de claves: `volume` y `brightness` llaman los módulos respectivos, `rotate` reutiliza las funciones Fish, y los accesos a Wi-Fi/Bluetooth son consultas mediante Rofi. El menú de C, su compilación y el atajo `Super+P` son responsabilidad de `linux-setup`, no se copian ni modifican archivos del fork desde linux-tools.

```sh
sh install.sh --modules shortcuts --dry-run
sh install.sh --modules shortcuts
lt-shortcut volume k
lt-shortcut brightness j
lt-shortcut rotate r
lt-shortcut wifi l
```

**Advertencia:** los atajos que cambian volumen, brillo o rotación actúan inmediatamente; los comandos `wifi` y `bluetooth` solo consultan listas. No hay atajos de apagado/reinicio ni restauración de scripts legados con permisos o rutas incorrectas.
