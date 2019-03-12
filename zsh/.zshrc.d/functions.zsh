# -*- mode: sh -*-

bak () {
    for arg in "$@" ; do
        newname="$arg-$(date -Iseconds).bak";
        cp -a "$arg" "$newname";
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

con-by-state () {
    ss -nat | tail -n +2 | awk '{print $1}'| sort | uniq -c | sort -rn
}

con-by-ip () {
    ss -ntu | tail -n +2 | awk '{print $6}' | cut -d: -f1 | sort | uniq -c | sort -n
}

curlh () {
    curl -s -v -o /dev/null $@
}

# https://github.com/robbyrussell/oh-my-zsh/blob/master/plugins/encode64/encode64.plugin.zsh
encode64() {
    if [[ $# -eq 0 ]]; then
        cat | base64
    else
        printf '%s' $1 | base64
    fi
}

decode64() {
    if [[ $# -eq 0 ]]; then
        cat | base64 --decode
    else
        printf '%s' $1 | base64 --decode
    fi
}
alias d64=decode64
alias e64=encode64

easy-grep () {
    to_search=$(echo $* | sed "s/ /.*/g")
    rg "${to_search}"
}
alias -g G='| easy-grep'

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

gcl () {
    if git clone --recursive "$@" ; then
        # cd into a given directory or into the one git created
        if [[ -d "$2" ]] ; then
            cd "$2"
        else
            cd "$(basename ${@:-1} .git)"
        fi
    fi
}

_clip() {
    # Shamelessly stolen and adapted from http://www.passwordstore.org/
    # This base64 business is because bash/zsh cannot store binary data in a shell
    # variable. Specifically, it cannot store nulls nor (non-trivally) store
    # trailing new lines.

    local sleep_argv0="$1 sleep on display $DISPLAY"

    # Kill concurrent _clip sleep. Wait 0.5 seconds to let concurrent _clip
    # old clipboard data.
    pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5

    local before="$(xsel -ob 2>/dev/null | base64)"
    echo -n "$2" | xsel -ib

    # Create two subshells. The interior one is used to get killed by
    # concurrent _clip functions. The exterior one is used to restore the old
    # clipboard data.
    (
        ( ARGV0=$sleep_argv0 sleep 60 )
        local now="$(xsel -ob | base64)"
        [[ $now != $(echo -n "$2" | base64) ]] && before="$now"

        echo "$before" | base64 -d | xsel -ib
    ) &!
    echo "Will clear in 60 seconds."
}

gen-passphrase () {
    if [[ -z $1 ]] ; then
        dict="words"
    else
        dict=$1
    fi

    passphrase=$(echo $(LC_COLLATE=C grep "^[a-z0-9]\{3,7\}$" /usr/share/dict/$dict | shuf -n4))

    echo "Passphrase copied to clipboard."
    _clip gen-passphrase $(echo $passphrase | tr -d ' ')
}

gen-password () {
    if [[ -z $1 ]] ; then
        length="16"
    else
        length=$1
    fi

    password=$(pwgen $length 1)
    echo "Password copied to clipboard."
    _clip gen-password $password
}

getip () {
    dig +short myip.opendns.com @resolver1.opendns.com
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

hgcl () {
    hg clone $1
    cd "$(basename $1)"
}

hglo () {
    hg log -p | less
}

hglog () {
    hg log -g | less
}

loc () {
    to_search=$(echo $* | sed "s/ /*/g")
    \locate "*${to_search}*"
}

mkcd () {
    [[ -n "$1"  ]] && mkdir -p "$1" && builtin cd "$1"
}

mount () {
    if [ "$#" -eq 0 ] ; then
        /bin/mount | column -t
    else
        /bin/mount $@
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

play () {
    [[ -d ~/.mpd/music/temp/ ]] || mkdir -p ~/.mpd/music/temp &> /dev/null
    find ~/.mpd/music/temp -type l -delete

    for dir in "$@" ; do
        ln -s "$(realpath $dir)" ~/.mpd/music/temp &>/dev/null
    done

    {mpc -q update --wait
    mpc clear
    mpc ls temp | mpc -q add
    mpc play} &>/dev/null &!
}
compdef _files play

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
compdef sc="systemctl"

search () {
    to_search=$(echo $* | sed "s/ /*/g")
    find . -iname "*${to_search}*"
}
alias f=search

share () {
    [[ -d ~/.share/ ]] || mkdir ~/.share

    for file in ~/.share/*(N) ; do
        [[ -L "${file}" ]] && unlink "$file"
    done

    for arg in $* ; do
        [ -f $arg ] && ln -s "$(realpath $arg)" ~/.share

        if [ -d $arg ] ; then
            for file in $arg/* ; do
                ln -s "$(realpath $file)" ~/.share
            done
        fi
    done

    cd ~/.share &>/dev/null

    if [[ $# == 1 ]] ; then
        echo wget -r --reject "index.html" "http://$(ip -o -4 a | awk -F'[ /]+' '$2!~/lo/{print $4}'):8000/${1}" | tee >(xsel -i -b)
    else
        echo wget -r --reject "index.html" "http://$(ip -o -4 a | awk -F'[ /]+' '$2!~/lo/{print $4}'):8000" | tee >(xsel -i -b)
    fi

    # TODO select free port automatically
    python3 -m http.server # ${port}

    cd - &>/dev/null
}

slit () {
    # print columns 1 2 3 ... n
    awk "{ print ${(j:,:):-\$${^@}}  }"
}

sshrc () {
    ssh -o ControlPath=none -o PermitLocalCommand=yes -o LocalCommand="scp -C ~/.ssh-bashrc %n:/tmp/" -t $@ "bash --rcfile /tmp/.ssh-bashrc -i"
}
alias s=sshrc
compdef s="ssh"

sudo-ssh () {
    ssh $* -t "sudo su"
}
compdef sudo-ssh="ssh"

urgent-ssh () {
    ssh -t $@ "/usr/bin/nice -n-20 bash -l"
}
compdef urgent-ssh="ssh"

vmanage () {
    virt-manager -c qemu+ssh://$1/system
}
compdef vmanage="ssh"
