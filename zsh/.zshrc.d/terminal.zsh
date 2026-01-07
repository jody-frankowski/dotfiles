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

_set-window-title () {
    # Sets the terminal window title with the following OSC:
    # https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
    # Works with most terminals however some might need further configuration.
    # In tmux, it sets the #{pane_title} variable.

    printf '\e]2;%s\a' "$@"
}

_term-title-cmd () {
    # Sets the window title with the current command

    # $1 contains the full command line as-is, e.g. `f () { vim } ; la`
    # $2 contains the expanded command with function bodies elided, e.g. `f () { ... } ; ls -la`
    # $3 contains the full expanded command:
    # f () {
    #   vim
    # }
    # ls -la

    # Zsh subscript expressions used in this function:
    # - ${var[(i)PATTERN]}: Get the index of the first element in the array that matches PATTERN
    # - ${var[(r)PATTERN]}: Get the first element in the array that matches PATTERN
    # - ${var[(w)INDEX]}:   Split a string on space separated words
    # - Example: ${var[(wr)^(*=*|-*)]}
    #   - (w)        $var is split on space separated words
    #   - (r)        Get the first word that matches the pattern `^(*=*|-*)`
    #   - ^(*=*|-*)  Matches anything that isn't assignements (e.g. a=1) or command flags (e.g. -v)

    local cmdline=(${(z)1}) # Split on whitespace separated words
    local cmd_index=(${cmdline[(i)^(\(|*=*)]}) # Get index of first command-like word (skipping `(` and `var=...`)
    cmdline=(${cmdline[$cmd_index,-1]}) # Skip `(` and `var=...`
    local cmd=${cmdline[1]:t} # Take only the tail of the command (e.g. Removes /usr/bin/)
    local args=(${cmdline[2,-1]})

    local title=""
    [[ $USER == root || $cmd == (run0|sudo) ]] && title+="⚡ "

    if [[ $cmd == (%*|fg) ]]; then
        # Set title to job's command
        # Get the job id (%%/%1/%2...), or if missing, set it to the current job (%%)
        local job_id="${${cmd[(wr)%?]}:-%%}"
        title+="${jobtexts[$job_id]}"
    elif [[ $cmd == (apropos|man) ]]; then
        # Set title to manpage
        [[ ${args[1]} =~ "^[0-9]+$" ]] && shift args # Skip manpage section (e.g. `man 3 printf`)
        title+="$cmd ${args[1]}"
    elif [[ $cmd == (mosh|s|ssh|sshrc) ]]; then
        # Set title to remote hostname and executed command
        local remote=${args[(r)^(-*)]}
        local remote_host=$remote
        if [[ $remote == *@* ]]; then
            local remote_user=${${(@s:@:)remote}[1]}
            local remote_host=${${(@s:@:)remote}[2]}
        fi
        local remote_index=${args[(i)^(-*)]}
        local remote_cmd=${args[$remote_index + 1]}

        [[ $remote_user == root ]] && title+="⚡ "
        title+=$remote_host
        [[ -n $remote_cmd ]] && title+=" $remote_cmd"
    elif [[ $cmd == (run0|sudo) ]]; then
        # Set title to the sudo command
        title+="${args[(r)^(-*)]}"
    else
        # Set title to the command name
        title+=$cmd
    fi

    _set-window-title $title
}

_term-title-path () {
    # Sets the window title with the current path

    local title=""
    [[ $USER == root ]] && title+="⚡ "

    local pwd="${PWD/#$HOME/~}"
    if [[ "$pwd" == "~" ]]; then
        title+="~"
    else
        # Paths like `$HOME/.config/something` will be transformed into `~/.c/something`
        title+="${${${${(@j:/:M)${(@s:/:)pwd}##.#?}:h}%/}//\%/%%}/${${pwd:t}//\%/%%}"
    fi

    _set-window-title $title
}

# Set the window title before command execution
add-zsh-hook preexec _term-title-cmd
# Set the window title before displaying the prompt
add-zsh-hook precmd  _term-title-path

_terminal-osc7-set-cwd() {
    # Used by tmux's `pane_path`.
    # It's not standard, but we follow this dead proposal:
    # https://gitlab.freedesktop.org/terminal-wg/specifications/-/merge_requests/7/diffs
    # Contrary to the discussion in the PR, there is actually an advantage for paths on UNIX
    # systems: The system primitives used to get the subprocess path always result in their
    # realpath. It works with symlinks, but can be surprising.
    # e.g. `mkdir real; ln -s real symlink; cd symlink; ls -la /proc/$$/cwd` >> `[...]/real`
    printf "\e]7;file://$HOST/$PWD\e\\"
}
add-zsh-hook chpwd _terminal-osc7-set-cwd
_terminal-osc7-set-cwd # Call it at least once when the shell starts
