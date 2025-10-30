#!/bin/sh
# 003-pathfilter.sh - included by .profile

# wrapper to make sure it only runs once, since it can be called from .profile or .bashrc
if source_once pathfilter
then
    # path-munging operations
    # skip if we're in a flatpak container, which won't have these directories
    if [ -z "$FLATPAK_ID" ]
    then
        # munge path
        PATH=$("${PATHFILTER}" --before /usr/bin:"${HOME}"/lib/perl/bin --after "${HOME}/bin:${HOME}/.local/bin:${HOME}/.local/lib/cargo/bin")

        # fix PATH for root - recently has not been including /sbin:/usr/sbin
        if [ "$(/usr/bin/id -n -u)" = 'root' ]
        then
            PATH=$("${PATHFILTER}" --before /sbin:/usr/sbin:/bin)
        fi
        export PATH
    fi
fi
