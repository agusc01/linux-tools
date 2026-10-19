# linux-tools-managed: agusc01/linux-tools
# Fish es la shell principal: no se importa sintaxis ni alias de Bash.
set -g fish_greeting ''

# Accesible incluso cuando dwm ejecuta fish -c.
if test -d "$HOME/.local/bin"
    fish_add_path -g "$HOME/.local/bin"
end

# Alpine deja /sbin y /usr/sbin fuera del PATH de usuarios comunes.
# Agregar al final del PATH solo de la sesión Fish; sin duplicados ni
# variables universales persistentes. No concede permisos de root.
for directory in /sbin /usr/sbin /usr/local/sbin
    if test -d "$directory"
        fish_add_path --append --path "$directory"
    end
end

if command -sq nvim
    set -gx EDITOR nvim
else if command -sq vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end
set -gx LESS '-R -I'
