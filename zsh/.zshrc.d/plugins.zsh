# -*- mode: sh -*-

REPOS_DIR="$HOME/.zshrc.d/repos"

[[ ! -d $REPOS_DIR ]] && mkdir -p $REPOS_DIR

completion () {
    _clone $PLUGINS_REPO
    clone_dir=$(echo "$PLUGINS_REPO" | sed -e 's./.-SLASH-.g' -e 's.:.-COLON-.g' -e 's.|.-PIPE-.g')

    pushd $REPOS_DIR

    fpath=(`readlink -f $clone_dir/$1` $fpath)
    for file in $clone_dir/$1/* ; do
        autoload -Uz `basename ${file}`
    done

    popd
}

_clone () {
    clone_dir=$(echo "$PLUGINS_REPO" | sed -e 's./.-SLASH-.g' -e 's.:.-COLON-.g' -e 's.|.-PIPE-.g')

    pushd $REPOS_DIR

    if [ ! -d $clone_dir ] ; then
        chronic git clone --recursive $PLUGINS_REPO $clone_dir
        find $clone_dir -type d -exec chmod 700 {} \; &> /dev/null
        find $clone_dir -type f -exec chmod 600 {} \; &> /dev/null
    fi

    popd
}

lib () {
    #if [[ $# -lt 1 ]] ; then
        #echo "You need to give files to source to this function"
        #exit 1
    #fi

    _clone $PLUGINS_REPO
    clone_dir=$(echo "$PLUGINS_REPO" | sed -e 's./.-SLASH-.g' -e 's.:.-COLON-.g' -e 's.|.-PIPE-.g')

    pushd $REPOS_DIR

    #source "$@"
    if [[ -n $1 ]] ; then
        for zsh in $clone_dir/$1/*.zsh ; do
            source ${zsh}
        done
    fi

    popd
}

plugin () {
    _clone $PLUGINS_REPO
    clone_dir=$(echo "$PLUGINS_REPO" | sed -e 's./.-SLASH-.g' -e 's.:.-COLON-.g' -e 's.|.-PIPE-.g')

    pushd $REPOS_DIR

    if [[ -n $1 && -d $clone_dir/$1 ]] ; then
        pushd $clone_dir/$1
    else
        pushd $clone_dir
    fi

    if [[ -d functions ]] ; then
        fpath=(`pwd`/functions $fpath)
        for file in functions/* ; do
            autoload -Uz `basename ${file}`
        done
    fi

    if [[ -n $1 && -f $1 ]] ; then
        source $1
    elif [[ -f init.zsh ]] ; then
        source init.zsh
    else
        for file in *.plugin.zsh(N) ; do
            source ${file}
        done
    fi

    popd
    popd
}

update-plugins () {
    for dir in $REPOS_DIR/*/ ; do
        pushd $dir
        git checkout .
        git pull
        popd
    done

    chmod -R u=rwX,g=,o= $REPOS_DIR
}
