#!/bin/sh
# 003-pathmunge.sh - included by .profile

# wrapper to make sure it only runs once, since it can be called from .profile or .bashrc
if [ -z "${PROFILE_PATHMUNGE_EXECUTED}" ]
then
    # path-munging operations
    # skip if perl doesn't exist (which means we're in a container and these paths don't matter)
    perl=$(which perl) >/dev/null 2>&1
    if [ -n "$perl" ]
    then
        # munge path
        PATH=$("${PATHMUNGE}" --before=/usr/bin:"${HOME}"/lib/perl/bin)

        # fix PATH for root - recently has not been including /sbin:/usr/sbin
        if [ "$(/usr/bin/id -n -u)" = 'root' ]
        then
            PATH=$("${PATHMUNGE}" --before=/sbin:/usr/sbin:/bin)
        fi
        export PATH
    fi
fi
PROFILE_PATHMUNGE_EXECUTED=1
export PROFILE_PATHMUNGE_EXECUTED
