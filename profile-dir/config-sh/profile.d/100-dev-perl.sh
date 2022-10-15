#!/bin/sh
# 100-dev-perl.sh - included by .profile

#
# software development settings
#

if source_once dev_perl
then
    # Perl
    # skip if perl is not found
    # usually no perl also means we're in a flatpak container - so don't spew unnecessary errors in containers
    perl=$(which perl) 2>/dev/null
    if [ -n "$perl" ]
    then
        if [ -n "$PERL5LIB" ]
        then
            PERL5LIB=$(perl -Mfeature=say -e 'say join ":", (grep {substr($_, 0, 6) ne "/home/"} @INC), (grep {substr($_, 0, 6) eq "/home/"} @INC)')
        fi
        PERL_LOCAL_LIB_ROOT="${HOME}/lib/perl${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
        PERL5LIB=$("${PATHFILTER}" --var=PERL5LIB --after /usr/local/share/perl5:"${HOME}"/lib/perl/lib/perl5:"${HOME}"/lib/perl/share/perl5)
        MANPATH=$("${PATHFILTER}" --var=MANPATH --before "${HOME}"/lib/perl/man)
        export PERL_LOCAL_LIB_ROOT PERL5LIB MANPATH
        eval "$($perl -I~/lib/perl -Mlocal::lib=~/lib/perl)"
    fi
fi
