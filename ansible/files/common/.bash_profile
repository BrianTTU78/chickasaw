if [ -f ~/.bash_banner ]; then
   cat ~/.bash_banner
fi

if [ -f ~/.aliases_output ]; then
   echo "Aliases:"
   echo "================================"
   cat ~/.aliases_output
   echo ""
fi

# Set Language
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Set Prompt
PS1='$(whoami):$(pwd) $ '

# Set Path
PATH=$PATH:/usr/local/bin:/opt/bin

#Set Editor
EDITOR=vim

#Set History
HISTSIZE=10000
HISTTIMEFORMAT="%F %T "

HOME=/home/$USER
umask 022

export PS1 EDITOR HISTSIZE PATH HOME HISTTIMEFORMAT

if [ -f ~/.bash_aliases ]; then
   . ~/.bash_aliases
fi
