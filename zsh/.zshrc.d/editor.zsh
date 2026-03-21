# -*- mode: sh -*-

### Zsh line editor config
# Adapted from https://github.com/sorin-ionescu/prezto/blob/master/modules/editor/init.zsh

# https://en.wikipedia.org/wiki/ANSI_escape_code#C0_control_codes
# ^[ is Escape
# ^I is Tab
# ^X is Control
# ^[[3~ is CSI (ESC [) 3 ~
#
# 0x08 = ^H/BS
# 0x7f = ^?/DEL
#
# iTerm2: If "Delete key sends ^H" is enabled, the delete key will send
# `0x08/BS/^H` instead of `0x7f/DEL/^?`
#
# Use bindkey -L to list the Zsh keybindings
# Use showkey -a on Linux to debug the keys pressed

# Set '|' as a between-word character
WORDCHARS="${WORDCHARS}|"

# Beep on error in line editor.
setopt BEEP

# Use human-friendly identifiers.
zmodload zsh/terminfo
typeset -gA key_info
key_info=(
  Control      '\C-'
  ControlLeft  '\e[1;5D \e[5D \e\e[D \eOd'
  ControlRight '\e[1;5C \e[5C \e\e[C \eOc'
  Escape       '\e'
  Meta         '\M-'
  Backspace    "^?"
  Delete       "^[[3~"
  F1           "$terminfo[kf1]"
  F2           "$terminfo[kf2]"
  F3           "$terminfo[kf3]"
  F4           "$terminfo[kf4]"
  F5           "$terminfo[kf5]"
  F6           "$terminfo[kf6]"
  F7           "$terminfo[kf7]"
  F8           "$terminfo[kf8]"
  F9           "$terminfo[kf9]"
  F10          "$terminfo[kf10]"
  F11          "$terminfo[kf11]"
  F12          "$terminfo[kf12]"
  Insert       "$terminfo[kich1]"
  Home         "$terminfo[khome]"
  PageUp       "$terminfo[kpp]"
  End          "$terminfo[kend]"
  PageDown     "$terminfo[knp]"
  Up           "$terminfo[kcuu1]"
  Left         "$terminfo[kcub1]"
  Down         "$terminfo[kcud1]"
  Right        "$terminfo[kcuf1]"
  BackTab      "$terminfo[kcbt]"
)

# Set empty $key_info values to an invalid UTF-8 sequence to induce silent
# bindkey failure.
for key in "${(k)key_info[@]}"; do
    if [[ -z "$key_info[$key]" ]]; then
        key_info[$key]='�'
    fi
done

# Used by the prompt theme, notably to show if the zle is in vicmd or not
# Exposes information about the Zsh Line Editor via the $editor_info associative
# array.
function editor-info {
  # Clean up previous $editor_info.
    unset editor_info
    typeset -gA editor_info

    if [[ $KEYMAP == vicmd ]]; then
        zstyle -s :editor:info:keymap:alternate format REPLY
        editor_info[keymap]=$REPLY
    else
        zstyle -s :editor:info:keymap:primary format REPLY
        editor_info[keymap]=$REPLY
    fi

    unset REPLY

    zle reset-prompt
    zle -R
}
zle -N editor-info

# Updates editor information when the keymap changes.
function zle-keymap-select {
    zle editor-info
}
zle -N zle-keymap-select

# Enables terminal application mode and updates editor information.
function zle-line-init {
    # The terminal must be in application mode when ZLE is active for $terminfo
    # values to be valid.
    if (( $+terminfo[smkx] )); then
        # Enable terminal application mode.
        echoti smkx
    fi

    # Update editor information.
    zle editor-info
}
zle -N zle-line-init

# Disables terminal application mode and updates editor information.
function zle-line-finish {
    # The terminal must be in application mode when ZLE is active for $terminfo
    # values to be valid.
    if (( $+terminfo[rmkx] )); then
        # Disable terminal application mode.
        echoti rmkx
    fi

    # Update editor information.
    zle editor-info
}
zle -N zle-line-finish

# Enters vi insert mode and updates editor information.
function vi-insert {
    zle .vi-insert
    zle editor-info
}
zle -N vi-insert

# Moves to the first non-blank character then enters vi insert mode and updates
# editor information.
function vi-insert-bol {
    zle .vi-insert-bol
    zle editor-info
}
zle -N vi-insert-bol

# Enters vi replace mode and updates editor information.
function vi-replace  {
    zle .vi-replace
    zle editor-info
}
zle -N vi-replace

# Expands .... to ../..
function expand-dot-to-parent-directory-path {
    if [[ $LBUFFER = *.. ]]; then
        LBUFFER+='/..'
    else
        LBUFFER+='.'
    fi
}
zle -N expand-dot-to-parent-directory-path

# Use the `emacs` keymap by default
bindkey -e

### `vicmd` keymap
# Press `v` in Vi Mode to edit command line with $VISUAL or $EDITOR
autoload -Uz edit-command-line; zle -N edit-command-line
bindkey -M vicmd v edit-command-line

### `emacs` keymap
# Delete the char under the cursor (`fn + delete` on macOS)
bindkey $key_info[Delete] delete-char

# Bind Shift + Tab to go to the previous completion menu item.
bindkey $key_info[BackTab] reverse-menu-complete

# Expand .... to ../..
bindkey . expand-dot-to-parent-directory-path

# Generate completion trace
bindkey $key_info[Control]x\? _complete_debug

# Select the vicmd keymap
bindkey $key_info[Escape] vi-cmd-mode

# Make M-backspace delete path components (and not the whole word/path) by stopping at '/'
backward-kill-dir () {
    local WORDCHARS=${WORDCHARS/\/}
    zle backward-kill-word
}
zle -N backward-kill-dir
bindkey "$key_info[Escape]$key_info[Backspace]" backward-kill-dir

# Rewrite some mistakenly typed commands
typeset -A COMMAND_REWRITE_TABLE=(
  brwe brew
  bwre brew
  gti  git
  sl   ls
)
COMMAND_SEPARATORS=('|' '||' '&&' ';')
command_rewrite_on_space() {
    # NOTE Doesn't support replacements in nested commands contexts ($() & ``)
    local buf="$BUFFER"
    local -a parts
    parts=("${(z)buf}") # Split on high-level token parsed

    # Find the last command token: Scan backwards to last separator
    local cmd_index=${#parts}
    local i s
    for (( i=${#parts}; i>0; i-- )); do
        if (( $COMMAND_SEPARATORS[(Ie)${parts[i]}] )); then
            cmd_index=$((i+1))
            break
        fi
    done

    # Skip leading env vars assignments after separator
    while (( cmd_index <= ${#parts} )) && [[ ${parts[cmd_index]} == *=* ]]; do
        ((cmd_index++))
    done

    # Rebuild command while replacing command token if needed
    if (( cmd_index <= ${#parts} )); then
        local cmd=${parts[cmd_index]}
        if (( ${+COMMAND_REWRITE_TABLE[$cmd]} )); then
            parts[cmd_index]=${COMMAND_REWRITE_TABLE[$cmd]}

            BUFFER=""
            [[ $buf == ' '* ]] && BUFFER=" "
            BUFFER+="${(j: :)parts}"
            CURSOR=${#BUFFER}
        fi
    fi

    zle .self-insert
}
zle -N command_rewrite_on_space
bindkey ' ' command_rewrite_on_space
