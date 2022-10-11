#!/bin/sh
# 003-pathfilter.sh - included by .profile

# wrapper to make sure it only runs once, since it can be called from .profile or .bashrc
if [ -z "${profile_pathfilter_executed}" ]
then
    # path-munging operations
    # skip if perl doesn't exist (which means we're in a container and these paths don't matter)
    perl=$(which perl) >/dev/null 2>&1
    if [ -n "$perl" ]
    then
        # munge path
        PATH=$("${PATHFILTER}" --before /usr/bin:"${HOME}"/lib/perl/bin)

        # fix PATH for root - recently has not been including /sbin:/usr/sbin
        if [ "$(/usr/bin/id -n -u)" = 'root' ]
        then
            PATH=$("${PATHFILTER}" --before /sbin:/usr/sbin:/bin)
        fi
        export PATH
    fi
    profile_pathfilter_executed=1
fi
