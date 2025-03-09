# `Terminfo`

Terminfo is a way to tell running applications what capabilities the terminal
they run on supports. 24-bit colors support is a bit of a new development and is
tricky to get properly on all layers. These terminfo are an attempt at making
most things work!

The terminfo source format, and associated capabilities are defined here:
https://pubs.opengroup.org/onlinepubs/7908799/xcurses/terminfo.html

## History

24-bit colors started being supported by some terminals without a corresponding
exposed capability. (Konsole probably being the first to do it properly).
They expected this escape sequence, with either ';' or ':' or sometimes both as
delimiters:
  - "\033[38;2;%d;%d;%dm" for the foreground color
  - "\033[48;2;%d;%d;%dm" for the background color
They had found this sequence in ITU's T.416 standard.

24-bit colors was still impossible to detect according to the standards, so
programs started to implement their own detection mechanism. Eg. Emacs 26 with
the capabilites setb24/setf24, and Tmux with the Tc or RGB capabilities.

Support for a new capability that should support 24-bit colors was added in
ncurses 6.0:
https://lists.gnu.org/archive/html/bug-ncurses/2018-01/msg00045.html But it
seems that it was patchy at best:
https://gist.github.com/XVilka/8346728#gistcomment-2347656

Learn more here:
- https://gist.github.com/XVilka/8346728
- https://cgit.kde.org/konsole.git/tree/doc/user/README.moreColors

## Implementation

We have created two custom terminfos:
- One for xterm-like terminals (eg. alacritty, gnome-terminal, or iterm2):
  xterm-256color
- One for tmux: tmux-256color

They are named `XXX-256color` but actually enable True colors.

The main reasons for creating these custom terminfos are:

- By advertising a common 256color profile, but by actually enabling True colors
  support we don't need to override $TERM when we use ssh. If the remote has our
  custom terminfo, True colors will be supported. If not, the remote will
  properly fallback to the real 256color terminfo.
- Emacs 26 needs the specific capabilities `setb24` and `setf24` in order to
  show True colors. Emacs 27 only needs that the now standard `RGB` capability
  be defined. At the time of writing this, Emacs 27 hasn't been released yet.
