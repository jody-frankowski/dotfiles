# More restrictive umask
umask 077

# Emacs as default editor
# https://unix.stackexchange.com/questions/4859/visual-vs-editor-whats-the-difference
export EDITOR='emacsclient -a "" --tty'
export VISUAL='emacsclient -a "" --tty'

# FZF
export FZF_DEFAULT_OPTS='--bind=esc:,ctrl-a:toggle-all,ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down --cycle --layout=reverse --scroll-off=20'

# Pager
export PAGER=moar
# Set the default moar options
export MOAR='--no-linenumbers --no-statusbar'
# Set the default less options
# -i smart case search
# -M show line numbers in prompt
# -R interpret ANSI color escape sequences
# -j4 search results will be 4 lines lower than the top of the screen
export LESS='-i -M -R -j4'

# Go
export GOPATH=~/.cache/go

# Npm
export NPM_PACKAGES=~/.cache/npm

# Python
export PYTHONPATH="${HOME}/.usr/lib/:${PYTHONPATH}"

# Rust
export CARGO_HOME=~/.cache/cargo

### PATH
# Homebrew
if ~/.usr/bin/_onmacos ; then
    export PATH="/opt/homebrew/bin:${PATH}"
fi
# Node
export PATH="${HOME}/.cache/npm/bin:${PATH}"
# Python
export PATH="${HOME}/.local/bin:${PATH}"
# Go
export PATH="${HOME}/.cache/go/bin:${PATH}"
# Rust
export PATH="${HOME}/.cache/cargo/bin:${PATH}"
# Custom scripts and symlinks
export PATH="${HOME}/.usr/bin:${PATH}"
### PATH

# Disable Homebrew's auto update
if ~/.usr/bin/_onmacos ; then
    export HOMEBREW_NO_AUTO_UPDATE=1
fi

# Set the locale
export LC_ALL=en_US.UTF-8
