#!/bin/bash

set -euo pipefail
set -x

script_dir=$(dirname $0)
pushd ${script_dir} > /dev/null

for dir in ~/.usr/bin/ ~/.usr/opt/ ~/.usr/share/ ~/.usr/var/log/ ; do
    [[ -d "${dir}" ]] || mkdir -p "${dir}"
done

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

popd > /dev/null
