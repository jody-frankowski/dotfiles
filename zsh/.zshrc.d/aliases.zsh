# -*- mode: sh -*-

# Global aliases
alias -g C='| clipboard'
alias -g COL='| col'
alias -g F='| fzf'
alias -g FM='| fzf -m'
alias -g G='| rg'
alias -g GV='| rg -v'
alias -g H='| head'
alias -g HD='| hexdump -C'
alias -g J='| jq'
alias -g L='| less'
alias -g LE='2>&1 | less'
alias -g M='| moar'
alias -g ME='2>&1 | moar'
# Pipe Print: Print stdin and if the user accepts forward it to stdout
alias -g PP='| tee "$(tty)" | { _pp_var="$(< /dev/stdin)" } ; echo -n "Is this content ok for the next commands? Press Enter to continue or C-c to abort. " ; read ; echo -n "${_pp_var}"'
alias -g S='| sort'
alias -g SU='| sort -u'
alias -g T='| tail'
alias -g U='| uniq'
alias -g WCC='| wc -c'
alias -g WCL='| wc -l'
alias -g X='| xargs -r'
alias -g XI='X -I{}'
alias -g XIN='X -I{} -n'
alias -g XN='X -n'
alias -g Y='| highlight --syntax yaml -O ansi'

alias -g CA='2>&1 | cat -A'
alias -g NE='2> /dev/null'
alias -g NO='> /dev/null'
alias -g NUL='> /dev/null 2>&1'

# For aws/kubectl
alias -g JJ='--output json | jq'
alias -g YY='-o yaml | highlight --syntax yaml -O ansi'

# grep / rg
alias grep='grep --color=auto -i'
alias rg='rg -S'

# Misc
alias dd='dd status=progress'
alias diff='diff -u'
alias get='curl --continue-at - --location --remote-name --remote-time'
alias info='info --vi-keys'
alias ip='ip -c'
alias k='kubectl'
# Don't convert network numbers to hostnames
alias lsof='lsof -n'
alias mkdir='mkdir -pv'
alias o='open'
alias pass='EDITOR=vim pass'
alias rdesktop='rdesktop -g 1680x1050'
alias umount='sudo umount'
_onmacos && alias ifconfig='ifconfig -f inet:cidr,inet6:cidr'

# Systemd
alias jctl='journalctl'
alias jctlu='journalctl --user'
alias scu='systemctl --user'

# ls
alias ls='lsd --group-directories-first'
alias l='ls -l'
alias la='l -a'
alias lat='la -t'
alias latr='lat -r'

# ps and free
alias free='free -h'
alias pscpu='ps auxf | sort -n -k 3'
alias psg='ps aux | rg'
alias psmem='ps auxf | sort -n -k 4'

# Editors
alias e='emacsclient -a "" --tty'
alias v=vim

# Safer commands
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm --one-file-system -I'

# Docker
_onlinux && alias docker='sudo docker'
# Removes all unused containers, images and networks
alias docker-cleanup='docker system prune'
# Removes all containers, images, networks and volumes
alias docker-full-cleanup='docker system prune --all --volumes'

# Git
alias ga='git add'
alias gb='git branch'
alias gbb='git bisect bad'
alias gbg='git bisect good'
alias gbr='git bisect reset'
alias gbs='git bisect start'
alias gc='git commit -v -m'
alias gco='git checkout'
alias gd='git diff'
alias gf='git fetch --all --prune'
alias gl='git pull'
alias glo='git log -p'
alias glog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
alias gp='git push --follow-tags'
alias gst='git status -sb'
alias gsu='git submodule update'

# Pacman
alias pac='pacman'
alias pacqi='pacman -Qi'
alias pacql='pacman -Ql'
alias pacqo='pacman -Qo'
alias pacqs='pacman -Qs'
alias pacrs='sudo pacman -Rs'
alias pacsi='pacman -Si'
alias pacss='pacman -Ss'
alias pikss='pikaur -Ss'
alias pacu='sudo pacman -Syu'
alias piku='sudo pikaur -Syyu --noconfirm'
alias pacman-list-orphans='pacman --query --deps --unrequired'
alias pacman-remove-orphans='sudo pacman --remove --recursive $(pacman --quiet --query --deps --unrequired)'

# Url tools
alias urlencode='python3 -c "import sys, urllib.parse as up; print(up.quote_plus(sys.argv[1]))"'
alias urldecode='python3 -c "import sys, urllib.parse as up; print(up.unquote_plus(sys.argv[1]))"'
