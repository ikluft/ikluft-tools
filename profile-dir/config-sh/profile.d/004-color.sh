#!/bin/sh
# 004-color.sh - included by .profile
# borrowed from Debian/RaspberryPiOS default .bashrc

# wrapper to make sure it only runs once, since it can be called from .profile or .bashrc
if source_once color
then
    # set a fancy prompt (non-color, unless we know we "want" color)
    case "$TERM" in
        xterm-color|*-256color) color_prompt=yes;;
    esac

    # uncomment for a colored prompt, if the terminal has the capability; turned
    # off by default to not distract the user: the focus in a terminal window
    # should be on the output of commands, not on the prompt
    force_color_prompt=yes

    if [ -n "$force_color_prompt" ]; then
        if [ -x /usr/bin/tput ] && tput setaf 1 >/dev/null 2>&1
        then
            # We have color support; assume it's compliant with Ecma-48
            # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
            # a case would tend to support setf rather than setaf.)
            color_prompt=yes
        else
            color_prompt=
        fi
    fi

    if [ "$color_prompt" = yes ]
    then
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \$\[\033[00m\] '
    else
        PS1='\u@\h:\w\$ '
    fi
    unset color_prompt force_color_prompt

    # enable color support of ls and also add handy aliases
    if [ -x /usr/bin/dircolors ]
    then
        if [ -r ~/.dircolors ]
        then
            eval "$(dircolors -b ~/.dircolors)"
        else
            eval "$(dircolors -b)"
        fi
        alias ls='ls --color=auto'
        #alias dir='dir --color=auto'
        #alias vdir='vdir --color=auto'

        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
    fi
fi
