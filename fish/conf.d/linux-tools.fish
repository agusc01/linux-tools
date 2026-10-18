# linux-tools-managed: agusc01/linux-tools
# Fish es la shell principal: no se importa sintaxis ni alias de Bash.
set -g fish_greeting ''

# Accesible incluso cuando dwm ejecuta fish -c.
if test -d "$HOME/.local/bin"
    fish_add_path -g "$HOME/.local/bin"
end

if command -sq nvim
    set -gx EDITOR nvim
else if command -sq vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end
set -gx LESS '-R -I'
