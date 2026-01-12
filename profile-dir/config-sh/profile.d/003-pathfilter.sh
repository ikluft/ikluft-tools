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

        if [ "$(/usr/bin/id -n -u)" = 'root' ]
        then
            # fix PATH for root - recently has not been including /sbin:/usr/sbin
            PATH=$("${PATHFILTER}" --before /sbin:/usr/sbin:/bin)
        else
            # fix path for user - include XDG per-user binaries if directory exists
            sp_cmd="$(which systemd-path)"
            if [ -n "$sp_cmd" ]
            then
                user_bin="$(systemd-path user-binaries)"
                if [ -n "$user_bin" ] && [ -d "$user_bin" ]
                then
                    PATH=$("${PATHFILTER}" --after "$user_bin")
                fi
            fi
        fi
        export PATH
    fi
fi
