# Correct commands
setopt CORRECT

# Directory options
setopt AUTO_CD              # Auto changes to a directory without typing cd.
setopt AUTO_PUSHD           # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS    # Do not store duplicates in the stack.
setopt PUSHD_SILENT         # Do not print the directory stack after pushd or popd.
setopt PUSHD_TO_HOME        # Push to home directory when no argument is given.
setopt CDABLE_VARS          # Change directory to a path stored in a variable.
setopt AUTO_NAME_DIRS       # Auto add variable-stored paths to ~ list.
setopt MULTIOS              # Write to multiple descriptors.
setopt EXTENDED_GLOB        # Use extended globbing syntax.
unsetopt CLOBBER            # Do not overwrite existing files with > and >>.
                            # Use >! and >>! to bypass.

# History options
# https://github.com/sorin-ionescu/prezto/blob/master/modules/history/init.zsh
HISTFILE="${ZDOTDIR:-$HOME}/.zhistory"       # The path to the history file.
HISTSIZE=10000                   # The maximum number of events to save in the internal history.
SAVEHIST=10000                   # The maximum number of events to save in the history file.
setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt HIST_BEEP                 # Beep when accessing non-existent history.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.
setopt SHARE_HISTORY             # Share history between all sessions.

# https://github.com/sorin-ionescu/prezto/blob/master/modules/environment/init.zsh
# Smart urls quoting
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# General
setopt BRACE_CCL          # Allow brace character class list expansion.
setopt COMBINING_CHARS    # Combine zero-length punctuation characters (accents)
                          # with the base character.
setopt RC_QUOTES          # Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
unsetopt MAIL_WARNING     # Don't print a warning message if a mail file has been accessed.

# Jobs
setopt LONG_LIST_JOBS     # List jobs in the long format by default.
setopt AUTO_RESUME        # Attempt to resume existing job before creating a new process.
setopt NOTIFY             # Report status of background jobs immediately.
unsetopt BG_NICE          # Don't run all background jobs at a lower priority.
unsetopt HUP              # Don't kill jobs on shell exit.
unsetopt CHECK_JOBS       # Don't report on jobs when shell exit.

# Less termcap config that enables colored man pages
export LESS_TERMCAP_mb=$'\E[01;31m'      # Begins blinking.
export LESS_TERMCAP_md=$'\E[01;31m'      # Begins bold.
export LESS_TERMCAP_me=$'\E[0m'          # Ends mode.
export LESS_TERMCAP_se=$'\E[0m'          # Ends standout-mode.
export LESS_TERMCAP_so=$'\E[00;47;30m'   # Begins standout-mode.
export LESS_TERMCAP_ue=$'\E[0m'          # Ends underline.
export LESS_TERMCAP_us=$'\E[01;32m'      # Begins underline.

### GPG Agent
# The following applies for a GPG Agent configured with
# pinentry-tty. For the others it's probably much easier.

# This variable is used by the command `gpg-connect-agent updatestartuptty /bye`
# to tell pinentry-tty on which TTY to prompt the user.
# It might get removed someday: https://dev.gnupg.org/T3412
export GPG_TTY="$(tty)"

# We don't call `gpg-connect-agent updatestartuptty /bye` here because
# it's mostly useless (the last to be started terminal would be the
# one gpg/pinentry-tty would try to write on, which is almost never
# what we want).

# Instead we do this in wrappers around commands that can trigger
# gpg/pinentry prompts (ssh, ssh-add).  Note that commands like git
# and sshfs will call our wrapper.  It's possible that this won't work
# for programs written with libssh!
###

# Generate the LS_COLORS variable
eval `dircolors ~/.dir_colors`

# Needed by some loaded scripts
autoload -Uz add-zsh-hook

# Loads aliases, functions , the prompt theme and others
for script in ~/.zshrc.d/*.zsh ; do
    source ${script}
done

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

### Hooks
# Auto ls when cd
chpwd() {
    # Make sure we are not in anything else than in shell/chpwd.
    [[ $ZSH_EVAL_CONTEXT == "toplevel:shfunc" ]] || return
    emulate -L zsh
    ls --color=auto --group-directories-first
}

# Search the command in available packages and if found install the package
# and retry to execute the command
if type pacman > /dev/null ; then
command_not_found_handler() {
    pkgs=($(pkgfile -b -- "$1"))
    if [[ -n "$pkgs" ]] ; then
        echo "Command not found but package found!" >&2
        echo "Installing ${pkgs[1]}\n" >&2

        sudo pacman -S ${pkgs[1]} >&2

        echo "\nExecuting $@" >&2

        "$@"
        return $?
    else
        echo "Command or package not found: $1" >&2
        return 127
    fi
}
fi
###

### Plugins
# fzf
if [[ "$OSTYPE" == "darwin"* ]]; then
    fzf_path=/opt/homebrew/opt/fzf/shell/
else
    fzf_path=/usr/share/fzf/
fi
source ${fzf_path}/completion.zsh
source ${fzf_path}/key-bindings.zsh
###
