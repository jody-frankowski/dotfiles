#!/bin/bash

set -euxo pipefail

script_dir=$(dirname $0)
pushd "${script_dir}" > /dev/null

symlink () {
    package="$1"

    for file in $(find "${package}" -type f) ; do
        dir=~/"$(dirname ${file} | cut -s -d/ -f2-)"
        filename="$(basename ${file})"
        link="${dir}/${filename}"

        mkdir -p "${dir}"

        if [[ -e "${link}" && ! -L "${link}" ]] ; then
            echo "/!\ ${link} exists and is not a symlink. Moving to ${link}.old!"
            mv "${link}"{,.old}
        fi
        ln -f -s "$(pwd)/${file}" "${link}"
    done
}

# Set the umask manually in this script as the calling shell may not yet have it configured
umask 077

# terminfo
# Symlink terminfo's capabilities files early so that macOS' specific configuration works
symlink terminfo

# fzf
if [[ "$OSTYPE" == "darwin"* ]]; then
    fzf_path=/opt/homebrew/opt/fzf/shell/
else
    fzf_path=/usr/share/fzf/
fi
[[ -d ~/.usr/share/fzf ]] || mkdir -p ~/.usr/share/fzf
for file in completion.zsh key-bindings.zsh ; do
    [[ -L ~/.usr/share/fzf/${file} ]] || ln -s ${fzf_path}/${file} ~/.usr/share/fzf/${file}
done

for dir in ~/.usr/bin/ ~/.usr/opt/ ~/.usr/share/ ~/.usr/var/log/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

# macOS Specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="/opt/homebrew/bin:$PATH"

    [[ -d /opt/homebrew ]] || git clone --depth=1 https://github.com/Homebrew/brew /opt/homebrew

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
    casks=(
        firefox
        karabiner-elements
    )

    for package in ${packages[@]} ; do
        [[ -d /opt/homebrew/opt/$package ]] || brew install $package
    done
    for cask in ${casks[@]} ; do
        [[ -d /opt/homebrew/Caskroom/$cask ]] || brew install $cask
    done

    ### coreutils
    # Replace some macOS's coreutils binaries with GNU ones. We do this because some of our zsh
    # aliases depend on specific GNU's coreutils flags.
    for symlink in date dircolors ls rm sort ; do
        [[ -L ~/.usr/bin/$symlink ]] || ln -s /opt/homebrew/opt/coreutils/bin/g$symlink ~/.usr/bin/$symlink
    done

    ### terminfo
    # We need the terminfo capabilites of tmux-256color, however macOS doesn't
    # provide one. The one in homebrew's ncurses package is incompatible
    # with macOS' ncurses tools (tic/terminfo). So we export the terminfo
    # capabilities with homebrew's ncurses' infocmp and compile them with macOS'
    # tic.
    /opt/homebrew/opt/ncurses/bin/infocmp -x tmux-256color > ~/.terminfo/tmux-256color.ncurses.terminfo
    # This command will generate a binary terminfo database in ~/.terminfo and the next one
    # will generate a terminfo database with the same name, however since our custom version
    # includes the same terminfo database (use=tmux-256color), our capabilities will be added to
    # the former one.
    tic -x ~/.terminfo/tmux-256color.ncurses.terminfo
    tic -x ~/.terminfo/tmux-256color.terminfo

    brew services list | grep 'syncthing.*started' > /dev/null || brew services start syncthing

    ### Screensaver
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

# terminfo
for terminfo in ~/.terminfo/*.terminfo ; do
    tic -x ${terminfo}
done

# Symlink the dotfiles
for dir in alacritty base docker emacs gnupg js mpv ssh tmux zsh ; do
    symlink ${dir}
done

# Symlink *-hostname or *-domain
ls -d *-"$(hostname)" &>/dev/null && symlink *-"$(hostname)"
ls -d *-"$(hostname | cut -d. -f2-)" &>/dev/null && symlink *-"$(hostname | cut -d. -f2-)"

# Linux Specific
if [[ "$OSTYPE" == "linux-gnu" ]] ; then
    # Reload systemd because of the potentially newly installed or modified systemd units
    systemctl --user daemon-reload
fi

# ssh
# This directory will be used for the ControlPath files
[[ -d ~/.cache/ssh ]] || mkdir -p ~/.cache/ssh
# Generate ssh's config file. This script's purpose is to concatenate all the ~/.ssh/config-* files
# so that private ssh configs can be stored in a private location
~/.ssh/update

# tpm (tmux-plugin-manager)
# This needs to be done after tmux's symlinking because tpm searches for its
# config in tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# install plugins. buggy, better use prefix + I
~/.tmux/plugins/tpm/scripts/install_plugins.sh > /dev/null

popd > /dev/null
