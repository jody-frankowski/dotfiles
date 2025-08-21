#!/bin/bash

set -euxo pipefail

script_dir="$(realpath "$(dirname "$0")")"
pushd "${script_dir}" > /dev/null

symlink () {
    package="$1"

    find "${package}" -type f | while IFS= read -r file ; do
        dir=~/"$(dirname "${file}" | cut -s -d/ -f2-)"
        filename="$(basename "${file}")"
        link="${dir}/${filename}"

        mkdir -p "${dir}"

        if [[ -e "${link}" && ! -L "${link}" ]] ; then
            echo "${link}" exists and is not a symlink. Moving to "${link}".old! >&2
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

for dir in ~/.usr/bin/ ~/.usr/logs/ ~/.usr/opt/ ~/.usr/share/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

# macOS Specific
if ./base/.usr/bin/_onmacos ; then
    # Make sure brew is in our PATH in case it's an early installation
    export PATH="/opt/homebrew/bin:${PATH}"

    # Disable Homebrew's analytics
    brew analytics off

    taps=(
        homebrew/cask-fonts
    )
    for tap in "${taps[@]}" ; do
        [[ -d /opt/homebrew/Library/Taps/"${tap}" ]] || brew tap "${tap}"
    done

    formulae=(
        atool
        bfs
        borgbackup
        coreutils
        # Mainly for the zsh completion
        curl
        dfc
        editorconfig
        emacs
        fzf
        gnupg
        jq
        lsd
        moar
        mosh
        myrepos
        p7zip
        pass
        pass-otp
        pinentry-mac
        python3
        ripgrep
        syncthing
        tmux
        wget
        zsh-completions
    )
    for formula in "${formulae[@]}" ; do
        [[ -d /opt/homebrew/opt/"${formula}" ]] || brew install "${formula}"
    done

    casks=(
        firefox
        font-sauce-code-pro-nerd-font
        google-chrome
        iina
        iterm2
        karabiner-elements
        lulu
        stats
        visual-studio-code
        vlc
    )
    for cask in "${casks[@]}" ; do
        [[ -d /opt/homebrew/Caskroom/"${cask}" ]] || brew install --cask "${cask}"
    done

    # Make sure this folder exists before linking completion files
    [ -d ~/.zshrc.d/completion/ ] || mkdir -p ~/.zshrc.d/completion

    ### coreutils
    # Replace some macOS's coreutils binaries with GNU ones. We do this because some of our zsh
    # aliases depend on specific GNU's coreutils flags.
    for symlink in date dircolors du head rm sort; do
        [[ -L ~/.usr/bin/"${symlink}" ]] || ln -s /opt/homebrew/opt/coreutils/bin/g"${symlink}" ~/.usr/bin/"${symlink}"
    done

    ### curl
    # Use homebrew's curl so that we can use its zsh completion and have a binary with a matching
    # version
    [[ -L ~/.usr/bin/curl ]] || ln -s /opt/homebrew/opt/curl/bin/curl ~/.usr/bin/
    [[ -L ~/.zshrc.d/completion/_curl ]] || ln -s /opt/homebrew/opt/curl/share/zsh/site-functions/_curl ~/.zshrc.d/completion/

    ### Clock
    # Don't show day of week
    defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
    # Never show date
    defaults write com.apple.menuextra.clock ShowDate 2

    ### Finder
    # Show all the extensions
    defaults write com.apple.finder AppleShowAllExtensions -bool true
    # Show the folders first
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    # Show the path bar
    defaults write com.apple.finder ShowPathbar -bool true
    # Automatically empty the Bin after 30 days
    defaults write com.apple.finder FXRemoveOldTrashItems -bool true
    killall Finder || true

    ### iina
    # Move the OSC at the bottom. It also makes it much larger.
    defaults write com.colliderli.iina oscPosition 2
    # Remove the settings button from the OSC
    defaults write com.colliderli.iina controlBarToolbarButtons '(2,1)'
    # Show the chapters markers in the OSC
    defaults write com.colliderli.iina showChapterPos -bool true
    # Quit the application when all windows have closed
    defaults write com.colliderli.iina quitWhenNoOpenedWindow -bool true
    # Move SubRip subtitles in the video matte
    defaults write com.colliderli.iina displayInLetterBox -bool true

    ### pinentry-mac
    # Disable the default behavior of saving the passphrase in the keychain
    defaults write org.gpgtools.common UseKeychain NO

    ### python
    # Add a python symlink so we can call python3 with `python` like on Arch Linux
    [[ -L ~/.usr/bin/python ]] || ln -s /opt/homebrew/bin/python3 ~/.usr/bin/python

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

    ### zsh-completions
    # Link only the completion files we need
    for completion in cmake gpgconf node ; do
        [[ -L ~/.zshrc.d/completion/_"${completion}" ]] || ln -s /opt/homebrew/share/zsh-completions/_"${completion}" ~/.zshrc.d/completion/
    done

    ### Syncthing
    # Start and enable
    brew services list | grep 'syncthing.*started' > /dev/null || brew services start syncthing

    ### Screensaver
    # Require a password immediately after enabling the screensaver
    defaults write com.apple.screensaver askForPassword -bool true
    defaults write com.apple.screensaver askForPasswordDelay -int 0

    ### Alert Sound
    defaults write "Apple Global Domain" com.apple.sound.beep.sound -string /System/Library/Sounds/Purr.aiff

    ### iterm2
    # Specify the preferences directory
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "${script_dir}/iterm2"
    # Tell iTerm2 to use the custom preferences from this directory
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

    ### Dock
    # Show only active apps
    defaults write com.apple.dock static-only -bool true
    # Auto hide
    defaults write com.apple.dock autohide -bool true
    # Disable bottom right Hot Corner
    defaults write com.apple.dock wvous-br-corner -int 1
    defaults write com.apple.dock wvous-br-modifier -int 0
    # Reload
    killall Dock

    ### Menu Bar
    # Auto Hide (Will need a logout to take effect in all apps. Or we could restart every app.)
    defaults write NSGlobalDomain _HIHideMenuBar -bool true

    ### Karabiner
    # We can't symlink it because Karabiner overwrites the symlink
    osascript -e 'quit app "Karabiner-Elements"'
    # Needed for a first run
    mkdir -p ~/.config/karabiner/
    cp -f karabiner/.config/karabiner/karabiner.json ~/.config/karabiner/
    osascript -e 'tell application "Karabiner-Elements" to activate'

    ### Compose key keybindings
    # Needed for a first run
    mkdir -p ~/Library/KeyBindings
    # Symlinking doesn't work
    # /!\ This depends on the Karabiner right_command -> non_us_backslash modification
    cp -f base-macos/Library/KeyBindings/DefaultKeyBinding.dict ~/Library/KeyBindings
    # Disable the character palette when holding a key (applications need to be restarted)
    defaults write -g ApplePressAndHoldEnabled -bool false

    ### Student service (if the mac was bought by a school or with a student account)
    # Disable and stop
    launchctl disable gui/$(id -u)/com.apple.studentd
    launchctl stop com.apple.studentd

    ### Stats
    # Configure basic settings
    defaults write eu.exelban.Stats runAtLoginInitialized 1
    defaults write eu.exelban.Stats setupProcess 1
    defaults write eu.exelban.Stats telemetry 0
    defaults write eu.exelban.Stats update-interval "At start"
    # Needed otherwise the defaults will be reset
    defaults write eu.exelban.Stats version 2.9.4
    # Enable combined modules display
    defaults write eu.exelban.Stats CombinedModules 1
    # Enable some widgets
    stats_widgets=(Battery CPU RAM GPU Network Sensors Disk)
    for widget in "${stats_widgets[@]}" ; do
        defaults write eu.exelban.Stats "${widget}"_state 1
    done
    # Configure some widgets
    stats_widgets=(CPU RAM GPU Disk)
    for widget in "${stats_widgets[@]}" ; do
        defaults write eu.exelban.Stats "${widget}"_widget mini
        defaults write eu.exelban.Stats "${widget}"_mini_color utilization
    done
    # Battery
    defaults write eu.exelban.Stats Battery_battery_additional innerPercentage
    defaults write eu.exelban.Stats Battery_battery_color 1
    defaults write eu.exelban.Stats Battery_battery_lowPowerMode 1
    defaults write eu.exelban.Stats Battery_widget battery
    # Disk
    defaults write eu.exelban.Stats Disk_widget mini
    defaults write eu.exelban.Stats SSD_mini_color utilization
    # Network
    defaults write eu.exelban.Stats Network_speed_value 1
    defaults write eu.exelban.Stats Network_speed_valueColor 1
    # Sensors
    defaults write eu.exelban.Stats Sensors_widget sensors
    defaults write eu.exelban.Stats "sensor_Average CPU" 1
    defaults write eu.exelban.Stats sensor_PSTR 1
    # Set widgets positions
    stats_widgets=(Network Disk GPU CPU RAM Sensors Battery Bluetooth Clock)
    position=0
    for widget in "${stats_widgets[@]}" ; do
        echo $widget
        defaults write eu.exelban.Stats "${widget}"_position "${position}"
        position=$(( position + 1 ))
    done
    osascript -e 'tell application "Stats" to quit'
    osascript -e 'tell application "System Events"' -e 'repeat while (application process "Stats" exists)' -e 'delay 0.2' -e 'end repeat' -e 'end tell'
    open /Applications/Stats.app

    ### Siri
    # Disable background listening for "Hey Siri"
    defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false

    # Symlink macOS specific dotfiles
    for dir in *-macos ; do
        symlink "${dir}"
    done
fi

# terminfo
for terminfo in ~/.terminfo/*.terminfo ; do
    tic -x "${terminfo}"
done

# Symlink the dotfiles
for dir in alacritty base docker emacs js mpv ssh tmux zed zsh ; do
    symlink "${dir}"
done

# Linux specific
if ./base/.usr/bin/_onlinux ; then
    # Make a symlink from open to xdg-open, so that `open` or the `o` alias work the same on Linux
    # or macOS
    [[ -L ~/.usr/bin/open ]] || ln -s /usr/bin/xdg-open ~/.usr/bin/open

    # Symlink Linux specific dotfiles
    for dir in *-linux ; do
        symlink "${dir}"
    done
    # Reload systemd because of the potentially newly installed or modified systemd units
    systemctl --user daemon-reload
fi

# emacs
# Directory used for custom .el files
[[ -d ~/.emacs.d/lisp ]] || mkdir -p ~/.emacs.d/lisp

# nvim
# base16-theme
git clone --depth 1 https://github.com/RRethy/base16-nvim ~/.local/share/nvim/site/pack/misc/start/base16-nvim

# ssh
# This directory will be used for the ControlPath files
[[ -d ~/.cache/ssh ]] || mkdir -p ~/.cache/ssh

# tpm (tmux-plugin-manager)
# This needs to be done after tmux's symlinking because tpm searches for its
# config in tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Install plugins
~/.tmux/plugins/tpm/scripts/install_plugins.sh

popd > /dev/null
