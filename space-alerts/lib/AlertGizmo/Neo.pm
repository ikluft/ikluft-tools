# AlertGizmo::Neo
# ABSTRACT: AlertGizmo monitor for NASA JPL Near-Earth Object (NEO) close approach data
# Copyright (c) 2024 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);   # includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Neo;

use parent "AlertGizmo";

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Readonly;
use Carp qw(croak confess);

# constants
Readonly::Scalar my $NEO_API_URL =>
    "https://ssd-api.jpl.nasa.gov/cad.api?dist-max=2LD&sort=-date&diameter=true&date-min=%s";
Readonly::Scalar my $NEO_LINK_URL =>
    "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=";
Readonly::Scalar my $OUTJSON  => "neo-data.json";
Readonly::Scalar my $TEMPLATE => "close-approaches.tt";
Readonly::Scalar my $OUTHTML  => "close-approaches.html";
Readonly::Scalar my $E_RADIUS => 6378;
Readonly::Scalar my $UC_QMARK => "\N{fullwidth question mark}";    # Unicode question mark
Readonly::Scalar my $UC_NDASH => "\N{en dash}";                    # Unicode dash
Readonly::Scalar my $UC_PLMIN => "\N{plus minus sign}";            # Unicode plus-minus sign

# class method AlertGizmo (parent) calls before template processing
sub pre_template
{
    my $class = shift;

    # clear destination symlink
    $class->paths( [ qw( outlink ) ], $class->config_dir() . "/" . $OUTJSON );
    if ( -e paths( [ qw( outlink ) ] ) ) {
        if ( not -l $class->paths( [ qw( outlink ) ] )) {
            croak "destination file " . $class->paths( [ qw( outlink ) ] ) . " is not a symlink";
        }
    }
    $class->paths( [ qw( outjson ) ], $class->paths( [ qw( outlink ) ] ) . "-" . $class->config_timestamp());
    return;
}

1;
