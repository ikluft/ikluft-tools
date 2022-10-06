#!/bin/bash
# ~/.bashrc is run by bash when an interactive shell which is not a login shell is started
# note: login shells run ~/.bash_profile or ~/.profile instead of ~/.bashrc
# by Ian Kluft

# Source global definitions first so we can override them
if [ -f /etc/bashrc ]; then
	source /etc/bashrc
fi

# XDG Base Directory paths
# defined in https://specifications.freedesktop.org/basedir-spec/latest/
function xdg_base_set
{
    xdg_var="$1"
    xdg_path="$2"
    if [ ! -d "$xdg_path" ]
    then
        mkdir -p "$xdg_path"
    fi
    if [ -z "${!xdg_var}" ] # ! = use indirection to read var named by a var
    then
        eval "${xdg_var}=$xdg_path"
        eval "export ${xdg_var}"
    fi
}
xdg_base_set XDG_CONFIG_HOME "${HOME}/.config"
xdg_base_set XDG_CACHE_HOME "${HOME}/.cache"
xdg_base_set XDG_DATA_HOME "${HOME}/.local/share"
xdg_base_set XDG_STATE_HOME "${HOME}/.local/state"

# point BASHRC_DIR at .config/sh/bashrc.d and SH_PROFILE_DIR at .config/sh/profile.d
# (following XDG Base Directory Specification to declutter home dot-files)
SH_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"/sh
BASHRC_DIR="${SH_CONFIG_DIR}/bashrc.d"
SH_PROFILE_DIR="${SH_CONFIG_DIR}/profile.d"
export BASHRC_DIR SH_PROFILE_DIR

# point to pathmunge.pl which can be used by multiple profile.d scripts
PATHMUNGE="${SH_CONFIG_DIR}"/pathmunge.pl
export PATHMUNGE

# make sure BASHRC_DIR existS
if [ ! -d "$BASHRC_DIR" ]
then
    mkdir -p "$BASHRC_DIR"
    chmod u=rwx,go= "$BASHRC_DIR"
fi

# run scripts from .config/sh/bashrc.d
if [ -f "${BASHRC_DIR}"/profile-import ]
then
    # shellcheck disable=SC2162
    while read name <  "${BASHRC_DIR}"/profile-import
    do
        if [ -e "${SH_PROFILE_DIR}/$name" ]
        then
            # shellcheck disable=SC1090
            echo ".bashrc: import $name"
            source "${SH_PROFILE_DIR}/$name"
        fi
    done
fi
for file in "${BASHRC_DIR}"/*.sh "${BASHRC_DIR}"/*.bash
do
        # shellcheck disable=SC1090
        echo ".bashrc: source $file"
        source "$file"
done
unset BASHRC_DIR
