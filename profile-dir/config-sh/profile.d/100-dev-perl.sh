#!/bin/sh
# 100-dev-perl.sh - included by .profile

#
# software development settings
#

# Perl
if [ -n "$perl" ]
then
    if [ -n "$PERL5LIB" ]
    then
        PERL5LIB=$(perl -Mfeature=say -e 'say join ":", (grep {substr($_, 0, 6) ne "/home/"} @INC), (grep {substr($_, 0, 6) eq "/home/"} @INC)')
    fi
    PERL_LOCAL_LIB_ROOT="${HOME}/lib/perl${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
    PERL5LIB=$("${PATHMUNGE}" --var=PERL5LIB --after=/usr/local/share/perl5:"${HOME}"/lib/perl/lib/perl5:"${HOME}"/lib/perl/share/perl5)
    MANPATH=$("${PATHMUNGE}" --var=MANPATH --before="${HOME}"/lib/perl/man)
    export PERL_LOCAL_LIB_ROOT PERL5LIB MANPATH
    eval "$($perl -I~/lib/perl -Mlocal::lib=~/lib/perl)"
fi
