# Not ~/.zshenv because of https://wiki.archlinux.org/index.php/Zsh#Startup.2FShutdown_files
# https://lists.archlinux.org/pipermail/arch-general/2013-March/033109.html :

# /etc/profile is not a part of the regular list of startup files run for Zsh,
# but is sourced from /etc/zsh/zprofile in the zsh package. Users should take
# note that /etc/profile sets the $PATH variable which will overwrite any $PATH
# variable set in $ZDOTDIR/.zshenv. To prevent this, please set the $PATH
# variable in $ZDOTDIR/.zprofile.

# Emacs as default editor
# https://unix.stackexchange.com/questions/4859/visual-vs-editor-whats-the-difference
export EDITOR='emacsclient -a "" --tty'
export VISUAL='emacsclient -a "" --tty'

# Pager
export PAGER='less'
# Sets the default Less options.
# -i smart case search
# -M show line numbers in prompt
# -R interpret ANSI color escape sequences
# -j4 search results will be 4 lines lower than the top of the screen
export LESS='-i -M -R -j4'

# Go
export GOPATH=~/.go

# Npm
export NPM_PACKAGES=~/.cache/npm

# Python
export PYTHONPATH="$HOME/.usr/lib/:$PYTHONPATH"

## PATH
# Homebrew
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="$HOME/.brew/bin:$PATH"
fi
# Node
export PATH="$HOME/.cache/npm/bin:$PATH"
# Python
export PATH="$HOME/.local/bin:$PATH"
# Go
export PATH="$HOME/.go/bin:$PATH"
# Rust
export PATH="$HOME/.cargo/bin:$PATH"
# Custom scripts and symlinks
export PATH="$HOME/.usr/bin:$PATH"
## PATH

# Disable Homebrew's auto update
if [[ "$OSTYPE" == "darwin"* ]]; then
    export HOMEBREW_NO_AUTO_UPDATE=1
fi
