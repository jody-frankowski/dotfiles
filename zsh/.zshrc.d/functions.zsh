# -*- mode: sh -*-

bak () {
    # ${@%/} removes trailing slashes
    for arg in "${@%/}" ; do
        cp -a "${arg}" "${arg}-$(date -u +%F%H%M%S).bak"
    done
}

if _onmacos; then
brew () {
    command brew "$@"
    rehash
}
alias brwe=brew
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

curlh () {
    curl -s -v -o /dev/null $@
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

find-dead-symlinks () {
    [[ $1 == -h ]] && { echo "Usage: $0 [DIR] [OPTIONS]" >&2; return 1 }

    local dir=.
    [[ -d "$1" ]] && { dir=$1; shift }

    bfs "$dir" -xtype l "$@"
}

flac-encode () {
    local metadata
    local output
    local tmp=tmp-$RANDOM.flac
    local input="$1"
    shift
    while [[ $# -gt 0 ]] ; do
        arg="$1"

        case $arg in
            -o|--output)
                output="$2"
                shift
                ;;
            -m|--metadata)
                metadata="$2"
                shift
                ;;
        esac
        shift
    done
    if [[ -z "$input" ]] ; then
        echo "Input not set."
        return -1
    fi
    if [[ -z "$output" ]] ; then
        output="${input%.*}.flac"
    fi
    flac --best --verify --exhaustive-model-search --qlp-coeff-precision-search "$input" -o "$tmp"
    if [[ -n "$metadata" ]] ; then
        # ffmpeg -y -i "$input" -map_metadata 0 "${input%.*}.flac"
        ffmpeg -y -i "$metadata" -i "$tmp" -map_metadata 0 -map 1:a:0 -c:a copy "$output"
        rm -f "$tmp"
    else
        mv -f "$tmp" "$output"
    fi
}

flac-encode-dir () {
    local metadata
    local output
    local input="$1"
    shift
    while [[ $# -gt 0 ]] ; do
        arg="$1"

        case $arg in
            -o|--output)
                output="$2"
                shift
                ;;
            -m|--metadata)
                metadata="$2"
                shift
                ;;
        esac
        shift
    done
    if [[ -z "$input" ]] ; then
        echo "Input not set."
        return -1
    fi
    if [[ -z "$output" ]] ; then
        echo "-o is not set."
        return -1
    fi
    mkdir "$output"
    for file in "$input"/* ; do
        filename=$(basename -- "$file")
        extension="${filename##*.}"
        filename="${filename%.*}"
        if [[ "$extension" = "flac" || "$extension" = "wav" ]] ; then
            if [[ -n "$metadata" ]] ; then
                flac-encode "$file" -m "$metadata"/"$filename".* -o "$output"/"$filename".flac
            else
                flac-encode "$file" -o "$output"/"$filename".flac
            fi
        else
            cp -v "$file" "$output"
        fi
    done
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

gcl () {
    if git clone --recursive "$@"; then
        # cd into the last modified directory. This is simpler than trying to parse git arguments and
        # their order.
        cd "$(\ls -t | head -n1)"
        # Remove the useless default ssh `git@` user and the common `.git` suffix
        sed -Ei 's/git@|\.git//g' .git/config
    fi
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

get () {
    [[ $# -eq 0 ]] && { echo "Usage: $0 URL..."; return 1 }

    for url
        curl --continue-at - --location --remote-name --remote-time "${url}"
}

getdir () {
    [[ $# -eq 0 ]] && { echo "Usage: $0 URL..."; return 1 }

    for url
        wget -r -nd -np -N -P "$(basename ${url})" "${url}"
}

getip () {
    curl https://ip.me || dig +short ANY myip.opendns.com @resolver1.opendns.com
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

# cat ~/.zsh/repos/*prezto*/modules/git/...
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
    local cmd=xxhsum
    if [[ "$#" -ge 1 ]]; then
        "${cmd}" "$@" | sort -k2
        return
    fi

    bfs . -type f -print0 | xargs -0 "${cmd}" | sort -k2
}
compdef _files hash

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

_user_commands=(
    cat help is-active is-enabled list-jobs list-unit-files list-units show
    show-environment status
)
sc () {
    if [[ $(id -u) -eq 0 ]] ; then
        systemctl "$@"
        return
    fi

    if (( ${_user_commands[(I)$1]} )) ; then
        systemctl "$@"
    else
        sudo systemctl "$@"
    fi
}
type systemctl > /dev/null && compdef sc="systemctl"

search () {
    if [[ $# -eq 0 ]]; then
        echo Usage: $0 [DIR] PATTERN... >&2
        return 1
    fi

    local dir_to_search="."
    if [[ -d "$1" ]]; then
        dir_to_search="$1"
        shift
    fi

    to_search=$(echo $* | sed "s/ /*/g")
    bfs "${dir_to_search}" -iname "*${to_search}*"
}
alias f=search

share () {
    if [[ $1 = "-h" || $1 = "--help" ]] ; then
        echo "Usage: $0 [--auth[=PASSWORD]] [--expose] [DIR|FILE...]"
        return
    fi

    local auth=false
    local auth_password=""
    local expose=false
    local to_share=()
    while [[ $# -gt 0 ]] ; do
        arg="$1"

        case "$arg" in
            --auth*)
                auth=true
                auth_password="$(echo $1 | cut -s -d= -f2)"
                ;;
            --expose)
                expose=true
                ;;
            *)
                to_share+=("$1")
                ;;
        esac
        shift
    done

    if [[ ${#to_share[@]} -eq 0 ]] ; then
        to_share=(.)
    fi

    local share_directory_root=$(mktemp -d)

    if [[ "${auth}" = true ]] ; then
        # When there is an index.html file, Python doesn't generate a directory
        # listing for the root directory
        # https://docs.python.org/3/library/http.server.html#http.server.SimpleHTTPRequestHandler.do_GET
        touch "${share_directory_root}"/index.html
        if [[ -z "${auth_password}" ]] ; then
            auth_password=$(gen-passphrase --no-clipboard)
        fi
        share_directory="${share_directory_root}"/"${auth_password}"
        mkdir "${share_directory}"
    else
        share_directory="${share_directory_root}"
    fi

    for arg in "${to_share[@]}" ; do
        ln -s "$(realpath ${arg})" "${share_directory}"
    done

    cd "${share_directory_root}" &>/dev/null

    # It really should be a while loop of python trying to listen to the port,
    # but with this way we can easily print the port before running the server,
    # and let the user stop it with a simple C-c
    local port="9999"
    while ss -nlt | awk '{print $4}' | grep ":${port}" > /dev/null ; do
        port="${RANDOM}"
    done

    echo "Pick one of the following:"
    [[ ${expose} == true ]] && echo "Local:"
    for ip in $(ip -o -4 a | awk -F'[ /]+' '$2!~/lo/{print $4}') ; do
        url="http://${ip}:${port}"
        if [[ -n "${auth_password}" ]] ; then
            url="${url}/${auth_password}/"
        fi
        echo wget -r --reject "'"index.html\*"'" "${url}"
    done

    if [[ "${expose}" = true ]] ; then
        if ! local remote_port=$(forward-port "${port}" | head -n1 | awk '{print $3}') ; then
            echo "Failed to expose share."
            return 1
        fi
        echo "Remote:"
        remote_local_ips=$(ssh port-forwarder "ip -o -4 a | awk -F'[ /]+' '\$2!~/lo/{print \$4}'")
        for ip in ${=remote_local_ips} ; do
            url="http://${ip}:${remote_port}"
            if [[ -n "${auth_password}" ]] ; then
                url="${url}/${auth_password}/"
            fi
            echo wget -r --reject "'"index.html\*"'" "${url}"
        done
    fi

    python3 -m http.server "${port}"
    forward-port "${port}" --stop

    # We don't `rm -rf` to be a bit safer
    find "${share_directory}" -maxdepth 1 -type l -delete
    if [[ "${auth}" = true ]] ; then
        rmdir "${share_directory}"
        rm -f "${share_directory_root}/index.html"
    fi
    rmdir "${share_directory_root}"

    cd - &>/dev/null
}

sprunge () {
    if [ -t 0 ]; then
        if [ "$*" ]; then
            if [ -f "$*" ]; then
                echo Uploading the contents of "$*"... >&2
                cat "$*"
            else
                echo Uploading the text: \""$*"\"... >&2
                echo "$*"
            fi | curl -F 'sprunge=<-' http://sprunge.us 2>/dev/null | tee /dev/tty | xsel -ib
        else
            echo "usage:
  $0 filename.txt
  $0 text string
  $0 < filename.txt
  piped_data | $0"
        fi
    else
        echo Using input from a pipe or STDIN redirection... >&2
        curl -F 'sprunge=<-' http://sprunge.us 2>/dev/null  | tee /dev/tty | xsel -ib
    fi
}

sshrc () {
    ssh -o ControlPath=none \
        -o PermitLocalCommand=yes \
        -o LocalCommand="scp -qC ~/.ssh-bashrc %n:/tmp/" \
        -t $@ -- \
        "(tmux new -A -s ssh-\$(whoami) \
               \"tmux set -s default-command 'bash --rcfile /tmp/.ssh-bashrc'
                 bash --rcfile /tmp/.ssh-bashrc\") \
         || bash --rcfile /tmp/.ssh-bashrc"
}
alias s=sshrc
compdef s="ssh"

# watch () {
#     watch "$@"
# }

rdap () {
    [[ $# -eq 0 ]] && { command rdap; return 1 }

    domain="${1#*://}" # Remove https?://
    domain="${domain%%/*}" # Remove /* suffix
    # TODO Handle ccSLD (e.g. .co.uk)
    domain="${(j/./)${(s/./)domain}[-2,-1]}" # Keep only the second-level domain

    command rdap -j "${domain}" || command whois "${domain}"
}
whois () {
    echo "Deprecated, call rdap:"
    echo "rdap $1"
    return 1
}

ugg () {
    local file_or_dir=
    local options=()
    while [[ $# -gt 0 ]] ; do
        case "$1" in
            -*) options+=("$1"); shift;;
            *) file_or_dir="$1"; shift; break;;
        esac
    done
    if [[ -z "${file_or_dir}" || $# -gt 1 ]]; then
        echo "Inverted ug: $0 [UG_OPTION...] PATH... PATTERN..." >&2
        return 1
    fi

    ug "${options[@]}" "--regexp=$^@" "${file_or_dir}"
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
