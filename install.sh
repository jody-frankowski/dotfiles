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
    export BREW_PREFIX=/opt/homebrew
    export PATH="${BREW_PREFIX}/bin:${PATH}"

    # Disable Homebrew's analytics
    brew analytics off

    formulae=(
        atool
        atuin
        bfs
        borgbackup
        coreutils gnu-sed
        # Mainly for the zsh completion
        curl
        devbox
        dfc
        diffutils # Because macOS' diff doesn't support `--color`
        editorconfig
        emacs
        fd
        fx
        fzf
        gnupg
        jq
        lsd
        moar
        mise
        mosh
        mpv
        myrepos
        ncdu
        neovim
        p7zip
        pass
        pass-otp
        pinentry-mac
        pstree
        python3
        ripgrep
        # Install rsync 3.+ (macOS' only has 2.+) which supports --append and --append-verify.
        # More infos in the cpva script.
        rsync
        starship
        syncthing
        tldr
        tmux
        ugrep
        usage # Required for mise's completion
        uv # Modern Python package manager
        wget
        yq
        zsh-completions
    )
    for formula in "${formulae[@]}" ; do
        [[ -d "${BREW_PREFIX}/opt/${formula}" ]] || brew install "${formula}"
    done

    casks=(
        firefox
        font-sauce-code-pro-nerd-font
        google-chrome
        iina
        iterm2
        karabiner-elements
        lulu
        rectangle
        stats
        visual-studio-code
        vlc
    )
    for cask in "${casks[@]}" ; do
        [[ -d "${BREW_PREFIX}/Caskroom/${cask}" ]] || brew install --cask "${cask}"
    done

    # Make sure this folder exists before linking completion files
    [ -d ~/.zshrc.d/completion/ ] || mkdir -p ~/.zshrc.d/completion

    ### Accessibility
    # `Display/Reduce transparency`
    # Requires logout
    defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool true
    defaults write com.apple.universalaccess reduceTransparency -bool true

    ### coreutils
    # Replace some macOS's coreutils binaries with GNU ones. We do this because some of our zsh
    # aliases depend on specific GNU's coreutils flags.
    for symlink in date diff dircolors du head rm sed sort; do
        [[ -L ~/.usr/bin/"${symlink}" ]] || ln -s "${BREW_PREFIX}/opt/coreutils/bin/g${symlink}" ~/.usr/bin/"${symlink}"
    done

    ### curl
    # Use homebrew's curl so that we can use its zsh completion and have a binary with a matching
    # version
    [[ -L ~/.usr/bin/curl ]] || ln -s "${BREW_PREFIX}/opt/curl/bin/curl" ~/.usr/bin/
    [[ -L ~/.zshrc.d/completion/_curl ]] || ln -s "${BREW_PREFIX}/opt/curl/share/zsh/site-functions/_curl" ~/.zshrc.d/completion/

    ### Clock
    # Don't show day of week
    defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false
    # Never show date
    defaults write com.apple.menuextra.clock ShowDate 2

    ### Desktop & Dock
    # Windows/Prefer tabs when opening documents: Always
    defaults write "Apple Global Domain" AppleWindowTabbingMode always

    ### Finder
    # Show all the extensions
    defaults write com.apple.finder AppleShowAllExtensions -bool true
    # Show the folders first
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    # Show the path bar
    defaults write com.apple.finder ShowPathbar -bool true
    # Allow quitting (lets us hide Finder from the App Switcher)
    defaults write com.apple.finder QuitMenuItem -bool true
    # Automatically empty the Bin after 30 days
    defaults write com.apple.finder FXRemoveOldTrashItems -bool true
    # Open new windows in home directory
    defaults write com.apple.finder NewWindowTarget PfHm
    killall Finder || true

    ### Preview
    # Disable named annotations
    defaults write com.apple.preview PVGeneralUseUserName -bool false

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

    ### terminfo
    # We need the terminfo capabilites of tmux-256color, however macOS doesn't
    # provide one. The one in homebrew's ncurses package is incompatible
    # with macOS' ncurses tools (tic/terminfo). So we export the terminfo
    # capabilities with homebrew's ncurses' infocmp and compile them with macOS'
    # tic.
    "${BREW_PREFIX}/opt/ncurses/bin/infocmp" -x tmux-256color > ~/.terminfo/tmux-256color.ncurses.terminfo
    # This command will generate a binary terminfo database in ~/.terminfo and the next one
    # will generate a terminfo database with the same name, however since our custom version
    # includes the same terminfo database (use=tmux-256color), our capabilities will be added to
    # the former one.
    tic -x ~/.terminfo/tmux-256color.ncurses.terminfo
    tic -x ~/.terminfo/tmux-256color.terminfo

    ### zsh-completions
    # Link only the completion files we need
    for completion in cmake gpgconf node ; do
        [[ -L ~/.zshrc.d/completion/_"${completion}" ]] || ln -s "${BREW_PREFIX}/share/zsh-completions/_${completion}" ~/.zshrc.d/completion/
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

    ### Keyboard
    ## Delay until repeat: Short
    defaults write "Apple Global Domain" InitialKeyRepeat 15
    ## Key repeat rate: Fast
    defaults write "Apple Global Domain" KeyRepeat 2
    ## Keyboard Shortcuts
    # App Shortcuts: Always paste with current style (disregard source style) with ⌘+v
    defaults write -g NSUserKeyEquivalents -dict-add "Paste and Match Style" "@v"
    # Input Sources: Select the previous/next input source
    /usr/libexec/PlistBuddy -c 'Set AppleSymbolicHotKeys:60:enabled 0' ~/Library/Preferences/com.apple.symbolichotkeys.plist
    /usr/libexec/PlistBuddy -c 'Set AppleSymbolicHotKeys:61:enabled 0' ~/Library/Preferences/com.apple.symbolichotkeys.plist
    ## Text Input > Text Replacements
    /usr/libexec/PlistBuddy -x \
        -c 'Delete :NSUserDictionaryReplacementItems' \
        -c 'Add :NSUserDictionaryReplacementItems array' \
        -c 'Add :NSUserDictionaryReplacementItems: dict' \
            -c 'Add :NSUserDictionaryReplacementItems:0:on integer 1' \
            -c 'Add :NSUserDictionaryReplacementItems:0:replace string "omw"' \
            -c 'Add :NSUserDictionaryReplacementItems:0:with string "On my way!"' \
        -c 'Add :NSUserDictionaryReplacementItems: dict' \
            -c 'Add :NSUserDictionaryReplacementItems:1:on integer 1' \
            -c 'Add :NSUserDictionaryReplacementItems:1:replace string "---"' \
            -c 'Add :NSUserDictionaryReplacementItems:1:with string "(-|_)"' \
        -c 'Add :NSUserDictionaryReplacementItems: dict' \
            -c 'Add :NSUserDictionaryReplacementItems:2:on integer 1' \
            -c 'Add :NSUserDictionaryReplacementItems:2:replace string "shrug"' \
            -c 'Add :NSUserDictionaryReplacementItems:2:with string "¯\\_(ツ)_/¯"' \
        ~/Library/Preferences/.GlobalPreferences.plist
    ## Input Sources > Disable `Add period with double-space`
    defaults write "Apple Global Domain" NSAutomaticPeriodSubstitutionEnabled -bool false
    ## Reload config
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    ## Karabiner
    osascript -e 'quit app "Karabiner-Elements"'
    [[ -d ~/.config/karabiner ]] || mkdir -p ~/.config/karabiner/
    # /!\ Symlinking doesn't work for this file
    cp -fR karabiner/.config/karabiner/karabiner.json ~/.config/karabiner/
    osascript -e 'tell application "Karabiner-Elements" to activate'

    ## Compose key keybindings
    [[ -d ~/Library/KeyBindings ]] || mkdir -p ~/Library/KeyBindings
    # /!\ This requires Karabiner's `right_command -> non_us_backslash` mapping
    # /!\ Symlinking doesn't work for this file
    cp -fR base-macos/Library/KeyBindings/DefaultKeyBinding.dict ~/Library/KeyBindings
    # Disable the character palette when holding a key (applications need to be restarted)
    defaults write -g ApplePressAndHoldEnabled -bool false

    ### Terminal.app
    # Use Option as Meta key
    /usr/libexec/PlistBuddy -c 'Set :"Window Settings":Basic:useOptionAsMetaKey 1' ~/Library/Preferences/com.apple.Terminal.plist

    ### Rectangle
    # Hide menu bar icon
    defaults write com.knollsoft.Rectangle hideMenubarIcon -bool true
    # Launch on login
    defaults write com.knollsoft.Rectangle launchOnLogin -bool true

    ### Spotlight
    ## Requires a logout!
    # Show Related Content: Disabled
    defaults write com.apple.Spotlight EnabledPreferenceRules -array-add Custom.relatedContents
    # Results from App: Disabled
    defaults write com.apple.Spotlight EnabledPreferenceRules -array-add \
        com.apple.AppStore \
        com.apple.iBooksX \
        com.apple.mail \
        com.apple.podcasts \
        com.apple.Safari \
        com.apple.stocks \
        com.apple.VoiceMemos \
        System.documents \
        System.folders

    ### Student service (if the mac was bought by a school or with a student account)
    # Disable and stop
    launchctl disable gui/$(id -u)/com.apple.studentd
    launchctl stop com.apple.studentd

    ### Stats
    # Configure basic settings
    defaults write eu.exelban.Stats runAtLoginInitialized -bool true
    defaults write eu.exelban.Stats setupProcess -bool true
    defaults write eu.exelban.Stats telemetry -bool false
    defaults write eu.exelban.Stats update-interval "At start"
    # Needed otherwise the defaults will be reset
    defaults write eu.exelban.Stats version 2.11.64
    # Enable combined modules display
    defaults write eu.exelban.Stats CombinedModules -bool true
    # Enable some widgets
    stats_widgets=(Battery CPU RAM GPU Network Sensors Disk)
    for widget in "${stats_widgets[@]}"; do
        defaults write eu.exelban.Stats "${widget}"_state -bool true
    done
    # Configure some widgets
    stats_widgets=(CPU RAM GPU Disk)
    for widget in "${stats_widgets[@]}" ; do
        defaults write eu.exelban.Stats "${widget}"_widget mini
        defaults write eu.exelban.Stats "${widget}"_mini_color utilization
    done
    # Battery
    defaults write eu.exelban.Stats Battery_battery_additional innerPercentage
    defaults write eu.exelban.Stats Battery_battery_color -bool true
    defaults write eu.exelban.Stats Battery_battery_lowPowerMode -bool true
    defaults write eu.exelban.Stats Battery_widget battery
    # Disk
    defaults write eu.exelban.Stats Disk_widget mini
    defaults write eu.exelban.Stats SSD_mini_color utilization
    # Network
    defaults write eu.exelban.Stats Network_speed_value -bool true
    defaults write eu.exelban.Stats Network_speed_valueColor -bool true
    # Sensors
    defaults write eu.exelban.Stats Sensors_widget sensors
    defaults write eu.exelban.Stats "sensor_Average CPU" -bool true
    defaults write eu.exelban.Stats sensor_PSTR -bool true
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
    for dir in *-macos iterm2 ; do
        symlink "${dir}"
    done

    echo Some macOS settings require a logout\! >&2
fi

# terminfo
for terminfo in ~/.terminfo/*.terminfo ; do
    tic -x "${terminfo}"
done

# Symlink the dotfiles
for dir in base docker emacs idea js karabiner mpv nvim ssh tmux zed zsh; do
    symlink "${dir}"
done

# Linux specific
if ./base/.usr/bin/_onlinux ; then
    # Make a symlink from open to xdg-open, so that `open` or the `o` alias work the same on Linux
    # or macOS
    [[ -L ~/.usr/bin/open ]] || ln -s /usr/bin/xdg-open ~/.usr/bin/open

    # Symlink Linux specific dotfiles
    for dir in *-linux alacritty ; do
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
