# -*- mode: sh -*-

# Docs:
# - https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
# - https://en.wikipedia.org/wiki/ANSI_escape_code
# - https://vtdn.dev/docs/category/c0-control-codes

# Only run when called with a terminal attached
[[ -o interactive && -t 1 && -t 2 && -n $TERM && $TERM != (dumb|linux) ]] || return 0

() {
  emulate -L zsh

  # No terminfo tooling? Leave TERM alone rather than guessing.
  (( $+commands[infocmp] )) || return 0
  infocmp $TERM &>/dev/null && return 0

  print -ru2 -- "terminfo: no entry for '$TERM'"

  # Build candidates: for each stripped prefix, prefer -256color first,
  # then generic fallbacks. Deduplicate and drop the original TERM.
  local -a candidates
  local base=$TERM c
  while [[ $base == *-* ]]; do
    base=${base%-*}
    candidates+=( $base-256color $base )
  done
  candidates+=( xterm-256color xterm vt100 )
  candidates=( ${(u)candidates:#$TERM} )

  for c ($candidates)
    if infocmp $c &>/dev/null; then
      print -ru2 -- "terminfo: falling back to '$c'"
      export TERM=$c
      return 0
    fi

  print -ru2 -- "terminfo: database appears unusable; leaving TERM=$TERM"
}

# Colored less and manpages
# See `man -P "$PAGER -p '-Dxcolor'" less`
export LESS='-i -M -R -j4 --use-color -DCwk -DEr~ -DNr -DPw~ -DSw~'
export MANPAGER='less -Dd+r -Dk+r -Dsw~ -Dug*'

_term-title-set () {
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

    _term-title-set $title
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

    _term-title-set $title
}
# Set the window title before command execution
add-zsh-hook preexec _term-title-cmd
# Set the window title before displaying the prompt
add-zsh-hook precmd  _term-title-path

_term-osc7-set-cwd() {
    # Used by tmux's `pane_path`.
    # It's not standard, but we follow this dead proposal:
    # https://gitlab.freedesktop.org/terminal-wg/specifications/-/merge_requests/7/diffs
    # Contrary to the discussion in the PR, there is actually an advantage for paths on UNIX
    # systems: The system primitives used to get the subprocess path always result in their
    # realpath. It works with symlinks, but can be surprising.
    # e.g. `mkdir real; ln -s real symlink; cd symlink; ls -la /proc/$$/cwd` >> `[...]/real`

    # Skip subshells (Can't be guarded against at the top of terminal.zsh)
    (( ZSH_SUBSHELL )) && return 0
    printf "\e]7;file://$HOST/$PWD\e\\"
}
# Trigger on any directory change
add-zsh-hook chpwd  _term-osc7-set-cwd
# Trigger if ssh/subshell sessions exit early without clearing their own osc7 traces
add-zsh-hook precmd _term-osc7-set-cwd
_term-osc7-set-cwd # Call it at least once when the shell starts

() {
    # Build the reset string once instead of on every prompt
    local -a seqs=(
        $'\e[?1049l'                                   # Alternate screen off
        $'\e[?7h'                                      # Auto-wrap on
        $'\e[?25h'                                     # Cursor visible
        $'\e[?1004l'                                   # Focus reporting off
        $'\e[?1005l\e[?1006l\e[?1015l'                 # Mouse encodings off
        $'\e[?9l\e[?1000l\e[?1001l\e[?1002l\e[?1003l'  # Mouse tracking off
        $'\e[?1l\e>'                                   # Normal cursor keys & numeric keypad
        $'\e[?2026l'                                   # Synchronized output off
        $'\e[>4;0m'                                    # xterm modifyOtherKeys off
    )
    typeset -g _term_reset_seq=${(j::)seqs}
}
_term-reset-modes() {
    print -rn -- $_term_reset_seq
}
add-zsh-hook precmd _term-reset-modes

# Set OSC 133 prompt mark
# Tmux only supports OSC 133 A & C:
# https://github.com/tmux/tmux/blob/bef4865d91ff8e549a3a4d63563f0ef1a39a1a39/input.c#L3083
# Use Tmux's `next-prompt` for `A` & `next-prompt -o` for `C`
PS1+=$'%{\e]133;A\a%}'
