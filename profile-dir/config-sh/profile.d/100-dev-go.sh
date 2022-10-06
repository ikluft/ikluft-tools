#!/bin/sh
# 100-dev-go.sh - included by .profile

#
# software development settings
#

# Golang
if [ -d "${HOME}"/src/go ]
then
    GOPATH=${HOME}/src/go
    export GOPATH
fi

# path-munging operations
# skip if perl doesn't exist (which means we're in a container and these paths don't matter)
perl=$(which perl) 2>/dev/null
if [ -n "$perl" ] && [ -n "${GOPATH}" ] && [ -d "${GOPATH}/bin" ]
then
    oldpath="$PATH"
    PATH=$("${PATHMUNGE}" --after="${GOPATH}/bin" || echo "${oldpath}")
    export PATH
    unset oldpath
fi

