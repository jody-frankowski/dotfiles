# -*- mode: sh -*-

# Adapted from https://github.com/sorin-ionescu/prezto/blob/master/modules/prompt/functions/prompt_paradox_setup

function coalesce {
    for arg in $argv; do
        print "$arg"
        return 0
    done
    return 1
}

# Gets the Git special action (am, bisect, cherry, merge, rebase).
# Borrowed from vcs_info and edited.
function _git-action {
  local action_dir
  local git_dir="$(git rev-parse --git-dir)"
  local apply_formatted
  local bisect_formatted
  local cherry_pick_formatted
  local cherry_pick_sequence_formatted
  local merge_formatted
  local rebase_formatted
  local rebase_interactive_formatted
  local rebase_merge_formatted

  for action_dir in \
    "${git_dir}/rebase-apply" \
    "${git_dir}/rebase" \
    "${git_dir}/../.dotest"
  do
    if [[ -d "$action_dir" ]] ; then
      zstyle -s ':git:info:action:apply' format 'apply_formatted' || apply_formatted='apply'
      zstyle -s ':git:info:action:rebase' format 'rebase_formatted' || rebase_formatted='rebase'

      if [[ -f "${action_dir}/rebasing" ]] ; then
        print "$rebase_formatted"
      elif [[ -f "${action_dir}/applying" ]] ; then
        print "$apply_formatted"
      else
        print "${rebase_formatted}/${apply_formatted}"
      fi

      return 0
    fi
  done

  for action_dir in \
    "${git_dir}/rebase-merge/interactive" \
    "${git_dir}/.dotest-merge/interactive"
  do
    if [[ -f "$action_dir" ]]; then
      zstyle -s ':git:info:action:rebase-interactive' format 'rebase_interactive_formatted' || rebase_interactive_formatted='rebase-interactive'
      print "$rebase_interactive_formatted"
      return 0
    fi
  done

  for action_dir in \
    "${git_dir}/rebase-merge" \
    "${git_dir}/.dotest-merge"
  do
    if [[ -d "$action_dir" ]]; then
      zstyle -s ':git:info:action:rebase-merge' format 'rebase_merge_formatted' || rebase_merge_formatted='rebase-merge'
      print "$rebase_merge_formatted"
      return 0
    fi
  done

  if [[ -f "${git_dir}/MERGE_HEAD" ]]; then
    zstyle -s ':git:info:action:merge' format 'merge_formatted' || merge_formatted='merge'
    print "$merge_formatted"
    return 0
  fi

  if [[ -f "${git_dir}/CHERRY_PICK_HEAD" ]]; then
    if [[ -d "${git_dir}/sequencer" ]] ; then
      zstyle -s ':git:info:action:cherry-pick-sequence' format 'cherry_pick_sequence_formatted' || cherry_pick_sequence_formatted='cherry-pick-sequence'
      print "$cherry_pick_sequence_formatted"
    else
      zstyle -s ':git:info:action:cherry-pick' format 'cherry_pick_formatted' || cherry_pick_formatted='cherry-pick'
      print "$cherry_pick_formatted"
    fi

    return 0
  fi

  if [[ -f "${git_dir}/BISECT_LOG" ]]; then
    zstyle -s ':git:info:action:bisect' format 'bisect_formatted' || bisect_formatted='bisect'
    print "$bisect_formatted"
    return 0
  fi

  return 1
}

# Gets the Git status information.
function git-info {
  # Extended globbing is needed to parse repository status.
  setopt LOCAL_OPTIONS
  setopt EXTENDED_GLOB

  local action
  local action_format
  local action_formatted
  local added=0
  local added_format
  local added_formatted
  local ahead=0
  local ahead_and_behind
  local ahead_and_behind_cmd
  local ahead_format
  local ahead_formatted
  local ahead_or_behind
  local behind=0
  local behind_format
  local behind_formatted
  local branch
  local branch_format
  local branch_formatted
  local branch_info
  local clean
  local clean_formatted
  local commit
  local commit_format
  local commit_formatted
  local deleted=0
  local deleted_format
  local deleted_formatted
  local dirty=0
  local dirty_format
  local dirty_formatted
  local ignore_submodules
  local indexed=0
  local indexed_format
  local indexed_formatted
  local -A info_formats
  local info_format
  local modified=0
  local modified_format
  local modified_formatted
  local position
  local position_format
  local position_formatted
  local remote
  local remote_cmd
  local remote_format
  local remote_formatted
  local renamed=0
  local renamed_format
  local renamed_formatted
  local stashed=0
  local stashed_format
  local stashed_formatted
  local status_cmd
  local status_mode
  local unindexed=0
  local unindexed_format
  local unindexed_formatted
  local unmerged=0
  local unmerged_format
  local unmerged_formatted
  local untracked=0
  local untracked_format
  local untracked_formatted

  # Clean up previous $git_info.
  unset git_info
  typeset -gA git_info

  # Return if not inside a Git repository work tree.
  if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    return 1
  fi

  # Ignore submodule status.
  zstyle -s ':git:status:ignore' submodules 'ignore_submodules'

  # Format commit.
  zstyle -s ':git:info:commit' format 'commit_format'
  if [[ -n "$commit_format" ]]; then
    commit="$(git rev-parse HEAD 2> /dev/null)"
    if [[ -n "$commit" ]]; then
      zformat -f commit_formatted "$commit_format" "c:$commit"
    fi
  fi

  # Format stashed.
  zstyle -s ':git:info:stashed' format 'stashed_format'
  if [[ -n "$stashed_format" && -f "$(git rev-parse --git-dir)/refs/stash" ]]; then
    stashed="$(git stash list 2> /dev/null | wc -l | awk '{print $1}')"
    if [[ -n "$stashed" ]]; then
      zformat -f stashed_formatted "$stashed_format" "S:$stashed"
    fi
  fi

  # Format action.
  zstyle -s ':git:info:action' format 'action_format'
  if [[ -n "$action_format" ]]; then
    action="$(_git-action)"
    if [[ -n "$action" ]]; then
      zformat -f action_formatted "$action_format" "s:$action"
    fi
  fi

  # Get the branch.
  branch="${$(git symbolic-ref HEAD 2> /dev/null)#refs/heads/}"

  # Format branch.
  zstyle -s ':git:info:branch' format 'branch_format'
  if [[ -n "$branch" && -n "$branch_format" ]]; then
    zformat -f branch_formatted "$branch_format" "b:$branch"
  fi

  # Format position.
  zstyle -s ':git:info:position' format 'position_format'
  if [[ -z "$branch" && -n "$position_format" ]]; then
    position="$(git describe --contains --all HEAD 2> /dev/null)"
    if [[ -n "$position" ]]; then
      zformat -f position_formatted "$position_format" "p:$position"
    fi
  fi

  # Format remote.
  zstyle -s ':git:info:remote' format 'remote_format'
  if [[ -n "$branch" && -n "$remote_format" ]]; then
    # Gets the remote name.
    remote_cmd='git rev-parse --symbolic-full-name --verify HEAD@{upstream}'
    remote="${$(${(z)remote_cmd} 2> /dev/null)##refs/remotes/}"
    if [[ -n "$remote" ]]; then
      zformat -f remote_formatted "$remote_format" "R:$remote"
    fi
  fi

  zstyle -s ':git:info:ahead' format 'ahead_format'
  zstyle -s ':git:info:behind' format 'behind_format'
  if [[ -n "$branch" && ( -n "$ahead_format" || -n "$behind_format" ) ]]; then
    # Gets the commit difference counts between local and remote.
    ahead_and_behind_cmd='git rev-list --count --left-right HEAD...@{upstream}'

    # Get ahead and behind counts.
    ahead_and_behind="$(${(z)ahead_and_behind_cmd} 2> /dev/null)"

    # Format ahead.
    if [[ -n "$ahead_format" ]]; then
      ahead="$ahead_and_behind[(w)1]"
      if (( ahead > 0 )); then
        zformat -f ahead_formatted "$ahead_format" "A:$ahead"
      fi
    fi

    # Format behind.
    if [[ -n "$behind_format" ]]; then
      behind="$ahead_and_behind[(w)2]"
      if (( behind > 0 )); then
        zformat -f behind_formatted "$behind_format" "B:$behind"
      fi
    fi
  fi

  # Get status type.
  if ! zstyle -t ':git:info' verbose; then
    # Format indexed.
    zstyle -s ':git:info:indexed' format 'indexed_format'
    if [[ -n "$indexed_format" ]]; then
      ((
        indexed+=$(
          git diff-index \
            --no-ext-diff \
            --name-only \
            --cached \
            --ignore-submodules=${ignore_submodules:-none} \
            HEAD \
            2> /dev/null \
          | wc -l
        )
      ))
      if (( indexed > 0 )); then
        zformat -f indexed_formatted "$indexed_format" "i:$indexed"
      fi
    fi

    # Format unindexed.
    zstyle -s ':git:info:unindexed' format 'unindexed_format'
    if [[ -n "$unindexed_format" ]]; then
      ((
        unindexed+=$(
          git diff-files \
            --no-ext-diff \
            --name-only \
            --ignore-submodules=${ignore_submodules:-none} \
            2> /dev/null \
          | wc -l
        )
      ))
      if (( unindexed > 0 )); then
        zformat -f unindexed_formatted "$unindexed_format" "I:$unindexed"
      fi
    fi

    # Format untracked.
    zstyle -s ':git:info:untracked' format 'untracked_format'
    if [[ -n "$untracked_format" ]]; then
      ((
        untracked+=$(
          git ls-files \
            --other \
            --exclude-standard \
            2> /dev/null \
          | wc -l
        )
      ))
      if (( untracked > 0 )); then
        zformat -f untracked_formatted "$untracked_format" "u:$untracked"
      fi
    fi

    (( dirty = indexed + unindexed + untracked ))
  else
    # Use porcelain status for easy parsing.
    status_cmd="git status --porcelain --ignore-submodules=${ignore_submodules:-none}"

    # Get current status.
    while IFS=$'\n' read line; do
      # Count added, deleted, modified, renamed, unmerged, untracked, dirty.
      # T (type change) is undocumented, see http://git.io/FnpMGw.
      # For a table of scenarii, see http://i.imgur.com/2YLu1.png.
      [[ "$line" == ([ACDMT][\ MT]|[ACMT]D)\ * ]] && (( added++ ))
      [[ "$line" == [\ ACMRT]D\ * ]] && (( deleted++ ))
      [[ "$line" == ?[MT]\ * ]] && (( modified++ ))
      [[ "$line" == R?\ * ]] && (( renamed++ ))
      [[ "$line" == (AA|DD|U?|?U)\ * ]] && (( unmerged++ ))
      [[ "$line" == \?\?\ * ]] && (( untracked++ ))
      (( dirty++ ))
    done < <(${(z)status_cmd} 2> /dev/null)

    # Format added.
    if (( added > 0 )); then
      zstyle -s ':git:info:added' format 'added_format'
      zformat -f added_formatted "$added_format" "a:$added"
    fi

    # Format deleted.
    if (( deleted > 0 )); then
      zstyle -s ':git:info:deleted' format 'deleted_format'
      zformat -f deleted_formatted "$deleted_format" "d:$deleted"
    fi

    # Format modified.
    if (( modified > 0 )); then
      zstyle -s ':git:info:modified' format 'modified_format'
      zformat -f modified_formatted "$modified_format" "m:$modified"
    fi

    # Format renamed.
    if (( renamed > 0 )); then
      zstyle -s ':git:info:renamed' format 'renamed_format'
      zformat -f renamed_formatted "$renamed_format" "r:$renamed"
    fi

    # Format unmerged.
    if (( unmerged > 0 )); then
      zstyle -s ':git:info:unmerged' format 'unmerged_format'
      zformat -f unmerged_formatted "$unmerged_format" "U:$unmerged"
    fi

    # Format untracked.
    if (( untracked > 0 )); then
      zstyle -s ':git:info:untracked' format 'untracked_format'
      zformat -f untracked_formatted "$untracked_format" "u:$untracked"
    fi
  fi

  # Format dirty and clean.
  if (( dirty > 0 )); then
    zstyle -s ':git:info:dirty' format 'dirty_format'
    zformat -f dirty_formatted "$dirty_format" "D:$dirty"
  else
    zstyle -s ':git:info:clean' format 'clean_formatted'
  fi

  # Format info.
  zstyle -a ':git:info:keys' format 'info_formats'
  for info_format in ${(k)info_formats}; do
    zformat -f REPLY "$info_formats[$info_format]" \
      "a:$added_formatted" \
      "A:$ahead_formatted" \
      "B:$behind_formatted" \
      "b:$branch_formatted" \
      "C:$clean_formatted" \
      "c:$commit_formatted" \
      "d:$deleted_formatted" \
      "D:$dirty_formatted" \
      "i:$indexed_formatted" \
      "I:$unindexed_formatted" \
      "m:$modified_formatted" \
      "p:$position_formatted" \
      "R:$remote_formatted" \
      "r:$renamed_formatted" \
      "s:$action_formatted" \
      "S:$stashed_formatted" \
      "U:$unmerged_formatted" \
      "u:$untracked_formatted"
    git_info[$info_format]="$REPLY"
  done

  unset REPLY

  return 0
}

function prompt_segment {
    local bg fg
    if [[ -n "$2" ]] && [[ "$2" != "NONE" ]] ; then
        bg="%K{$2}"
    fi
    if [[ -n "$3" ]] && [[ "$3" != "NONE" ]] ; then
        fg="%F{$3}"
    fi
    print -n "$bg$fg$1%f%k"
}

function prompt_build_prompt {
    # http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html
    # in order, show, the last command error code, if the shell is privileged
    # and if there are jobs running
    prompt_segment ' %(?::%F{red}%? )%(!:%F{yellow}⚡  :)%(1j:⚙  :)%F{blue}%n%F{red}@%F{green}%m%f '

    # %S aka standout mode, by inverting the colors, lets us have blue as
    # %background and default background as foreground. Hence this prompt will
    # %work with light terminal themes that don't invert black and white colors.
    prompt_segment '%S $_prompt_pwd %s' NONE blue

    if [[ -n "$git_info" ]]; then
        prompt_segment '%S ${(e)git_info[ref]}${(e)git_info[status]} %s' NONE green
    fi
}

function prompt_pwd {
    _prompt_pwd="${PWD/#$HOME/~}"
}

function prompt_print_elapsed_time {
    local end_time=$(( SECONDS - _prompt_start_time ))
    local hours minutes seconds remainder

    if (( end_time >= 3600 )); then
        hours=$(( end_time / 3600 ))
        remainder=$(( end_time % 3600 ))
        minutes=$(( remainder / 60 ))
        seconds=$(( remainder % 60 ))
        print -P "%B%F{red}>>> elapsed time ${hours}h${minutes}m${seconds}s%b"
    elif (( end_time >= 60 )); then
        minutes=$(( end_time / 60 ))
        seconds=$(( end_time % 60 ))
        print -P "%B%F{yellow}>>> elapsed time ${minutes}m${seconds}s%b"
    elif (( end_time > 10 )); then
        print -P "%B%F{green}>>> elapsed time ${end_time}s%b"
    fi
}

function prompt_precmd {
    setopt LOCAL_OPTIONS
    unsetopt XTRACE KSH_ARRAYS

    # Format PWD.
    prompt_pwd

    # Get Git repository information.
    if (( $+functions[git-info] )); then
        git-info
    fi

    # Calculate and print the elapsed time.
    prompt_print_elapsed_time
}

function prompt_preexec {
    _prompt_start_time="$SECONDS"
}

function prompt_setup {
    setopt LOCAL_OPTIONS
    unsetopt XTRACE KSH_ARRAYS
    # See man zshcontrib and zshoptions
    prompt_opts=(cr percent sp subst)

    # Load required functions.
    autoload -Uz add-zsh-hook

    # Add hook for calling git-info before each command.
    add-zsh-hook preexec prompt_preexec
    add-zsh-hook precmd prompt_precmd

    # Set editor-info parameters.
    zstyle ':editor:info:completing' format '%B%F{red}...%f%b'
    zstyle ':editor:info:keymap:primary' format '%B%F{blue}❯%f%b'
    zstyle ':editor:info:keymap:alternate' format '%B%F{red}❮%f%b'

    # Set git-info parameters.
    zstyle ':git:info' verbose 'yes'
    zstyle ':git:info:action' format ' ⁝ %s'
    zstyle ':git:info:added' format ' ✚'
    zstyle ':git:info:ahead' format ' ⬆'
    zstyle ':git:info:behind' format ' ⬇'
    zstyle ':git:info:branch' format '%b'
    zstyle ':git:info:commit' format '➦ %.7c'
    zstyle ':git:info:deleted' format ' ✖'
    zstyle ':git:info:dirty' format ' ⁝'
    zstyle ':git:info:modified' format ' ✱'
    zstyle ':git:info:position' format '%p'
    zstyle ':git:info:renamed' format ' ➙'
    zstyle ':git:info:stashed' format ' S'
    zstyle ':git:info:unmerged' format ' ═'
    zstyle ':git:info:untracked' format ' ?'
    zstyle ':git:info:keys' format \
        'ref' '$(coalesce "%b" "%p" "%c")' \
        'status' '%s%D%A%B%S%a%d%m%r%U%u'

    # Define prompts.
    PROMPT='%F{blue}[%F{green}%D{%H:%M:%S}%F{blue}]%f${(e)$(prompt_build_prompt)}
 ${editor_info[keymap]} '
    # In PROMPT until we find an *easy* solution to put it on the right of PROMPT
    # RPROMPT='%F{blue}[%F{green}%D{%H:%M:%S}%F{blue}]%f'
    SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '
}

# needed to evaluate functions inside prompt strings
setopt promptsubst

prompt_setup "$@"
