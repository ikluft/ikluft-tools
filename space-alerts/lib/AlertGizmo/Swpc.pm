# AlertGizmo::Swpc
# ABSTRACT: AlertGizmo monitor for NOAA Space Weather Prediction Center (SWPC) alerts, including aurora
# Copyright 2024 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);   # includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Swpc;

use parent "AlertGizmo";

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use charnames qw(:loose);
use Readonly;
use Carp qw(croak confess);


# class method AlertGizmo (parent) calls before template processing
sub pre_template
{
    my $class = shift;

    # TODO
    return;
}

# class method AlertGizmo (parent) called after template processing
sub post_template
{
    my $class = shift;

    # TODO
    return;
}

1;
