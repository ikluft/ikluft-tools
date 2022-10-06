#!/bin/sh
# 002-terminal.sh - included by .profile

# set TERM and PS1
if [ -n "$WINDOWID" ] && [ -z "$TERM" ]
then
    TERM=xterm
    export TERM
fi
PS1="[\u@\h \W]$ "
export PS1

# tty device settings
stty erase '^h' kill '^x' intr '^c' eof '^d'

