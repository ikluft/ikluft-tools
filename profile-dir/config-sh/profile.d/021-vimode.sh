#!/bin/bash
# 021-vimode.sh - included by .profile

if source_once vimode
then
    # set up VI mode
    EDITOR=vim
    export EDITOR
    set -o vi
fi
