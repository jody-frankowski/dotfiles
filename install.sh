#!/bin/bash

set -e

script_dir=$(dirname $0)
pushd ${script_dir} > /dev/null

source ./lib.sh

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

popd > /dev/null
