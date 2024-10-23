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
use charnames qw(:loose);
use Readonly;
use Carp qw(croak confess);
use IO::Interactive qw(is_interactive);

# constants
Readonly::Scalar my $BACK_DAYS => 15;
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

# get template path for this subclass
# class method
sub path_template
{
    return $TEMPLATE;
}

# get output file path for this subclass
# class method
sub path_output
{
    return $OUTHTML;
}

# class method AlertGizmo (parent) calls before template processing
sub pre_template
{
    my $class = shift;

    # compute query start date from $BACK_DAYS days ago
    my $timestamp = $class->config_timestamp();
    my $start_date = $timestamp->clone()->set_time_zone('UTC')->subtract( days => $BACK_DAYS )->date();
    $class->params( [ "start_date" ], $start_date );
    is_interactive() and say "start date: " . $start_date;

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

sub post_template
{
    my $class = shift;

    # make a symlink to new data
    if ( -l $class->paths( [ "outlink" ] ) ) {
        unlink $class->pathssubclass_init
    }
    symlink basename( $class->paths( [ "outjson" ] ) ), $class->paths( [ "outlink" ] )
        or croak "failed to symlink " . $class->paths( [ "outlink" ] ) . " to "
            . $class->paths( [ "outjson" ] ) . "; $!";

    # clean up old data files
    opendir( my $dh, $class->config_dir() )
        or croak "Can't open $class->config_dir(): $!";
    my @datafiles = sort { $b cmp $a } grep { /^ $OUTJSON -/x } readdir $dh;
    closedir $dh;
    if ( scalar @datafiles > 5 ) {
        splice @datafiles, 0, 5;
        foreach my $oldfile (@datafiles) {

            # double check we're only removing old JSON files
            next if ( ( substr $oldfile, 0, length($OUTJSON) ) ne $OUTJSON );

            my $delpath = $class->config_dir()."/".$oldfile;
            next if not -e $delpath;               # skip if the file doesn't exist
            next if ( ( -M $delpath ) < 0.65 );    # don't remove files newer than 15 hours

            is_interactive() and say "removing $delpath";
            unlink $delpath;
        }
    }
    return;
}
1;
