#!/bin/bash

set -e

script_dir=$(dirname $0)
pushd ${script_dir} > /dev/null

source ./lib.sh

for dir in ~/.usr/bin/ ~/.usr/opt/ ~/.usr/var/log/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

if [[ `id -u` -ne 0 ]] ; then
    ./user-only.sh
fi

# stow some dotfiles
for dir in docker tmux zsh ; do
    stow --no-folding ${dir}
done

for terminfo in ./base/.terminfo/*.terminfo ; do
    tic -x -o ~/.terminfo $terminfo
done

# fzf
go get -u github.com/junegunn/fzf

# vim
silent curl https://raw.githubusercontent.com/amix/vimrc/master/vimrcs/basic.vim -o ~/.vimrc

popd > /dev/null
