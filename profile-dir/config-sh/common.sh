#!/bin/sh
# common.sh - common shell functions used by bashrc.d & profile.d scripts
# by Ian Kluft

# function to make sure a script is sourced only once
# usage: if source_once keyword; then ...; fi
# where "keyword" is a string to uniquely identify the script calling it
# The keyword will be used to generate and set a variable which blocks re-running this code again.
source_once() {
    var_name='profile_'"$1"'_sourced'
    if eval [ -z \$"${var_name}" ]
    then
        # the variable indicates the script has not already been sourced
        # set the variable so it won't be sourced again
        # return 0 (exit code true)
        eval "${var_name}=1"
        return 0
    fi

    # the variable indicates the script has already been sourced
    # return 1 (exit code false)
    return 1
}

# make sure this only runs once, even when .profile calls .bashrc
if source_once common
then
    # XDG Base Directory paths
    # defined in https://specifications.freedesktop.org/basedir-spec/latest/
    xdg_base_set()
    {
        xdg_var="$1"
        xdg_path="$2"
        if [ ! -d "$xdg_path" ]
        then
            mkdir -p "$xdg_path"
        fi
        if eval [ -z \$"${xdg_var}" ]
        then
            eval "${xdg_var}=$xdg_path"
            eval "export ${xdg_var}"
        fi
    }
    xdg_base_set XDG_CONFIG_HOME "${HOME}/.config"
    xdg_base_set XDG_CACHE_HOME "${HOME}/.cache"
    xdg_base_set XDG_DATA_HOME "${HOME}/.local/share"
    xdg_base_set XDG_STATE_HOME "${HOME}/.local/state"

    # point SH_CONFIG_DIR to ~/.config/sh and SH_PROFILE_DIR to .config/sh/profile.d
    # (following XDG Base Directory Specification to declutter home dot-files)
    SH_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"/sh
    SH_PROFILE_DIR="${SH_CONFIG_DIR}"/profile.d
    export SH_CONFIG_DIR SH_PROFILE_DIR

    # initialize PATHFILTER environment variable to point to a script/symlink or a fallback function
    # ideally we want to point to pathfilter which can be used by multiple profile.d scripts
    PATHFILTER="${SH_CONFIG_DIR}"/pathfilter
    if [ ! -x "${PATHFILTER}" ]
    then
        # find basic commands for path-manipulation functions before messing with the PATH
        expr=$(which expr)
        test=$(which test)
        if [ -z "${expr}" ]
        then
            expr=/usr/bin/expr
        fi
        if [ -z "${test}" ]
        then
            test=/usr/bin/test
        fi

        # is_in_var() function used by pathfilter - returns 0 (shell true) if arg1 dir is found in arg2 path
        is_in_var() {
            pattern="$1"
            var_name="$2"
            # shellcheck disable=SC2003
            if eval "${expr}" match "\":${pattern}:\"" "\"\$${var_name}\"" >/dev/null
            then
                return 0
            fi
            return 1
        }

        # pathfilter() function is a fallback in case of problems with pathfilter program, which should symlink
        # to either Perl or Rust implementation. This is much slower and doesn't canonicalize path entries for
        # more effective deduplication.
        pathfilter() {
            var_name="PATH"
            var_value="${PATH}"
            while "${expr}" $# \> 0 >/dev/null
            do
                case "$1" in
                    "--before")
                        if ! is_in_var "$2" "${var_name}"
                        then
                            var_value="$2:${var_value}"
                        fi
                        shift 2
                        ;;
                    "--after")
                        if ! is_in_var "$2" "${var_name}"
                        then
                            var_value="${var_value}:$2"
                        fi
                        shift 2
                        ;;
                    "--var")
                        # set variable name to manipulate/munge instead of PATH
                        var_name="$2"
                        eval "var_value=\"\$${var_name}\""
                        shift 2
                        ;;
                    "--delimiter")
                        # ignore: setting delimiter not supported in pathfilter fallback function - ':' is hard-coded
                        shift 2
                        ;;
                    *)
                        # other arguments: end processing arguments
                        break
                        ;;
                esac
            done
            echo "${var_value}"
            unset var_name
        }
        # shellcheck disable=SC2034
        PATHFILTER=pathfilter
    fi
    export PATHFILTER
fi
