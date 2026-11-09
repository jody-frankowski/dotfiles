# -*- mode: sh -*-

bak () {
    local ts=$(date +%Y-%m-%dT%H%M%S%z)

    for arg in "$@"; do
        # Removes trailing slash and protects against names containing `:` which may trip up rsync
        # remote copy detection
        src="$(realpath ${arg})"
        dst="${src}-${ts}.bak"
        [[ -d $src ]] && src="$src/"
        rsync -a -f '- node_modules' -f '- .venv' "${src}" "${dst}"
    done
}

if _onmacos; then
brew () {(
    export HOMEBREW_NO_ENV_HINTS=1          # Disable env vars hints
    export HOMEBREW_NO_INSTALL_CLEANUP=1    # Disable automatic formulae cleanup
    export HOMEBREW_NO_UPGRADE_QUIT_CASKS=1 # Disable upgraded casks restart

    case $1 in
        i) shift; brew install "$@"; rehash; return;;
        s) shift; brew search  "$@"; return;;
    esac
    if [[ $1 == up ]]; then
        brew upgrade
        return
    fi
    command brew "$@"
    rehash
)}
fi

# This will shadow the `col` binary
col () {
    # print columns 1 2 3 ... n
    # "${^@}" is "$@" with RC_EXPAND_PARAM turned off
    awk "{ print ${(j:,:):-\$${^@}} }" # Turns into `awk { print $1,$2 }`
}

capitalize () {
    for arg in "$@"; do
        mv "${arg}" "${(C)arg}"
    done
}

clean-mv () {
    for file in "$@" ; do
        dir=$(dirname -z "$file" | head -c -1)
        new="$(basename $file | head -c -1 | tr '_' '-' | tr -cs '[:alnum:]-.' '-' | tr '[:upper:]' '[:lower:]')"
        \mv "$file" "$dir"/"$new"
    done
}

clifu () {
    curl -s "https://www.commandlinefu.com/commands/matching/$1/`echo -n $1 | base64`/plaintext" | less
}

curlg () {
    curl --continue-at - \
         --glob-off \
         --location \
         --no-clobber \
         --parallel \
         --remote-name-all \
         --remote-time \
         --retry 5 $@
}
curlh () {
    curl -s -v -o /dev/null $@
}
curlt () {
    curl -o /dev/null -s -w @- "$@" <<EOF
namelookup:    %{time_namelookup}s\n
connect:       %{time_connect}s\n
appconnect:    %{time_appconnect}s\n
pretransfer:   %{time_pretransfer}s\n
redirect:      %{time_redirect}s\n
starttransfer: %{time_starttransfer}s\n
------------------------\n
total:         %{time_total}s\n
EOF
}

date-unix () {
    date +%s
}
date-unix-to-real () {
    if (( $# != 1 )); then
        echo "Usage: $0 UNIX_TIMESTAMP"
        return 1
    fi
    date -ud @$1
}

dbg () {
    # /!\ If the command is part of a conditional (e.g. true || false), the exit value ($?) will be
    # the condition result
    local -r ps4_bash='+ $? \w ${BASH_SOURCE##*/}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}() }\n> '
    local -r ps4_zsh='%D{%H:%M:%S} %(?::%B%F{red}%?%f%b )%~ %1x:%I %-1N():%i%D{%n}> '

    if [[ "$(whence -w "$1")" =~ alias$ || "$(whence -w "$1")" =~ function$ ]] ; then
        (PS4="${ps4_zsh}"; set -x; "$@")
        return
    fi

    script_path="$(which "$1")"
    shell="$(head -n1 "${script_path}" | cut -d! -f2)"

    if [[ "${shell}" == *bash ]] ; then
      export PS4="${ps4_bash}"
    elif [[ "${shell}" == *zsh ]] ; then
      export PS4="${ps4_zsh}"
    fi

    "${shell}" -x "${script_path}" "${@:2}"

    unset PS4
}
_dbg () { shift words; (( CURRENT-- )); _normal -P }; compdef _dbg dbg

d64 () {
    if [[ $# -eq 0 ]]; then
        base64 --decode
    else
        printf '%s' $1 | base64 --decode
    fi
}
e64 () {
    if [[ $# -eq 0 ]]; then
        base64
    else
        printf '%s' $1 | base64
    fi
}

diff () {
    # Defined as a function instead of an alias becasue otherwise the completion will keep
    # suggesting options instead of files
    command diff --color -u "$@"
}

dig () {
    # Can be called with an URL (e.g. https://www.domain.tld/*) from which the domain to query will
    # be extracted (e.g. www.domain.tld)
    # Removes https?:// prefix & /* suffix
    command dig ${${@#*://}%%/*}
}

encode-flac () {
    emulate -L zsh
    local -a opt_output opt_strip
    zparseopts -D -E -F -- {o,-output}:=opt_output {s,-strip}=opt_strip || return 1

    if (( $# != 1 )); then
        print -ru2 "Usage: $0 INPUT [-o OUTPUT] [-s|--strip]"
        return 1
    fi
    local input=$1
    [[ -f $input ]] || { print -ru2 "$0: no such file: $input"; return 1 }

    local output=${opt_output[-1]:-${input:r}.flac}
    local tmp="${output:h}/.${output:t:r}.$$.flac"
    local tmp2="${tmp:r}.stripped.flac"

    {
        flac --best --verify --exhaustive-model-search --qlp-coeff-precision-search \
             --force -o "$tmp" "$input" || return 1

        if (( $#opt_strip )); then
            ffmpeg -nostdin -loglevel error -y -i "$tmp" -map 0:a -c copy \
                   -map_metadata -1 -map_chapters -1 -fflags +bitexact \
                   "$tmp2" || return 1
            metaflac --add-seekpoint=10s "$tmp2" || return 1
            mv -f -- "$tmp2" "$output"
        else
            mv -f -- "$tmp" "$output"
        fi
    } always {
        rm -f -- "$tmp" "$tmp2"
    }
}
encode-opus () {
    emulate -L zsh
    local -a opt_output opt_strip
    zparseopts -D -E -F -- {o,-output}:=opt_output {s,-strip}=opt_strip || return 1

    if (( $# != 1 )); then
        print -ru2 "Usage: $0 INPUT [-o OUTPUT] [-s|--strip]"
        return 1
    fi
    local input=$1
    [[ -f $input ]] || { print -ru2 "$0: no such file: $input"; return 1 }

    local output=${opt_output[-1]:-${input:r}.opus}
    local tmp="${output:h}/.${output:t:r}.$$.opus"
    local tmp2="${tmp:r}.stripped.opus"

    # Channel count of the first audio stream (ffprobe ships with ffmpeg)
    local ch
    ch=$(ffprobe -v error -select_streams a:0 -show_entries stream=channels \
                 -of csv=p=0 -i "$input") || return 1
    [[ $ch == <1-> ]] || { print -ru2 "$0: no audio stream in: $input"; return 1 }
    # Mapping family 1 supports at most 8 channels; aformat below downmixes larger layouts to 7.1
    (( ch > 8 )) && ch=8

    # Family 0 for mono/stereo (as opusenc does), family 1 for surround
    local family=$(( ch <= 2 ? 0 : 1 ))

    # Bitrate: 96k/channel up to stereo; beyond that 64k per extra
    # full-range channel and 16k for the LFE (5.1, 6.1, 7.1 have one)
    local -i lfe=$(( ch >= 6 ))
    local -i full=$(( ch - lfe ))
    local -i kbps
    if (( ch <= 2 )); then
        kbps=$(( ch * 96 ))
    else
        kbps=$(( 192 + (full - 2) * 64 + lfe * 16 ))
    fi

    # https://wiki.xiph.org/Opus_Recommended_Settings
    local -a enc_args=(
        -c:a libopus -b:a ${kbps}k -vbr on -compression_level 10
        -frame_duration 60 -application audio -mapping_family $family
    )

    # Resample to 48 kHz with swresample, feed float samples, and normalize the
    # channel layout to one Opus supports (e.g. 5.1(side) -> 5.1)
    local filters='aresample=48000:resampler=swr:filter_size=64,aformat=sample_fmts=flt:channel_layouts=mono|stereo|3.0|quad|5.0|5.1|6.1|7.1'

    local -a meta_args
    if (( $#opt_strip )); then
        meta_args=( -map_metadata -1 -map_chapters -1 )
    else
        # Keep global tags and chapters; drop per-stream container tags
        # (e.g. mkvmerge's BPS/DURATION/NUMBER_OF_* statistics)
        meta_args=( -map_metadata 0 -map_metadata:s -1 )
    fi

    {
        ffmpeg -nostdin -hide_banner -loglevel error -stats -y -i "$input" \
               -map 0:a:0 $meta_args -af $filters $enc_args \
               "$tmp" || return 1
        if (( $#opt_strip )); then
            # ffmpeg always writes an ENCODER tag when encoding; remux to drop it
            ffmpeg -nostdin -loglevel error -y -i "$tmp" -map 0:a -c copy \
                   -map_metadata -1 -map_chapters -1 -fflags +bitexact \
                   "$tmp2" || return 1
            mv -f -- "$tmp2" "$output"
        else
            mv -f -- "$tmp" "$output"
        fi
    } always {
        rm -f -- "$tmp" "$tmp2"
    }
}
# Usage: _encode-audio-dir NAME ENCODER_FN EXT [args...]
_encode-audio-dir () {
    emulate -L zsh
    local name=$1 encoder=$2 ext=$3
    shift 3

    local -a opt_output opt_strip
    zparseopts -D -E -F -- {o,-output}:=opt_output {s,-strip}=opt_strip || return 1
    if (( $# > 1 )); then
        print -ru2 "Usage: $name [INPUT_DIR] [-o OUTPUT_DIR] [-s|--strip]"
        return 1
    fi

    local input=${1:-.}
    local output=${opt_output[-1]:-$input}
    [[ -d $input ]] || { print -ru2 "$name: not a directory: $input"; return 1 }
    mkdir -p -- "$output" || return 1

    # Writing next to the sources: don't copy non-audio files onto themselves
    local in_place=0
    [[ ${input:A} == ${output:A} ]] && in_place=1

    local file out failed=0
    local -a outs
    for file in "$input"/*(N); do
        if [[ -f $file && ${(L)file:e} == (flac|wav) ]]; then
            out="$output/${file:t:r}.$ext"
            if (( ${outs[(Ie)$out]} )); then
                print -ru2 "$name: skipping $file: $out already written"
                failed=1
                continue
            fi
            if $encoder "$file" $opt_strip -o "$out"; then
                outs+=( "$out" )
            else
                failed=1
            fi
        elif (( ! in_place )); then
            cp -Rv -- "$file" "$output/" || failed=1
        fi
    done

    [[ "$ext" == flac ]] && {
        print -ru2 Before:
        du -ch *.wav | tail -n1
        print -ru2 After:
        du -ch *.flac | tail -n1

        rm -f  *.wav(N)
    }

    [[ "$ext" == opus ]] && {
        print -ru2 Before:
        du -ch *.(flac|wav) | tail -n1
        print -ru2 After:
        du -ch *.opus | tail -n1

        rm -f  *.(flac|wav)(N)
    }

    rm -f  *.(cue|jpg|jpeg|log|m3u|nfo|sfv)(N)

    return $failed
}
encode-flac-dir () { _encode-audio-dir $0 encode-flac flac "$@" }
encode-opus-dir () { _encode-audio-dir $0 encode-opus opus "$@" }
_encode-audio () {
    local ext=${${service#encode-}%-dir}
    case $service in
        *-dir)
            _arguments \
                '(-o --output)'{-o,--output}'[Output directory (default: input directory)]:Output directory:_files -/' \
                '(-s --strip)'{-s,--strip}'[Strip all metadata]' \
                '1::Input directory (default .):_files -/'
            ;;
        *)
            _arguments \
                '(-o --output)'{-o,--output}"[Output file]:Output file:_files -g '*.(#i)${ext}(-.)'" \
                '(-s --strip)'{-s,--strip}'[Strip all metadata]' \
                "1:Input file:_files -g '*.(#i)(wav|flac|aif|aiff)(-.)'"
            ;;
    esac
}
compdef _encode-audio encode-flac encode-flac-dir encode-opus encode-opus-dir

find-dead-symlinks () {
    [[ $1 == -h ]] && { echo "Usage: $0 [DIR] [OPTIONS]" >&2; return 1 }

    local dir=.
    [[ -d "$1" ]] && { dir=$1; shift }

    bfs "$dir" -xtype l "$@"
}

forward-port () {
    local host_and_port
    local remote_port
    if [[ $# -eq 0 ]] ; then
        echo "Usage: $0 [HOST:]PORT [--stop]"
        return 1
    fi
    host_and_port="$1"
    if ! echo "$host_and_port" | grep ':' ; then
        host_and_port="localhost:$host_and_port"
    fi
    if [[ "$2" = "--stop" ]] ; then
        ssh -R :0:"$host_and_port" -O cancel port-forwarder
    else
        if remote_port=$(ssh -g -o GatewayPorts=yes -R :0:"$host_and_port" -O forward port-forwarder) ; then
            echo "Remote port: $remote_port"
            echo "Use 'forward-port $host_and_port --stop' to stop the forwarding."
        else
            return 1
        fi
    fi
    return 0
}

# f/g() Searches hidden files by default
# g()   Searches in binary stdin and on-demand for files with `-BH`/`-BT`
f () {
    local path_to_search=(.)
    local patterns=()
    local options=(--hidden)

    [[ $# -eq 0 || $1 == -h || $1 == --help ]] && {
        echo "Usage: $0 [PATH] PATTERN... [FD_OPTION...]" >&2;
        return 1
    }

    [[ -d $1 ]] && {
        path_to_search=()
        while [[ -d $1 ]] { path_to_search+=(--search-path $1); shift }
    }

    while [[ $# -gt 0 && $1 != -* ]]; do
        patterns+=(--and "$1")
        shift
    done
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Custom flags
            -II) options+=(--ignore) ;;
            -IN) options+=(--no-ignore) ;;
            -HH) options+=(--hidden) ;;
            -HN) options+=(--no-hidden) ;;
            # Normal flags
            *) options+=("$1") ;;
        esac
        shift
    done

    fd $path_to_search $patterns $options
}
g () {
    local ug_bin=ugrep
    local input=(.)
    local patterns=()
    local options=(--decompress)
    # -j can't override -i, so we inject only the required one at the end
    # https://github.com/Genivia/ugrep/issues/453
    local option_case="-i"

    usage () { echo "Usage: g [PATH] PATTERN... [UG_OPTION...]" >&2 }

    [[ $# -eq 0 || $1 == -h || $1 == --help ]] && { usage; return 1 }

    if [[ ! -t 0 ]]; then
        input=(-)
    elif [[ -e $1 ]]; then
        input=()
        while [[ -e $1 ]] { input+=($1); shift }
    fi
    [[ "${input}" == - ]] &&
        options+=(--binary-files=with-hex)
    [[ "${input[1]}" != - ]] &&
        options+=(
        --binary-files=without-match
        --dereference-recursive
        --heading
        --hidden
        --ignore-files=~/.config/git/ignore
        --line-number
    )

    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Custom flags
            -BH) options+=(--binary-files=with-hex) ;;
            -BI) options+=(--binary-files=without-match) ;;
            -BT) options+=(--binary-files=text) ;;
            -FI) options+=(--ignore-files=~/.config/git/ignore) ;;
            -FN) options+=(--no-ignore-files) ;;
            -HH) options+=(--hidden) ;;
            -HN) options+=(--no-hidden) ;; # Undocumented, but it works
            -+) ug_bin+=+ ;;
            -i|-j) option_case="$1" ;;
            # Normal flags
            -*) options+=("$1") ;;
            # Regex
            *\**|*+*|*\[*\]*|*\|*|*(*)*) patterns+=("$1") ;;
            # Fixed-String
            *) patterns+=("\"$1\"") ;;
        esac
        shift
    done

    ! (( ${#patterns} )) && { usage; return 1 }

    options+=("${option_case}")

    $ug_bin $options -% "${patterns[*]}" -- $input
}
_f() {
    _files && return 0

    local -a custom_opts=(
        '-HH:Search hidden files'
        '-II:Search ignored files'
    )
    _describe -t custom-options 'wrapper options' custom_opts

    local service=fd
    _fd "$@"
}
_g() {
    _files && return 0

    local -a custom_opts=(
        '-+:Use ugrep+'
        '-HH:Search hidden files'
        '-II:Search ignored files'
    )
    _describe -t custom-options 'wrapper options' custom_opts

    local service=ugrep
    _ugrep "$@"
}
compdef _f f
compdef _g g

gcl () {
    # Transform GH/GL https urls in ssh ones
    local url=$1; shift
    if [[ $url == https://github.com/* || $url == https://gitlab.com/* ]]; then
        local url_parts=(${(@s:/:)url})
        url="${url_parts[2]}:${url_parts[3]}/${url_parts[4]}"
    fi

    if git clone --recursive "${url}" "$@"; then
        # cd into the last modified directory. This is simpler than trying to parse git arguments and
        # their order.
        builtin cd "$(\ls -t | head -n1)"
        # Remove the useless default ssh `git@` user and the common `.git` suffix
        sed -Ei 's/git@|\.git//g' .git/config
        # Remove the sample hook scripts
        bfs .git -type f -ipath '.git/hooks/*sample' -delete
        bfs .git -type f -ipath '.git/modules/*/hooks/*sample' -delete
    fi
}
git-open () {
    # Get current branch (returns empty string if in detached HEAD or not a git repo)
    local branch=$(git symbolic-ref --short -q HEAD)
    local remote="origin"

    # If on a feature branch, check for a tracking remote
    if [[ -n "$branch" && "$branch" != (main|master) ]]; then
        local tracking_remote=$(git config "branch.${branch}.remote")
        [[ -n "$tracking_remote" ]] && remote="$tracking_remote"
    fi

    # Get the raw URL for the determined remote
    local raw_url=$(git remote get-url "$remote" 2>/dev/null)
    if [[ -z "$raw_url" ]]; then
        echo "Error: No URL found for remote '$remote'." >&2
        return 1
    fi

    # Normalize SSH (git@host:user/repo.git) and HTTPS URLs into https://host/user/repo
    local base_url="$raw_url"
    base_url="${base_url%.git}"             # Strip trailing .git
    base_url="${base_url#ssh://}"           # Strip ssh:// if present
    base_url="${base_url#http://}"          # Strip http:// if present
    base_url="${base_url#https://}"         # Strip https:// if present
    base_url="${base_url#git@}"             # Strip git@
    base_url="https://${base_url/://}"      # Replace remaining ':' (from SSH) with '/'

    if [[ -n "$branch" && "$branch" != (main|master) ]]; then
        o "${base_url}/tree/${branch}"
    else
        o "$base_url"
    fi
}
git-pull-r () {
    bfs . -type d -iname '\.git' -printf '%h\n' -execdir git pull \;
}
git-project () {
    local -a roots
    roots=("${(@f)$(git rev-parse --show-superproject-working-tree --show-toplevel 2>/dev/null)}") || return 1
    print -r -- "$roots[1]"
}
git-top-print () {
    local dir=$PWD top=""

    while [[ $dir != / ]]; do
        [[ -e $dir/.git ]] && top=$dir
        dir=${dir:h}
    done

    [[ -n $top ]] && { print -r -- "$top"; return 0 }
    return 1
}
git-top () {
    local top
    top=$(git-top-print) && cd -- "$top"
}

gen-passphrase () {
    [[ $1 == -h ]] && { echo "Usage: $0 [--no-clipboard] [DICTFILE]" >&2; return 1 }

    local use_clipboard=true
    [[ "$1" == --no-clipboard ]] && { use_clipboard=false; shift }
    local dict=words
    [[ -n "$1" ]] && { dict="$1" }
    local dict_file="/usr/share/dict/${dict}"
    [[ ! -f "${dict_file}" ]] && { echo "Error: ${dict_file} doesn't exist!" >&2; return 1 }

    passphrase="$(shuf -n4 "${dict_file}" | tr '\n' ' ' | head -c-1)"
    if [[ "${use_clipboard}" == true ]]; then
        clipboard "${passphrase}" && echo Passphrase copied to clipboard
    else
        echo $passphrase
    fi
}

gen-password () {
    [[ $1 == -h ]] && { echo "Usage: $0 [--no-clipboard] [LENGTH]" >&2; return 1 }

    local use_clipboard=true
    [[ "$1" == --no-clipboard ]] && { use_clipboard=false; shift }
    local length=16
    [[ -n "$1" ]] && { length="$1" }

    password="$(dd if=/dev/urandom bs=1 count=$((length * 2)) 2>/dev/null |
                   base64 | head -c "${length}")"
    if [[ "${use_clipboard}" == true ]]; then
        clipboard "${password}" && echo Password copied to clipboard
    else
        echo $password
    fi
}

getdir () {
    [[ $# -eq 0 ]] && { echo "Usage: $0 URL..."; return 1 }

    for url
        wget -r -nd -np -N -P "$(basename ${url})" "${url}"
}

getip () {
    curl -4 ip.me 2>/dev/null || curl -4 ifconfig.co
    curl -6 ip.me 2>/dev/null || curl -6 ifconfig.co
}

_git-branch-current () {
    local ref="$(command git symbolic-ref HEAD 2> /dev/null)"

    if [[ -n "$ref" ]]; then
        print "${ref#refs/heads/}"
        return 0
    else
        return 1
    fi
}

git-browse () {
    if ! git rev-parse --is-inside-work-tree &> /dev/null ; then
        print "$0: not a repository work tree: $PWD" >&2
        return 1
    fi

    local remotes remote references reference file url

    remote="${1:-origin}"
    remotes=($(command git config --get-regexp 'remote.*.url' | cut -d. -f2))

    if (( $remotes[(i)$remote] == $#remotes + 1 )); then
        print "$0: remote not found: $remote" >&2
        return 1
    fi

    url=$(
        command git config --get "remote.${remote}.url" \
        | sed -En "s/(git|https?)(@|:\/\/)github.com(:|\/)(.+)\/(.+).git/https:\/\/github.com\/\4\/\5/p"
       )

    reference="${${2:-$(_git-branch-current)}:-HEAD}"
    references=(
        HEAD
        ${$(command git ls-remote --heads --tags "$remote" | awk '{print $2}')##refs/(heads|tags)/}
    )

    if (( $references[(i)$reference] == $#references + 1 )); then
        print "$0: branch or tag not found: $reference" >&2
        return 1
    fi

    if [[ "$reference" == 'HEAD' ]]; then
        reference="$(command git rev-parse HEAD 2> /dev/null)"
    fi

    file="$3"

    if [[ -n "$url" ]]; then
        url="${url}/tree/${reference}/${file}"
        xdg-open "$url"
    else
        print "$0: not a Git repository or remote not set" >&2
        return 1
    fi
}

compdef _git git-clone-multiple-remotes=git-clone
git-clone-multiple-remotes () {
(
    set -e

    usage () {
        echo "Usage: $0 [GIT_OPTIONS --] REPO_NAME [DEST]"
        echo -n "Clone a repo from the first remote set in \$(git config remotes.list) and set its "
        echo "push origin to all of the others too"
        echo "Example config:"
        echo "[remotes]"
        echo "    list = \"git@github.com:username git@gitlab.com:username\""
    }
    if [[ $# -lt 1 ]] || [[ "$1" == -h ]] || ; then
        usage
        return 1
    fi
    if [[ -z "$(git config remotes.list)" ]] ; then
        usage
        echo "\nError: Set remotes.list in git config first"
        return 1
    fi

    local args=()
    if [[ "$*" == *" -- "* ]] || [[ "$1" == -- ]]; then
        for arg in "$@" ; do
            shift
            if [[ "$arg" == "--" ]] ; then
                break
            fi
            args+=("$arg")
        done
    fi

    local remotes=($(git config remotes.list))

    if [[ -z "$2" ]] ; then
        git clone "${args[@]}" ${remotes[1]}/"$1"
        cd "$1"
    else
        git clone "${args[@]}" ${remotes[1]}/"$1" "$2"
        cd "$2"
    fi

    for remote in ${remotes[@]} ; do
        git remote set-url --add --push origin "${remote}"/"$1"
    done
)
    if [[ $? -ne 0 ]] ; then
        return $?
    fi

    if [[ "$*" == *" -- "* ]] || [[ "$1" == -- ]]; then
        for arg in "$@" ; do
            shift
            if [[ "$arg" == "--" ]] ; then
                break
            fi
        done
    fi

    if [[ -z "$2" ]] ; then
        cd "$1"
    else
        cd "$2"
    fi
}

hash () {
    local cmd=xxh3sum
    if [[ "$#" -ge 1 ]]; then
        "${cmd}" "$@" | sort -k2
        return
    fi

    bfs . -type f -print0 | xargs -0 "${cmd}" | sort -k2
}
compdef _files hash

k () {
    local cmd=()

    while (( $# )); do
        case "$1" in
            -c) cmd+=(--context "$2") ; shift 2; continue ;;
            a)  cmd+=(apply)          ; shift ; break ;;
            d)  cmd+=(describe)       ; shift ; break ;;
            e)  cmd+=(edit)           ; shift ; break ;;
            g)  cmd+=(get)            ; shift ; break ;;
            l)  cmd+=(logs)           ; shift ; break ;;
            pf) cmd+=(port-forward)   ; shift ; break ;;
            rm) cmd+=(delete)         ; shift ; break ;;
            sh) cmd+=(exec -it)       ; shift
                # Allow specifying a custom command with `k sh ... -- CMD ARGS...`
                (( ${@[(I)--]} )) && break
                set -- "$@" -- bash; break
        esac
        cmd+=("$1"); shift
    done

    KUBECTL_EXTERNAL_DIFF="diff --color=always -N -U 15" \
        kubectl "${cmd[@]}" "$@"
}
_k () {
    words[1]=kubectl

    local subcmd_idx=0
    local arg=2
    while (( arg <= CURRENT )); do
        case "$words[$arg]" in
            -c) words[$arg]=--context    ; (( arg += 2 ));  continue ;;
            a)  words[$arg]=apply        ; subcmd_idx=$arg; break ;;
            d)  words[$arg]=describe     ; subcmd_idx=$arg; break ;;
            e)  words[$arg]=edit         ; subcmd_idx=$arg; break ;;
            g)  words[$arg]=get          ; subcmd_idx=$arg; break ;;
            l)  words[$arg]=logs         ; subcmd_idx=$arg; break ;;
            pf) words[$arg]=port-forward ; subcmd_idx=$arg; break ;;
            rm) words[$arg]=delete       ; subcmd_idx=$arg; break ;;
            sh) words[$arg]=exec         ; subcmd_idx=$arg; break ;;
        esac
        (( arg++ ))
    done

    # If the word currently being completed starts with "dep" (e.g. `k g dep<TAB>`),
    # rewrite both `words[CURRENT]` and `PREFIX` so Zsh replaces "dep" on the
    # command line with "deploy/..."
    if [[ $PREFIX == dep ]]; then
        words[CURRENT]="deploy/${words[CURRENT]#dep}"
        PREFIX="deploy/${PREFIX#dep}"
    fi

    _kubectl
}
compdef _k k

loc () {
    if [[ $# -le 0 ]]; then
        echo Usage: loc KEYWORD...  Search for paths that match the keywords
        return 1
    fi

    if _onmacos; then
        # /!\ mdfind won't match symlinks
        local query="kMDItemFSName == '*$1*'cdw"
        for arg in "${@[@]:2}"
            query="${query} && kMDItemFSName == '*${arg}*'cdw"

        mdfind $query

        return
    fi

    to_search=$(echo $* | sed "s/ /*/g")
    locate -i -e "*${to_search}*"
}

if _onmacos; then
mac-plist-convert () {
    if [[ $# -ne 2 || ! $2 =~ "binary1|json|xml1" ]]; then
        echo "USAGE: $0 PLIST_FILE binary1|json|xml1" >&2
        return 1
    fi
    plutil -convert "$2" "$1"
}

mac-plist-print () {
    plutil -p "$1"
}

mac-plist-services-list () {
    bfs ~/Library/LaunchAgents \
        /Library/Launch{Agents,Daemons} \
        /System/Library/Launch{Agents,Daemons} \
        -type f -printf "%T@ %Tc %p\n" COL {2..9} | sort -n
}
fi

# ── manned: read a manned.org manpage for a specific distro/version ──────────
# Usage: manned [-o] MANPAGE DISTRO VERSION [SECTION]
#   SECTION defaults to 1
#   -o      Open the manned.org web page instead of rendering in the terminal
#
#   e.g. manned ls debian 12
#        manned open ubuntu noble 2
#        manned -o systemctl centos 9

# key: "<distro> <version>"   value: "<manned system id>:<description>"
typeset -gA _manned_systems=(
    'debian 13'    'debian-trixie:trixie'
    'debian 12'    'debian-bookworm:bookworm'
    'debian 11'    'debian-bullseye:bullseye'
    'debian 10'    'debian-buster:buster'
    'ubuntu 26.04' 'ubuntu-resolute:resolute (LTS)'
    'ubuntu 24.04' 'ubuntu-noble:noble (LTS)'
    'ubuntu 22.04' 'ubuntu-jammy:jammy (LTS)'
    'ubuntu 20.04' 'ubuntu-focal:focal (LTS)'
    'centos 10'    'centos-10:Stream 10'
    'centos 9'     'centos-9:Stream 9'
    'centos 8'     'centos-8:8 / Stream 8'
    'centos 7'     'centos-7:7'
)
typeset -ga _manned_distros=(centos debian ubuntu)
# Set $reply to the known versions of distro $1, newest first.
_manned_versions() {
    local -a vs=(${${(M)${(k)_manned_systems}:#$1 *}#$1 })
    reply=(${(On)vs})
}
manned() {
    emulate -L zsh

    local -a opt_open opt_help reply
    zparseopts -D -E -F -- o=opt_open h=opt_help -help=opt_help || return 2

    if (( $#opt_help || $# < 3 || $# > 4 )); then
        print -u2 "Usage: $0 [-o] MANPAGE DISTRO VERSION [SECTION]"
        return 2
    fi

    local page=$1 distro=${2:l} version=${3:l} section=${4:-1}
    local entry=${_manned_systems[$distro $version]} v d

    # Fall back to matching a codename (e.g. "noble", "bookworm")
    if [[ -z $entry ]]; then
        _manned_versions $distro
        for v in $reply; do
            [[ ${${_manned_systems[$distro $v]}#*:} == ${version}(| *) ]] \
                && { entry=${_manned_systems[$distro $v]}; break }
        done
    fi

    if [[ -z $entry ]]; then
        print -u2 "$0: unknown system '$distro $version'. Known:"
        for d in $_manned_distros; do
            _manned_versions $d
            print -u2 -- "  $d: ${(j:, :)reply}"
        done
        return 1
    fi

    if [[ $section != [1-9]* ]]; then
        print -u2 "$0: invalid section '$section'"
        return 2
    fi

    local target="${entry%%:*}/${page}.${section}"

    # Web mode
    if (( $#opt_open )); then
        local url="https://manned.org/man/$target"
        print -r -- $url
        ${MANNED_OPENER:-open} $url
        return
    fi

    # Terminal mode
    local raw_url="https://manned.org/raw/$target" src
    if ! src=$(curl -fsSL -- "$raw_url") || [[ -z $src ]]; then
        print -u2 "$0: not found: $raw_url"
        return 1
    fi

    if (( $+commands[mandoc] )); then
        print -r -- "$src" | mandoc -a -man
    elif (( $+commands[groff] )); then
        print -r -- "$src" | groff -man -Tutf8 | ${PAGER:-less -R}
    else
        print -u2 "$0: need mandoc or groff to render"
        return 1
    fi
}
_manned() {
    local curcontext=$curcontext state state_descr line ret=1
    typeset -A opt_args

    _arguments -C -s \
               '-o[Open the manned.org web page instead]' \
               '(- *)'{-h,--help}'[Show usage]' \
               '1:man page:_command_names -e' \
               "2:distro:($_manned_distros)" \
               '3:version:->version' \
               '4::section (default 1):((
        1\:"User commands"
        2\:"System calls"
        3\:"Library functions"
        4\:"Special files"
        5\:"File formats"
        6\:"Games"
        7\:"Miscellanea"
        8\:"System administration"
        9\:"Kernel routines"))' && ret=0

    case $state in
        version)
            local -a vers reply
            local v distro=${line[2]:l}
            _manned_versions $distro
            for v in $reply; do
                vers+=("$v:${${_manned_systems[$distro $v]}#*:}")
            done
            # -V: unsorted group, keeps our newest-first order
            _describe -V -t versions 'version' vers && ret=0
            ;;
    esac

    return ret
}
compdef _manned manned

mkcd () {
    [[ -n "$1"  ]] && mkdir -p "$1" && builtin cd "$1"
}

mount () {
    if [ "$#" -eq 0 ] ; then
        command mount | column -t
    else
        command mount $@
    fi
}

mv-merge () {
    if (( $# < 2 )); then
        echo Usage: mv-merge DIR... DST
        echo If DIR exists in DST, the two directories will be merged
        echo Example:
        cat <<- EOF
			$ tree
			.
			├── DIR
			│   └── A
			└── DST
			    └── DIR
			        └── B
			$ mv-merge DIR DST
			$ tree
			.
			└── DST
			    └── DIR
			        ├── A
			        └── B
		EOF
        return 1
    fi

    local dst="${@[-1]}"
    local srcs=("${@[0,-2]}")

    rsync -ai --remove-source-files --link-dest="$(realpath "${dst}")" "${srcs[@]}" "${dst}"

    find "${srcs[@]}" -type d -empty -delete

    error=false
    for src in "$src[@]"; do
        if [[ -d "${src}" ]]; then
            error=true
            echo "${src} couldn't be removed!" >&2
        fi
    done
    if [[ "${error}" == true ]]; then
        return 1
    fi
}

pacman-list-disowned () {
    # Lists Pacman disowned files
    local tmp="${TMPDIR:-/tmp}/pacman-disowned-$UID-$$"
    local db="$tmp/db"
    local fs="$tmp/fs"

    mkdir "$tmp"
    trap  'rm -rf "$tmp"' EXIT

    pacman --quiet --query --list | sort --unique > "$db"

    find /bin /etc /lib /sbin /usr \
        ! -name lost+found \
        \( -type d -printf '%p/\n' -o -print \) | sort > "$fs"

    comm -23 "$fs" "$db"
}

pacman-list-explicit () {
    # Lists explicitly installed Pacman packages
    pacman --query --explicit --info \
      | awk '
          BEGIN {
            FS=":"
          }
          /^Name/ {
            print $2
          }
          /^Description/ {
            print $2
          }
        '
}

pacr () {
    sudo pacman -Rs "$@"
    rehash
}

pacs () {
    sudo pacman -S "$@"
    rehash
}

ping-gw () {
    if _onmacos; then
        gw="$(netstat -nr G default G en0 COL 2)"
    else
        gw="$(route -n G 'UG\b' COL 2)"
    fi

    ping "${gw}"
}

if _onmacos; then
    plutil-to-json () {
        if [[ $# -lt 1 ]]; then
            echo "Usage: $0 PLIST_FILE..." >&2
            return 1
        fi

        for f in "$@"; do
            plutil -convert json "$f"
        done
    }
fi

ps () {
    command ps "$@" | grcat conf.ps
}
psg () {
    # Capture the output before searching to avoid capturing the filtering cmd
    local -r out=$(ps auxww)
    g "$@" --color=never <<<$out
}
pst () {
    pstree -w "$@" | grcat conf.ps
}

pssh () {
    # Takes a list of host as arguments
    # For each host:
    #    Split the tmux window
    #    Start an ssh session with the host
    #    If ssh fails, keep an interactive zsh session in the pane in order to
    #        see the error
    # Detach the "controlling" pane in order to set the window layout without
    # interfering

    window=$(tmux display-message -p '#I')

    if [[ $# -eq 2 ]] ; then
        layout="even-horizontal"
    else
        layout="tiled"
    fi

    for host in $* ; do
        tmux split-window "zsh -i -c \"ssh ${host} || zsh -i\""
        # HACK we can't split horizontally too many times because tmux would
        # complain about panes being too small.
        # We avoid this by setting the layout after each split.
        tmux select-layout -t :$window $layout
    done

    tmux set-window-option synchronize-panes on

    # extract the controlling pane so we can change the layout
    # https://github.com/tmux/tmux/issues/302
    pane=$(tmux break-pane -P -s 0)
    tmux select-layout -t :$window $layout
    # kill the controlling pane (don't put any code after this line, because
    # it won't be executed)
    tmux kill-pane -t ${pane}
}

_pssh () {
    _alternative 'hosts:Hosts:_hosts'
}
compdef _pssh pssh

psshfs () {
    if [[ ! -d /mnt/me ]] ; then
        echo "Error: /mnt/me doesn't exist."
        return 1
    fi

    # clean up old directories
    rmdir /mnt/me/* 2> /dev/null

    if [[ "${@: -1}" == *"/"* ]] ; then
        dir="${@: -1}"
    else
        dir="/data/log"
    fi

    for host in "$@" ; do
        if [[ "${host}" == *"/"* ]] ; then
            break
        fi

        mkdir /mnt/me/"${host}"
        sshfs "${host}":"${dir}" /mnt/me/"${host}"
    done
}
compdef psshfs="sshfs"

ptr () {
    drill -x `drill $1 | grep $1 | awk '{print $5}'`
}
compdef ptr="host"

rdiff () {
    tmp_name=$(echo "${1}" | tr ":/" "-")-${RANDOM}
    first_tmp=/tmp/$tmp_name
    scp -q "$1" "$first_tmp"

    tmp_name=$(echo "${2}" | tr ":/" "-")-${RANDOM}
    second_tmp=/tmp/$tmp_name
    scp -q "$2" "$second_tmp"

    vimdiff "$first_tmp" "$second_tmp"

    scp -q "$first_tmp" "$1"
    scp -q "$second_tmp" "$2"
}
compdef rdiff="scp"

rvim () {
    tmp_name=$RANDOM
    scp -q "$@" "/tmp/$tmp_name"
    vim /tmp/$tmp_name
    scp -q /tmp/$tmp_name "$@"
}
compdef rvim="scp"

_onlinux && (( $+commands[systemctl] )) && {
    sc() {
        emulate -L zsh
        local -a ro_cmds=(
            cat help get-default is-active is-enabled is-failed
            is-system-running list-dependencies list-jobs list-sockets
            list-timers list-unit-files list-units show show-environment status
        )

        local cmd i=1
        # Find the subcommand, skipping options (and values of options that take one)
        while (( i <= $# )); do
            case $argv[i] in
                --user)  systemctl "$@"; return ;;
                -[tpPsnoHM]|--type|--property|--state|--lines|--output|--host|--machine|--root)
                         (( i += 2 )); continue ;;
                -*)      ;;
                *)       cmd=$argv[i]; break ;;
            esac
            (( i++ ))
        done

        if (( EUID == 0 )) || [[ -z $cmd ]] || (( ${ro_cmds[(Ie)$cmd]} )); then
            systemctl "$@"
        else
            sudo systemctl "$@"
        fi
    }
    compdef sc=systemctl

    alias jc='journalctl'
    alias jcu='journalctl --user'
    alias scu='systemctl --user'
}

s () {
    # s [SSH_OPTIONS] HOST [COMMAND...]
    # With no COMMAND: upload a bashrc and tmux.conf, then attach to (or create) a tmux session.
    # With COMMAND: run plain ssh.
    emulate -L zsh
    setopt brace_ccl  # {abc} → a b c
    local usage="Usage: $0 [SSH_OPTIONS] HOST [COMMAND...]"
    local -a opts help
    zparseopts -D -F -a opts h=help -help=help \
        {46AaCfGgKkMNnqsTtVvXxYy}+ {BbcDEeFIiJLlmOoPpQRSWw}+: || return

    if (( $#help )); then print -- $usage; return 0
    elif (( ! $# )); then print -u2 -- $usage; return 1
    elif (( $# > 1 )); then ssh "${opts[@]}" "$@"; return  # COMMAND given: plain ssh
    fi

    # Ship the files inside RemoteCommand (one connection, one auth).
    # %n = host as typed, %r = remote user; ssh expands these tokens.
    local rc=/tmp/%r-bashrc conf=/tmp/%r-tmux.conf
    local -a rcfiles=(~/.ssh-bashrc*(N))
    local rc_b64 conf_b64
    rc_b64=$(cat -- $rcfiles </dev/null | base64 | tr -d '\n')
    # Strip features unsupported by older server-side tmux versions.
    conf_b64=$(sed -E \
        -e '/prompt-cursor-colour|menu-style|menu-selected-style/d' \
        -e 's/,fill=.*//' \
        ~/.tmux.conf | base64 | tr -d '\n')

    local remote="umask 077
{ echo _HOST=%n; echo $rc_b64 | base64 -d; } >$rc
echo $conf_b64 | base64 -d | sed 's/#[{]host_short[}]/%n/g' >$conf
echo \"set -g default-command 'bash --rcfile $rc'\" >>$conf
if command -v tmux >/dev/null 2>&1; then tmux -f $conf new -As %r && exit; fi
exec bash --rcfile $rc"

    ssh -t -o RemoteCommand=$remote "${opts[@]}" "$@"
}
compdef s=ssh

scp-r2r () {
    emulate -L zsh
    setopt pipefail extendedglob

    local -a help sudo compress verbose
    zparseopts -D -E -F - \
               {h,-help}=help \
               {s,-sudo}=sudo \
               {z,-compress}=compress \
               {v,-verbose}=verbose || return 1

    if (( $#help || $# != 2 )) || [[ $1 != *?:?* || $2 != *?:?* ]]; then
        print -u2 "Usage: $0 [-s|--sudo] [-z|--compress] [-v|--verbose] <src_host:path> <dst_host:dir>"
        return $(( ! $#help ))
    fi

    local sflag=${sudo:+sudo -n}
    local zflag=${compress:+-z}
    local vflag=${verbose:+-v}

    local src_host=${1%%:*} src_path=${${1#*:}%%/#}
    local dst_host=${2%%:*} dst_path=${2#*:}
    src_path=${src_path:-/}

    ssh -nT -- "$src_host" \
        "$sflag tar --acls --xattrs $zflag -C ${(qq)src_path:h} -cf - -- ${(qq)src_path:t}" |
        ssh -T -- "$dst_host" \
            "$sflag mkdir -p -- ${(qq)dst_path} && $sflag tar --acls --xattrs --same-owner $zflag $vflag -C ${(qq)dst_path} -xpf -"
}
_scp-r2r () {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C -s -S \
               '(- *)'{-h,--help}'[Display help message]' \
               '(-s --sudo)'{-s,--sudo}'[Run remote commands with sudo -n]' \
               '(-z --compress)'{-z,--compress}'[Compress archive stream with gzip (-z)]' \
               '(-v --verbose)'{-v,--verbose}'[Verbose tar extraction]' \
               '1:source (host\:path):->src' \
               '2:destination (host\:dir):->dst' && return 0

    case $state in
        src|dst)
            if compset -P '*:'; then
                local -a slash=(${${(M)state:#dst}:+-/})
                _remote_files $slash -- ssh
            elif compset -P '*@'; then
                _wanted hosts expl 'remote host' _ssh_hosts -qS:
            else
                _alternative \
                    'hosts:remote host:_ssh_hosts -qS:' \
                    'users:user:_users -qS@'
            fi
            ;;
    esac
}
compdef _scp-r2r scp-r2r

share () {
    emulate -L zsh
    setopt err_return pipe_fail no_unset

    local usage="Usage: $0 [--ip=LISTEN_IP] [--port=PORT] [--pass=PASS] [-s|--https] [-v|--verbose] [DIR|FILE...]
Share the specified directories or files (defaults to the current directory)."

    local -A opts
    local -a help verbose https
    zparseopts -D -E -F -A opts - \
        h=help -help=help \
        v=verbose -verbose=verbose \
        s=https -https=https \
        -pass:=opts -ip:=opts -port:=opts || { print -u2 "$usage"; return 1 }

    (( $#help )) && { print -u2 "$usage"; return 0 }
    (( $#verbose )) && setopt xtrace

    local pass="${${opts[--pass]:-}#=}"
    local listen_ip="${${opts[--ip]:-}#=}"
    local port="${${opts[--port]:-}#=}"
    local scheme="http"
    local tls_config=""
    local wget_tls_flag=""

    if (( $#https )); then
        scheme="https"
        wget_tls_flag=" --no-check-certificate"
        tls_config="tls internal {
        on_demand
    }"
    fi

    [[ "${1:-}" == "--" ]] && shift
    local -a to_share=( "${@:A}" )
    (( ${#to_share} == 0 )) && to_share=( "${PWD:A}" )

    for arg in "${to_share[@]}"; do
        [[ -e "$arg" ]] || { print -u2 "Error: '$arg' does not exist."; return 1 }
    done

    # Port selection: use 8080 if free, otherwise pick a random free port
    if [[ -z "$port" ]]; then
        if ! lsof -iTCP:8080 -sTCP:Listen -P -n &>/dev/null; then
            port=8080
        else
            port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
            print -u2 "Port 8080 is in use; using random port: ${port}"
        fi
    fi

    # Generate passphrase if not provided
    if [[ -z "$pass" ]]; then
        if (( $+commands[gen-passphrase] )); then
            pass="$(gen-passphrase --no-clipboard | sed -E "s/ |'//g")"
        else
            pass="$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16 || true)"
        fi
        [[ -n "$pass" ]] || { print -u2 "Error: failed to generate passphrase."; return 1 }
    fi

    local -r shares_base="${HOME}/.local/share/caddy/shares"
    command mkdir -p "$shares_base"
    local -r share_directory_root="$(command mktemp -d "${shares_base}/share.XXXXXX")"

    {
        print > "${share_directory_root}/index.html"
        print "User-agent: Wget\nAllow: /\nUser-agent: *\nDisallow: /" > "${share_directory_root}/robots.txt"
        command mkdir -p "${share_directory_root}/${pass}"

        for arg in "${to_share[@]}"; do
            command ln -s "$arg" "${share_directory_root}/${pass}/"
        done

        local url_path="$pass" trailing_slash="/"
        if (( ${#to_share} == 1 )); then
            url_path="${pass}/${to_share[1]:t}"
            [[ -d "${to_share[1]}" ]] || trailing_slash=""
        fi

        local -r caddyfile="${share_directory_root}/Caddyfile"
        cat <<EOF > "$caddyfile"
{
    admin off
    auto_https off
}
${scheme}://${listen_ip}:${port} {
    ${listen_ip:+bind ${listen_ip}}
    ${tls_config}
    root * "${share_directory_root}"
    file_server browse
    handle_errors {
        @404 expression {err.status_code} == 404
        redir @404 ../ 302
    }
}
EOF

        local cmd="wget -r --np --nH --cut-dirs=1${wget_tls_flag} --reject 'index.html*'"
        print "Pick one of the following:"
        local -a ips=( "${listen_ip:-$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {sub(/\/.*/, "", $2); print $2}')}" )
        for ip in ${(f)ips}; do
            print "${cmd} '${scheme}://${ip}:${port}/${url_path}${trailing_slash}'"
        done
        print

        caddy run --config "$caddyfile" --adapter caddyfile || true
    } always {
        if [[ -n "${share_directory_root:-}" && -d "$share_directory_root" ]]; then
            command find "${share_directory_root}/${pass}" -maxdepth 1 -type l -delete 2>/dev/null || true
            command rmdir "${share_directory_root}/${pass}" 2>/dev/null || true
            command rm -f "${share_directory_root}"/{index.html,robots.txt,Caddyfile} 2>/dev/null || true
            command rmdir "${share_directory_root}" 2>/dev/null || true
        fi
    }
}
_share () {
    local -a ips
    ips=( $(ifconfig 2>/dev/null | awk '/inet / {sub(/\/.*/, "", $2); print $2}') )

    _arguments -s -S \
        '(- *)'{-h,--help}'[Show help message]' \
        '(-v --verbose)'{-v,--verbose}'[Enable xtrace debug logging]' \
        '(-s --https)'{-s,--https}'[Serve over HTTPS using an internal self-signed certificate]' \
        '--ip=[IP address to listen on]:listen IP:('${(j: :)ips}')' \
        '--port=[Port to listen on]:port:(8080 9999 8000 3000)' \
        '--pass=[Custom URL passphrase]:passphrase:' \
        '*:file or directory to share:_files'
}
compdef _share share

rdap () {
    [[ $# -eq 0 ]] && { command rdap; return 1 }

    domain="${1#*://}" # Remove https?://
    domain="${domain%%/*}" # Remove /* suffix
    # TODO Handle ccSLD (e.g. .co.uk)
    domain="${(j/./)${(s/./)domain}[-2,-1]}" # Keep only the second-level domain

    command rdap "${domain}" || command whois "${domain}"
}
whois () {
    echo "Deprecated, call rdap:"
    echo "rdap $1"
    return 1
}

watch () {
    sleep_sec=2
    [[ $1 =~ ^[0-9]*$ ]] && { sleep_sec=$1; shift }

    while true; do
        out=$(unbuffer zsh -i -c "$*")
        clear
        echo $out
        sleep 2
    done
}

xsh () {
    # /!\ XSH expects blank separated ipnput.
    # /!\ XSH won't work with inputs that have unescaped/unquoted quotes or spaces.
    # /!\ Use XSH0 instead.

    # The caller needs to use $1 (quoting isn't required as there is only one parameter) instead of
    # {}. With {} it's xargs' job to insert the parameter, and this can result in a situation where
    # escaping would be required, for example with filenames that includes a `'` or `"`.
    # If we let zsh do that as part of arguments parsing, we keep total control of quoting.
    # The only thing that needs special care is `$` in the arguments. Escape or quote it. Apart from
    # no quoting is needed.
    # Don't forget to pass a single quoted string or escape the `$` if passing in a double quoted
    # one.

    # Example:
    # bfs . -type f -print0 XSH0 ls \$1
    # './abc def'
    # './"'

    # Return 255 so that xargs stops at the first error.
    # The last argument becomes the $0 of the executed command.

    local xargs_flags=()
    if [[ $# -ge 1 && "$1" == "-0" ]]; then
        xargs_flags+=(-0)
        shift
    fi
    # We start an interactive and non-login shell with `-i` in order to use our aliases
    # (~/.zshrc will be sourced, but not ~/.zprofile)
    xargs "${xargs_flags[@]}" -n1 -- \
          zsh -ieuo pipefail -c -- "($*) || (echo $0 failed with: \$@ >&2 && return 255)" "$0"
}
alias -g XSH='| xsh'
alias -g XSH0='| xsh -0'
