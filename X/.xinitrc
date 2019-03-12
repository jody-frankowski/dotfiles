#!/bin/sh

# X resources customization
xrdb -I$HOME -merge ~/.Xresources

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/* ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

. $HOME/.xinitrc-local &

umask 077

# Set qt5 theme
QT_STYLE_OVERRIDE=GTK+

## Java settings
# Hack for java grey windows https://wiki.archlinux.org/index.php/java#Applications_not_resizing_with_WM.2C_menus_immediately_closing
export _JAVA_AWT_WM_NONREPARENTING=1
# Force Anti-Aliasing and GTK Feel https://wiki.archlinux.org/index.php/java#Tips_and_tricks
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel'

# Numkeypad on
numlockx &

# Auto lock
xautolock -time 5 -locker slock &

# Stupid fix for X shaped cursor in bspwm
xsetroot -cursor_name left_ptr &

feh --no-fehbg --bg-fill ~/.config/tux.png &

# TODO find out why screen blanking doesn't work
#xset s off
#xset -dpms

# Clean some stuff
# We do it here because some clean up tasks need the applications to be closed
# (eg Firefox)
~/.usr/scripts/clean

# Start Apps
sxhkd -m 1 &
lxpolkit &
firefox &>/dev/null &
alacritty -e ~/.tmux/start-tmux.sh &

# Remove when https://github.com/jonls/redshift/issues/318 is closed
nohup redshift -l $(curl ipinfo.io | jq -j .loc | tr ',' ':') &>/dev/null &

# Automount removable drives
devmon &

# While loop so that killing bspwm would restart it right away
while true; do
    # Log everything to a file (not on the starting TTY)
    mv ~/.usr/var/log/bspwm.log{,.old}
    bspwm &> ~/.usr/var/log/bspwm.log || break
done
