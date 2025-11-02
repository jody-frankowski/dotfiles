# More restrictive umask
umask 077

# Emacs as default editor
# https://unix.stackexchange.com/questions/4859/visual-vs-editor-whats-the-difference
export EDITOR='emacsclient -a "" --tty'
export VISUAL='emacsclient -a "" --tty'

# FZF
export FZF_DEFAULT_OPTS='--bind=esc:,ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down --cycle --layout=reverse --scroll-off=20'

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

# Fix broken man page colors on Linux after roff update
# https://web.archive.org/web/20250309205344/https://bbs.archlinux.org/viewtopic.php?pid=2113876#p2113876
export MANROFFOPT=-c

# Go
export GOPATH=~/.cache/go

# Nix
if ~/.usr/bin/_onmacos; then
  [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] \
    && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Npm
export NPM_PACKAGES=~/.cache/npm

# Python
export PYTHONPATH=~/.usr/lib/:${PYTHONPATH}

# Rust
export CARGO_HOME=~/.cache/cargo

### PATH
# The PATH variable is read left-to-right, so we put the directories that are most likely to
# override others at the beginning of the variable
# Homebrew
if ~/.usr/bin/_onmacos; then
    export BREW_PREFIX=/opt/homebrew
    PATH=${BREW_PREFIX}/sbin:${PATH}
    PATH=${BREW_PREFIX}/bin:${PATH}
fi
# Bun
PATH=~/.bun/bin:${PATH}
# Node
PATH=~/.cache/npm/bin:${PATH}
# Python
PATH=~/.local/bin:${PATH}
# Go
PATH=~/.cache/go/bin:${PATH}
# Rust
PATH=~/.cache/cargo/bin:${PATH}
# Nix
PATH=~/.nix-profile/bin:${PATH}
# Custom scripts and symlinks
PATH=~/.usr/bin:${PATH}
export PATH
### PATH

if ~/.usr/bin/_onmacos; then
    export HOMEBREW_NO_AUTO_UPDATE=1     # Disable automatic updates
    export HOMEBREW_NO_INSTALL_CLEANUP=1 # Disable automatic formulae cleanup
fi

# Set the locale
export LC_ALL=en_US.UTF-8
