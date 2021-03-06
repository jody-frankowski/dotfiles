#!/bin/bash

set -euxo pipefail

script_dir=$(dirname $0)
pushd "${script_dir}" > /dev/null

symlink () {
    package="$1"

    for file in $(find "${package}" -type f)
    do
        dir=~/"$(dirname ${file} | cut -s -d/ -f2-)"
        filename="$(basename ${file})"
        link="${dir}/${filename}"

        mkdir -p "${dir}"

        if [ -e "${link}" -a ! -L "${link}" ]
        then
            echo "${link} exists and is not a symlink. Aborting!"
            exit 1
        else
            ln -f -s "$(pwd)/${file}" "${link}"
        fi
    done
}

for terminfo in ./base/.terminfo/*.terminfo ; do
    tic -x -o ~/.terminfo $terminfo
done

# fzf
if [[ "$OSTYPE" == "darwin"* ]]; then
    fzf_path=~/.brew/opt/fzf/shell/
else
    fzf_path=/usr/share/fzf/
fi
[[ -d ~/.usr/share/fzf ]] || mkdir -p ~/.usr/share/fzf
for file in completion.zsh key-bindings.zsh ; do
    [[ -L ~/.usr/share/fzf/${file} ]] || ln -s ${fzf_path}/${file} ~/.usr/share/fzf/${file}
done

symlink zsh

# Stop there for root
if [[ `id -u` -eq 0 ]] ; then
    exit 0
fi

for dir in ~/.usr/bin/ ~/.usr/opt/ ~/.usr/share/ ~/.usr/var/log/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

# macOS Specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="~/.brew/bin/:$PATH"

    [[ -d ~/.brew ]] || git clone --depth=1 https://github.com/Homebrew/brew ~/.brew

    packages=(
        atool
        coreutils
        editorconfig
        emacs
        gnupg
        fzf
        mosh
        myrepos
        python3
        ripgrep
        syncthing
        tmux
    )

    for package in ${packages[@]} ; do
        [[ -d ~/.brew/opt/$package ]] || brew install $package
    done

    ### coreutils
    # Replace some macOS's coreutils binaries with a GNU one
    for symlink in date dircolors ls rm sort ; do
        [[ -L ~/.usr/bin/$symlink ]] || ln -s g$symlink ~/.usr/bin/$symlink
    done

    # symlink only llvm's scan-build because we don't want this llvm to replace
    # macOS's one
    [[ -L ~/.brew/bin/scan-build ]] || ln -s ~/.brew/opt/llvm/bin/scan-build ~/.brew/bin/

    ### terminfo
    # We need the terminfo capabilites of tmux-256color, however macOS doesn't
    # provide one.  The one that is in the homebrew's ncurses is incompatible
    # with macOS ncurses tools (tic/terminfo). So we export the terminfo
    # capabilities with homebrew's ncurses tools and compile them with macOS'
    # tic.
    [[ -d ~/.terminfo ]] || mkdir ~/.terminfo
    latest_ncurses=$(ls -t ~/.brew/Cellar/ncurses/ | head -n1)
    PATH="~/.brew/opt/ncurses/bin:$PATH" TERMINFO_DIRS=~/.brew/Cellar/ncurses/$latest_ncurses/share/terminfo/ infocmp -x tmux-256color > ~/.terminfo/tmux-256color
    tic -x ~/.terminfo/tmux-256color

    brew services list | grep 'syncthing.*started' > /dev/null || brew services start syncthing

    ### screensaver
    # Require a password immediately after enabling the screensaver
    defaults write com.apple.screensaver askForPassword -bool true
    defaults write com.apple.screensaver askForPasswordDelay -int 0

    ### iterm2
    # Specify the preferences directory
    defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "~/.dotfiles/iterm2"
    # Tell iTerm2 to use the custom preferences from this directory
    defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true

    ### Dock
    # Show only active apps
    defaults write com.apple.dock static-only -bool true
    # Auto hide
    defaults write com.apple.dock autohide -bool true
    # Reload
    killall Dock

    ### Karabiner
    symlink karabiner
fi

# ssh
[[ -d ~/.ssh ]] || mkdir ~/.ssh && chmod 700 ~/.ssh
[[ -d ~/.cache/ssh ]] || mkdir ~/.cache/ssh && chmod 700 ~/.cache/ssh

# Symlink the dotfiles
for dir in alacritty base docker emacs gnupg js mpv ssh tmux ; do
    symlink ${dir}
done

# Symlink *-hostname or *-domain
ls -d *-"$(hostname)" &>/dev/null && symlink *-"$(hostname)"
ls -d *-"$(hostname | cut -d. -f2-)" &>/dev/null && symlink *-"$(hostname | cut -d. -f2-)"

# Linux Specific
if [[ "$OSTYPE" == "linux-gnu" ]] ; then
    # Reload systemd because of systemd units
    systemctl --user daemon-reload
fi

# ssh config
~/.ssh/update

# tpm (tmux-plugin-manager)
# This needs to be done after tmux's symlinking because tpm searches for its
# config in tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# install plugins. buggy, better use prefix + I
~/.tmux/plugins/tpm/scripts/install_plugins.sh > /dev/null

popd > /dev/null
