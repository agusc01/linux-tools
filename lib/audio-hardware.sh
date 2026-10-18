#!/bin/sh
# linux-tools-managed: agusc01/linux-tools
# Reglas de detección: solo aplican a Intel Cherry Trail + NAU8824 real.
# Sobrescribir raíces únicamente en pruebas aisladas.
lt_audio_sysroot() { printf '%s\n' "${LT_AUDIO_SYSROOT:-/sys}"; }
lt_audio_firmroot() { printf '%s\n' "${LT_AUDIO_FIRMROOT:-/lib/firmware}"; }
lt_cherrytrail_nau8824() {
    sysroot=$(lt_audio_sysroot)
    [ -d "$sysroot/bus/acpi/devices/808622A8:00" ] &&
        [ -d "$sysroot/bus/i2c/devices/i2c-10508824:00" ]
}
lt_audio_acpi_status() {
    sysroot=$(lt_audio_sysroot)
    if [ -r "$sysroot/bus/acpi/devices/808622A8:00/status" ]; then
        cat "$sysroot/bus/acpi/devices/808622A8:00/status"
    else
        printf '%s\n' unknown
    fi
}
lt_audio_file_present() {
    [ -f "$1" ] && return 0
    # Alpine puede distribuir el firmware comprimido como .zst.
    for file in "$1".*; do [ -f "$file" ] && return 0; done
    return 1
}
lt_audio_sof_ready() {
    firmroot=$(lt_audio_firmroot)
    lt_audio_file_present "$firmroot/intel/sof/sof-cht.ri" &&
        lt_audio_file_present "$firmroot/intel/sof-tplg/sof-cht-nau8824.tplg"
}
lt_audio_internal_card() {
    cards=${LT_AUDIO_CARDS_FILE:-/proc/asound/cards}
    [ -r "$cards" ] && grep -Eiq 'nau8824|sof-bytcht' "$cards"
}
lt_audio_cherrytrail_report() {
    if ! lt_cherrytrail_nau8824; then
        echo 'Hardware Cherry Trail + NAU8824: no detectado (no se instalará firmware específico).'
        return 0
    fi
    echo 'Hardware detectado: Intel Cherry Trail 808622A8 + códec NAU8824 (10508824).'
    case "$(lt_audio_acpi_status)" in
        15) echo 'BIOS/UEFI: LPE Audio ACPI mode habilitado (estado 15).' ;;
        0) echo 'ATENCIÓN: audio ACPI deshabilitado (estado 0). Revisá BIOS > Chipset > Audio Configuration > LPE Audio ACPI mode; no se cambia automáticamente.' ;;
        *) echo 'ATENCIÓN: estado ACPI distinto de 15. Comprobá el modo LPE Audio en la BIOS.' ;;
    esac
    if lt_audio_sof_ready; then
        echo 'Firmware SOF Cherry Trail y topología NAU8824: presentes.'
    else
        echo 'Faltan archivos SOF: intel/sof/sof-cht.ri y/o intel/sof-tplg/sof-cht-nau8824.tplg.'
    fi
    if lt_audio_internal_card; then
        echo 'ALSA: tarjeta NAU8824 detectada.'
    else
        echo 'ALSA: tarjeta NAU8824 aún no detectada. Puede ser necesario reiniciar después de instalar SOF.'
    fi
}
