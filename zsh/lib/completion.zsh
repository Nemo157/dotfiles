## Setup completion styles
# case-insensitive (all),partial-word and then substring completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u `whoami` -o pid,user,comm -w -w"

zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin

# disable named-directories autocompletion
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
cdpath=(. ~ ~/sources)

# use /etc/hosts and known_hosts for hostname completion
if [[ -r ~/.ssh/known_hosts ]] _ssh_hosts=(${${${${${(f)"$(<$HOME/.ssh/known_hosts)"}:#\#*}%%\ *}%%,*}:#[[]*})
if [[ -r /etc/hosts ]] : ${(A)_etc_hosts:=${(s: :)${(ps:\t:)${${(f)~~"$(</etc/hosts)"}%%\#*}##[:blank:]#[^[:blank:]]#}}}

known_hosts=(
  "$_ssh_hosts[@]"
  "$_etc_hosts[@]"
  $(hostname)
  localhost
)
zstyle ':completion:*:hosts' hosts $known_hosts

# Use caching so that commands like apt and dpkg complete are useable
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion::complete:*' cache-path /tmp/zsh-completion/cache/

uninteresting_users=(
# Linux
  adm amanda apache avahi beaglidx bin cacti canna clamav daemon dbus distcache
  dovecot fax ftp games gdm gkrellmd gopher hacluster haldaemon halt hsqldb
  ident junkbust ldap lp mail mailman mailnull mldonkey mysql nagios named
  netdump news nfsnobody nobody nscd ntp nut nx openvpn operator pcap postfix
  postgres privoxy pulse pvm quagga radvd rpc rpcuser rpm shutdown squid sshd
  sync uucp vcsa xfs cron man portage messagebus

  murmur postmaster subsonic transmission tcpdump dhcp guest logcheck minecraft
  redis tcpdump
# OS X
  '_*'
)
zstyle ':completion:*:*:*:users' ignored-patterns $uninteresting_users

# ... unless we really want to.
zstyle '*' single-ignored show

## Load additional ZSH completion scripts.
# My completion scripts
fpath=($ZDOTDIR/functions/completion $fpath)
# The Homebrew installed completion scripts.
fpath=(/usr/local/share/zsh-completions $fpath)

autoload -U compinit
compinit
