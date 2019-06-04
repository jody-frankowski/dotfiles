#!/bin/bash

set -euo pipefail

script_dir=$(dirname $0)
pushd ${script_dir} > /dev/null

source ./lib.sh

for dir in ~/code/ ~/code/tmp/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

# macOS Specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="~/.brew/bin/:$PATH"

    packages=(
        editorconfig
        emacs
        gdb
        go
        mosh
        myrepos
        rust
        syncthing
        valgrind
    )

    for package in ${packages[@]} ; do
        [[ -d ~/.brew/opt/$package ]] || silent brew install $package
    done

    brew services list | grep syncthing > /dev/null || brew services start syncthing

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
fi

# mpd
if [[ ! -d ~/.mpd ]] ; then
    mkdir -p ~/.mpd/playlists
    touch ~/.mpd/{mpd.db,mpd.log,mpd.pid,mpdstate}
fi

# ssh
[[ -d ~/.ssh ]] || mkdir ~/.ssh && chmod 700 ~/.ssh
[[ -d ~/.ssh/tmp ]] || mkdir ~/.ssh/tmp && chmod 700 ~/.ssh/tmp

# stow the dotfiles
for dir in base docker emacs gnupg js karabiner mpd mpv ssh tmux valgrind X ; do
    stow --no-folding ${dir}
done
# hack for the freaking symlink removal
chmod 500 ~/.config/gtk-2.0/

# Stow *-hostname or *-domain
ls -d *-"$(hostname)" &>/dev/null && stow --no-folding *-"$(hostname)"
ls -d *-"$(hostname | cut -d. -f2-)" &>/dev/null && stow --no-folding *-"$(hostname | cut -d. -f2-)"

# Linux Specific
if [[ "$OSTYPE" == "linux-gnu" ]] ; then
    # Reload systemd because of systemd units
    systemctl --user daemon-reload

    # change file-chooser startup location in gtk 3 https://wiki.archlinux.org/index.php/GTK%2B#File-Chooser_Startup-Location
    gsettings set org.gtk.Settings.FileChooser startup-mode cwd
fi

# ssh config
cd ~/.ssh > /dev/null
./update

cd ~/
# Clone repositories
silent mr -j 5 up

popd > /dev/null
