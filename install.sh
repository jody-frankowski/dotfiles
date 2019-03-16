#!/bin/bash

set -e

silent () {
    # This function captures all the output (stdout and stderr) of the command
    # (and its arguments) passed by argument and will only output it if the
    # command doesn't return 0.

    tmp=$(mktemp) || return # this will be the temp file w/ the output
    set +e
    set -e
    "$@" > "$tmp" 2>&1 # this should run the command, respecting all arguments
    ret=$?
    if [ "$ret" -ne 0 ] ; then
        echo "$@"
        cat "$tmp"  # if $? (the return of the last run command) is not zero, cat the temp file
    fi
    rm -f "$tmp"
    return "$ret" # return the exit status of the command
}

script_dir=$(dirname $0)
silent pushd ${script_dir}

# stow some dotfiles
for dir in docker tmux zsh ; do
    silent stow --no-folding ${dir}
done

if [[ `id -u` -ne 0 ]] ; then
    ./user-only.sh
fi

for terminfo in ./base/.terminfo/*.terminfo ; do
    tic -x -o ~/.terminfo $terminfo
done

cd ~

# fzf
if [[ ! -d ~/.usr/opt/fzf ]] ; then
    silent git clone --depth 1 https://github.com/junegunn/fzf.git ~/.usr/opt/fzf
    silent pushd ~/.usr/opt/fzf
    silent git pull
    silent make
    silent make install
    silent popd
    silent ln -s ~/.usr/opt/fzf/bin/fzf ~/.usr/bin/
fi

# vim
silent curl https://raw.githubusercontent.com/amix/vimrc/master/vimrcs/basic.vim -o ~/.vimrc
