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
export NPM_PACKAGES=~/.npm-packages

# .local/bin is for pip install --user
export PATH="$HOME/.npm-packages/bin:$HOME/.local/bin:$HOME/.usr/bin:$HOME/.go/bin/:$HOME/.cargo/bin/:$PATH"
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="$HOME/.brew/bin:$PATH"
fi

export PYTHONPATH="$HOME/.usr/lib/:$PYTHONPATH"
