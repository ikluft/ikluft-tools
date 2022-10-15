#!/bin/sh
# 100-dev-go.sh - included by .profile

#
# software development settings
#

if source_once dev_go
then
    # Golang
    if [ -d "${HOME}"/src/go ]
    then
        GOPATH=${HOME}/src/go
        export GOPATH
    fi

    # path-munging operations
    # skip if we're in a flatpak container
    if [ -z "$FLATPAK_ID" ] && [ -n "${GOPATH}" ] && [ -d "${GOPATH}/bin" ]
    then
        oldpath="$PATH"
        PATH=$("${PATHFILTER}" --after "${GOPATH}/bin" || echo "${oldpath}")
        export PATH
        unset oldpath
    fi
fi
