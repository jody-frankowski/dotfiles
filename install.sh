#!/bin/bash

set -euo pipefail
set -x

script_dir=$(dirname $0)
pushd ${script_dir} > /dev/null

for dir in ~/.usr/bin/ ~/.usr/opt/ ~/.usr/var/log/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

if [[ "$OSTYPE" == "darwin"* ]]; then
    export PATH="~/.brew/bin/:$PATH"

    [[ -d ~/.brew ]] || git clone --depth=1 https://github.com/Homebrew/brew ~/.brew

    packages=(
        atool
        coreutils
        python3
        ripgrep
        stow
        tmux
    )

    for package in ${packages[@]} ; do
        [[ -d ~/.brew/opt/$package ]] || brew install $package
    done

    latest_tmux=$(ls -t ~/.brew/Cellar/tmux/ | head -n1)
    if ! grep with-utf8proc ~/.brew/Cellar/tmux/$latest_tmux/.brew/tmux.rb &>/dev/null ; then
        sed -i -e $'s/args = %W\\[/args = %W[\\\n      --with-utf8proc/' ~/.brew/Cellar/tmux/$latest_tmux/.brew/tmux.rb
        brew reinstall tmux
    fi

    # coreutils symlinks
    for symlink in date dircolors ls rm ; do
        [[ -L ~/.usr/bin/$symlink ]] || ln -s g$symlink ~/.usr/bin/$symlink
    done

    # We need the terminfo capabilites of tmux-256color, however macOS doesn't
    # provide one.  The one that is in the homebrew's ncurses is incompatible
    # with macOS ncurses tools (tic/terminfo). So we export the terminfo
    # capabilities with homebrew's ncurses tools and compile them with macOS'
    # tic.
    [[ -d ~/.terminfo ]] || mkdir ~/.terminfo
    latest_ncurses=$(ls -t ~/.brew/Cellar/ncurses/ | head -n1)
    PATH="~/.brew/opt/ncurses/bin:$PATH" TERMINFO_DIRS=~/.brew/Cellar/ncurses/$latest_ncurses/share/terminfo/ infocmp -x tmux-256color > ~/.terminfo/tmux-256color
    tic -x ~/.terminfo/tmux-256color
fi

if [[ `id -u` -ne 0 ]] ; then
    ./user-only.sh
fi

# stow some dotfiles
for dir in docker tmux zsh ; do
    stow --no-folding ${dir}
done

# tpm (tmux-plugin-manager)
# This needs to be after tmux's stowing because tpm searches for its config in tmux.conf
[[ -d ~/.tmux/plugins/tpm ]] || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# install plugins. buggy, better use prefix + I
~/.tmux/plugins/tpm/scripts/install_plugins.sh > /dev/null

for terminfo in ./base/.terminfo/*.terminfo ; do
    tic -x -o ~/.terminfo $terminfo
done

# fzf
export GOPATH=~/.go
go get -u github.com/junegunn/fzf

popd > /dev/null
