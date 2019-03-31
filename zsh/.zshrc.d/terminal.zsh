# -*- mode: sh -*-

### Terminal window title
# Apdapted from https://github.com/sorin-ionescu/prezto/blob/master/modules/terminal/init.zsh

# Return if requirements are not found.
if [[ "$TERM" == (dumb|linux|*bsd*|eterm*) ]]; then
    return 1
fi

if ! infocmp &> /dev/null ; then
    echo "Terminfo database '$TERM' not found!" >&2

    if infocmp "${TERM[(ws:-:)1]}" &> /dev/null ; then
        echo "Falling back to a dumber TERM: '${TERM[(ws:-:)1]}'!" >&2
        export TERM="${TERM[(ws:-:)1]}"
    else
        echo "Dumber TERM '${TERM[(ws:-:)1]}' not found either!" >&2
        echo "Falling back to 'xterm'!" >&2
        export TERM=xterm
    fi
fi

# Sets the terminal window title
# Make sure you have this in your tmux config, for this to work
# setw -g window-status-current-format "#I:#T#F"
# setw -g window-status-format "#I:#T#F"
_set-window-title () {
    printf '\e]2;%s\a' "$argv"
}

# Sets the window title with the current command
_terminal-set-titles-with-command () {
    emulate -L zsh
    setopt EXTENDED_GLOB

    local title=""
    # If we're connected with ssh and we're not in tmux
    if [[ -n ${SSH_CLIENT} && -z ${TMUX} ]] ; then
        title="${USER}@${HOST}: "
    fi

    # Get the command name that is under job control
    if [[ "${2[(w)1]}" == (fg|%*)(\;|) ]]; then
        # Get the job name, and, if missing, set it to the default %+
        local job_name="${${2[(wr)%*(\;|)]}:-%+}"

        # Make a local copy for use in the subshell.
        local -A jobtexts_from_parent_shell
        jobtexts_from_parent_shell=(${(kv)jobtexts})

        jobs "$job_name" 2>/dev/null > >(
            read index discarded
            # The index is already surrounded by brackets: [1]
            _terminal_set-titles-with-command "${(e):-\$jobtexts_from_parent_shell$index}"
        )
    else
        # Set the command name, or in the case of mosh/s/ssh/sshrc/sudo, the next command
        title="${title}${${2[(wr)^(*=*|mosh|s|ssh|sshrc|sudo|-*)]}:t}"
    fi
    _set-window-title "${title}"
}

# Sets the window title with the current path
_terminal-set-titles-with-path () {
    emulate -L zsh
    setopt EXTENDED_GLOB

    local title=""
    # If we're connected with ssh and we're not in tmux
    if [[ -n ${SSH_CLIENT} && -z ${TMUX} ]] ; then
       title="${USER}@${HOST}: "
    fi

    local pwd="${PWD/#$HOME/~}"
    if [[ "$pwd" == "~" ]]; then
        title="${title}~"
    else
        # Paths like "$HOME/.config/something" will show as "~/.c/something"
        title="${title}${${${${(@j:/:M)${(@s:/:)pwd}##.#?}:h}%/}//\%/%%}/${${pwd:t}//\%/%%}"
    fi
    _set-window-title "${title}"
}

# Sets the window title before the prompt is displayed
add-zsh-hook precmd _terminal-set-titles-with-path

# Sets the window title before command execution
add-zsh-hook preexec _terminal-set-titles-with-command
