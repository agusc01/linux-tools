# linux-tools-managed: agusc01/linux-tools
function rotar --description 'Rotar pantalla y táctil Goodix en Xorg'
    if test (count $argv) -ne 1
        echo 'Uso: rotar normal|derecha|invertida|izquierda' >&2
        return 2
    end

    set -l orientacion
    set -l matriz

    switch $argv[1]
        case normal 0
            set orientacion normal
            set matriz 1 0 0 0 1 0 0 0 1
        case derecha 90
            set orientacion right
            set matriz 0 1 0 -1 0 1 0 0 1
        case invertida 180
            set orientacion inverted
            set matriz -1 0 1 0 -1 1 0 0 1
        case izquierda 270
            set orientacion left
            set matriz 0 -1 1 1 0 0 0 0 1
        case '*'
            echo 'Uso: rotar normal|derecha|invertida|izquierda' >&2
            return 2
    end

    if not command -sq xrandr
        echo 'Error: falta xrandr.' >&2
        return 1
    end

    # La pantalla interna tiene prioridad; admite un nombre configurado a mano.
    set -l salida
    if set -q ROTATE_OUTPUT; and test -n "$ROTATE_OUTPUT"
        set salida "$ROTATE_OUTPUT"
    else
        set salida (command xrandr --query | awk '$2 == "connected" && $1 ~ /^(eDP|LVDS|DSI)/ {print $1; exit}')
        if test -z "$salida"
            set salida (command xrandr --query | awk '$2 == "connected" && / primary / {print $1; exit}')
        end
        if test -z "$salida"
            set salida (command xrandr --query | awk '$2 == "connected" {print $1; exit}')
        end
    end

    if test -z "$salida"
        echo 'Error: no se encontró una pantalla conectada. Consultá xrandr --query.' >&2
        return 1
    end

    command xrandr --output "$salida" --rotate "$orientacion"
    or return 1

    if not command -sq xinput
        echo 'Aviso: pantalla rotada, pero falta xinput para sincronizar el táctil.' >&2
        return 0
    end

    set -l tactil 'Goodix Capacitive TouchScreen'
    if set -q ROTATE_TOUCH; and test -n "$ROTATE_TOUCH"
        set tactil "$ROTATE_TOUCH"
    end

    # "pointer:" evita la entrada de teclado que también aparece como Goodix.
    # Nunca se guarda un ID fijo: puede cambiar tras reiniciar Xorg.
    set -l ids (command xinput list --id-only "pointer:$tactil" 2>/dev/null)
    if test (count $ids) -eq 0
        echo "Aviso: pantalla rotada, pero no se encontró el táctil: $tactil" >&2
        return 0
    end

    if test (count $ids) -ne 1
        echo "Error: se encontraron varios táctiles llamados '$tactil'. No se modificó su matriz." >&2
        return 1
    end

    command xinput set-prop --type=float "$ids[1]" 'Coordinate Transformation Matrix' $matriz
    or return 1

    echo "Rotación aplicada: $argv[1] (pantalla $salida y táctil $tactil)."
end
