# Not ~/.zshenv because of https://wiki.archlinux.org/index.php/Zsh#Startup.2FShutdown_files
# https://lists.archlinux.org/pipermail/arch-general/2013-March/033109.html :

# /etc/profile is not a part of the regular list of startup files run for Zsh,
# but is sourced from /etc/zsh/zprofile in the zsh package. Users should take
# note that /etc/profile sets the $PATH variable which will overwrite any $PATH
# variable set in $ZDOTDIR/.zshenv. To prevent this, please set the $PATH
# variable in $ZDOTDIR/.zprofile.

source ~/.profile
