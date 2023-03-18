### Set some important environment variables

### Why ~/.zprofile and not ~/.zshenv:
# Requirements:
# - We need to be the last to prepend to PATH in order to put our overriding folders first in the
#   variable
# - New terminal tabs/windows need to have a proper GPG_TTY variable set

# macOS: /etc/zprofile PREPENDS to PATH
# Arch Linux: /etc/zprofile APPENDS to PATH

# Files sourced:
# - Login/Interactive:         ~/.zshenv > /etc/zprofile > ~/.zprofile
# - Login/Non-Interactive:     ~/.zshenv > /etc/zprofile > ~/.zprofile
# - Non-Login/Interactive:     ~/.zshenv > /etc/zprofile
# - Non-Login/Non-Interactive: ~/.zshenv > /etc/zprofile

# New terminal tabs/windows defaults:
# - tmux: Login shell
# - iTerm2: Login shell
# - Alacritty: Login shell
# - gnome-console: Non-login shell
# - lxterminal: Login shell

# Summary:
# - macOS:
#   - For all terminals, only ~/.zprofile will work for the PATH variable
#   - With iTerm2 and tmux, ~/.zprofile will work for the GPG_TTY variable
# - Arch Linux:
#   - For all terminals, ~/.zshenv will work for the PATH and GPG_TTY variables
#   - With Alacritty and tmux, ~/.zprofile will work for the GPG_TTY variable

# Conclusion:
# - macOS: Use ~/.zprofile and iTerm2/tmux
# - Arch Linux: Use ~/.zprofile and Alacritty/tmux

### All the important environment variables are in ~/.profile so that bash has them too
source ~/.profile
