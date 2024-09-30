#!/usr/bin/env perl
#===============================================================================
#         FILE: pull-nasa-neo.pl
#        USAGE: ./pull-nasa-neo.pl
#  DESCRIPTION: get upcoming & recent Near Earth Object approaches from NASA JPL API
#       AUTHOR: Ian Kluft (IKLUFT)
#      CREATED: 06/30/23 11:08:06
#===============================================================================

use strict;
use warnings;
use utf8;
use autodie;
use Modern::Perl qw(2023);          # built-in boolean types require 5.36, try/catch requires 5.34
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use charnames qw(:loose);
use Readonly;
use Carp qw(croak confess);
use File::Basename;
use FindBin;
use DateTime;
use DateTime::Format::Flexible;
use IPC::Run;
use Getopt::Long;
use File::Slurp;
use IO::Interactive qw(is_interactive);
use JSON;
use URI::Escape;
use Template;
use Data::Dumper;

# parse command-line
my %options;
GetOptions( \%options, "test|test_mode", "proxy:s", "timezone|tz:s" );

# constants
Readonly::Scalar my $TEST_MODE => $options{test}  // false;
Readonly::Scalar my $PROXY     => $options{proxy} // $ENV{PROXY} // $ENV{SOCKS_PROXY};
Readonly::Scalar my $BACK_DAYS => 15;
Readonly::Scalar my $TIMEZONE  => $options{timezone} // "UTC";
Readonly::Scalar my $TIMESTAMP => DateTime->now( time_zone => $TIMEZONE );
Readonly::Scalar my $NEO_API_URL =>
    "https://ssd-api.jpl.nasa.gov/cad.api?dist-max=2LD&sort=-date&diameter=true&date-min=%s";
Readonly::Scalar my $NEO_LINK_URL =>
    "https://ssd.jpl.nasa.gov/tools/sbdb_lookup.html#/?sstr=";
Readonly::Scalar my $OUTDIR   => $FindBin::Bin;
Readonly::Scalar my $OUTJSON  => "neo-data.json";
Readonly::Scalar my $TEMPLATE => "close-approaches.tt";
Readonly::Scalar my $OUTHTML  => "close-approaches.html";
Readonly::Scalar my $E_RADIUS => 6378;
Readonly::Scalar my $UC_QMARK => "\N{fullwidth question mark}";    # Unicode question mark
Readonly::Scalar my $UC_NDASH => "\N{en dash}";                    # Unicode dash
Readonly::Scalar my $UC_PLMIN => "\N{plus minus sign}";            # Unicode plus-minus sign

# internal computation for bgcolor for each table, called by dist2bgcolor()
sub _dist2rgb
{
    my $dist = shift;

    # green for over 350000km
    if ( $dist >= 350000 ) {
        return ( 0, 255, 0 );
    }

    # 150k-250k km -> ramp from green #00FF00 to yellow #FFFF00
    if ( $dist >= 250000 ) {
        my $ramp = 255 - int( ( $dist - 250000 ) / 100000 * 255 );
        return ( $ramp, 255, 0 );
    }

    # 50k-150k km -> ramp from yellow #7F7F00 to orange #7F5300
    if ( $dist >= 150000 ) {
        my $ramp = 165 + int( ( $dist - 150000 ) / 100000 * 91 );
        return ( 255, $ramp, 0 );
    }

    # 50k-150k km -> ramp from orange #7F5300 to red #7F0000
    if ( $dist >= 50000 ) {
        my $ramp = int( ( $dist - 50000 ) / 100000 * 165 );
        return ( 255, $ramp, 0 );
    }

    # surface-50000 km -> red bg
    if ( $dist >= $E_RADIUS ) {
        return ( 255, 0, 0 );
    }

    # less than surface -> BlueViolet bg (impact!)
    return ( 138, 43, 226 );
}

# compute bgcolor for each table row based on NEO distance at closest approach
sub dist2bgcolor
{
    # background color computation based on distance
    my $dist_min_km = shift;
    my ( $red, $green, $blue );

    ( $red, $green, $blue ) = _dist2rgb($dist_min_km);

    # return RGB string
    return sprintf( "#%02X%02X%02X", $red, $green, $blue );
}

# internal computation for bgcolor for table cell, called by diameter2bgcolor()
sub _diameter2rgb
{
    my $diameter_str = shift;

    # deal with unknown diameter
    if ( $diameter_str eq $UC_QMARK ) {
        return ( 192, 192, 192 );
    }

    my $diameter;
    if ( $diameter_str =~ /^ ( \d+ ) $UC_NDASH ( \d+ ) $/x ) {

        # if an estimated range of diameters was provided, use the top end for the cell color
        $diameter = int($2);
    } else {

        # otherwise use the initial integer as a median value
        $diameter_str =~ s/[^\d] .*//x;
        $diameter = int($diameter_str);
    }

    # green for under 20m
    if ( $diameter <= 30 ) {
        return ( 0, 255, 0 );
    }

    # 20-75m -> ramp from green #00FF00 to yellow #FFFF00
    if ( $diameter <= 75 ) {
        my $ramp = int( ( $diameter - 20 ) / 55 * 255 );
        return ( $ramp, 255, 0 );
    }

    # 75-140m -> ramp from yellow #7F7F00 to orange #7F5300
    if ( $diameter <= 140 ) {
        my $ramp = 165 + int( ( $diameter - 75 ) / 65 * 91 );
        return ( 255, $ramp, 0 );
    }

    # 140-1000m -> ramp from orange #7F5300 to red #7F0000
    if ( $diameter <= 1000 ) {
        my $ramp = int( ( $diameter - 140 ) / 860 * 165 );
        return ( 255, $ramp, 0 );
    }

    # over 1000m -> red bg
    return ( 255, 0, 0 );
}

# compute bgcolor for table cell based on NEO diameter
sub diameter2bgcolor
{
    # background color computation based on distance
    my $diameter_min_km = shift;
    my ( $red, $green, $blue );

    ( $red, $green, $blue ) = _diameter2rgb($diameter_min_km);

    # return RGB string
    return sprintf( "#%02X%02X%02X", $red, $green, $blue );
}

# perform NEO query and save result in named file
sub do_neo_query
{
    my ( $paths, $params ) = @_;

    # perform NEO query
    if ($TEST_MODE) {
        if ( not -e $paths->{outlink} ) {
            croak "test mode requires $paths->{outlink} to exist";
        }
        say "*** skip API access in test mode ***";
    } else {
        my $url = sprintf $NEO_API_URL, $params->{start_date};
        my ( $outstr, $errstr );
        my @cmd = (
            "/usr/bin/curl", "--silent", ( ( defined $PROXY ) ? ( "--proxy", $PROXY ) : () ),
            "--output", $paths->{outjson}, $url
        );
        IPC::Run::run( \@cmd, '<', \undef, '>', \$outstr, '2>', \$errstr );

        # check results of query
        if ( $? == -1 ) {
            confess "failed to execute command (" . join( " ", @cmd ) . "): $!";
        }
        my $retcode = $? >> 8;
        if ( $? & 127 ) {
            confess sprintf "command ("
                . join( " ", @cmd )
                . " child died with signal %d, %s coredump\n",
                ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
        }
        if ( $retcode != 0 ) {
            confess sprintf "command (" . join( " ", @cmd ) . " exited with code $retcode";
        }
        if ( -z $paths->{outjson} ) {
            croak "JSON data file " . $paths->{outjson} . " is empty";
        }
        if ($errstr) {
            say "stderr from command: $errstr";
        }
        if ($outstr) {
            say "stdout from command: $outstr";
        }
    }
    return;
}

# convert DateTime to date/time/tz string
sub dt2dttz
{
    my $dt = shift;
    return $dt->ymd('-') . " " . $dt->hms(':') . " " . $dt->time_zone_short_name();
}

# get distance as km (convert from AU)
sub get_dist_km
{
    my ( $param_name, $raw_item, $params ) = @_;

    my $dist_au = $raw_item->[ $params->{fnum}{$param_name} ];
    my $dist_km = $dist_au * 1.4959787e+08;
    return int( $dist_km + 0.5 );
}

# convert magnitude (h) to estimated diameter in m
sub h_to_diameter_m
{
    my ( $h, $p ) = @_;
    my $ee = -0.2 * $h;
    return 1329.0 / sqrt($p) * ( 10**$ee ) * 1000.0;
}

# get diameter as a printable string
# if diameter data exists, format diameter +/- diameter_sigma
# otherwise estimate diameter from magnitude (see https://www.physics.sfasu.edu/astro/asteroids/sizemagnitude.html )
sub get_diameter
{
    my $raw_item = shift;
    my $params   = shift;

    # if diameter data was provided, use it
    if (    ( exists $raw_item->[ $params->{fnum}{diameter} ] )
        and ( defined $raw_item->[ $params->{fnum}{diameter} ] )
        and ( $raw_item->[ $params->{fnum}{diameter} ] ne "null" ) )
    {
        # diameter data found - format it with or without diameter_sigma
        my $diameter = "" . int( $raw_item->[ $params->{fnum}{diameter} * 1000.0 ] + 0.5 );
        if (    ( exists $raw_item->[ $params->{fnum}{diameter_sigma} ] )
            and ( defined $raw_item->[ $params->{fnum}{diameter_sigma} ] )
            and ( $raw_item->[ $params->{fnum}{diameter_sigma} ] ne "null" ) )
        {
            $diameter .= " "
                . $UC_PLMIN . " "
                . int( $raw_item->[ $params->{fnum}{diameter_sigma} * 1000.0 ] + 0.5 );
        }
        return $diameter;
    }

    # if magnitude data was provided, estimate diameter from it
    # according to API definition, h (absolute magnitude) should be provided
    if (    ( exists $raw_item->[ $params->{fnum}{h} ] )
        and ( defined $raw_item->[ $params->{fnum}{h} ] )
        and ( $raw_item->[ $params->{fnum}{h} ] ne "null" ) )
    {
        my $min = int( h_to_diameter_m( $raw_item->[ $params->{fnum}{h} ], 0.25 ) + 0.5 );
        my $max = int( h_to_diameter_m( $raw_item->[ $params->{fnum}{h} ], 0.05 ) + 0.5 );
        return $min . $UC_NDASH . $max;
    }

 # if diameter and magnitude were both unknown, deal with missing data by displaying a question mark
    return $UC_QMARK;
}

sub main
{
    # template data & setup
    my $params = {};
    my $paths  = {};

    # compute query start date from $BACK_DAYS days ago
    $params->{timestamp} = dt2dttz($TIMESTAMP);
    $params->{start_date} =
        $TIMESTAMP->clone()->set_time_zone('UTC')->subtract( days => $BACK_DAYS )->date();
    is_interactive() and say "start date: " . $params->{start_date};

    # clear destination symlink
    $paths->{outlink} = $OUTDIR . "/" . $OUTJSON;
    if ( -e $paths->{outlink} ) {
        if ( not -l $paths->{outlink} ) {
            croak "destination file $paths->{outlink} is not a symlink";
        }
    }
    $paths->{outjson} = $paths->{outlink} . "-" . $TIMESTAMP;

    # perform NEO query
    do_neo_query( $paths, $params );

    # read JSON into template data
    # in case of JSON error, allow these to crash the program here before proceeding to symlinks
    my $json_path = $TEST_MODE ? $paths->{outlink} : $paths->{outjson};
    my $json_text = File::Slurp::read_file($json_path);
    $params->{json} = JSON::from_json $json_text;

    # check API version number
    if ( $params->{json}{signature}{version} ne "1.5" ) {
        croak "API version changed to "
            . $params->{json}{signature}{version}
            . " - code needs checking";
    }

    # collect field names/numbers from JSON
    $params->{fnum} = {};
    for ( my $fnum = 0 ; $fnum < scalar @{ $params->{json}{fields} } ; $fnum++ ) {
        $params->{fnum}{ $params->{json}{fields}[$fnum] } = $fnum;
    }

    # convert API results to template-able list
    $params->{neos} = [];
    foreach my $raw_item ( @{ $params->{json}{data} } ) {

        # start NEO record
        my %item;
        $item{des}   = $raw_item->[ $params->{fnum}{des} ];
        $item{cd}    = $raw_item->[ $params->{fnum}{cd} ];
        $item{v_rel} = int( $raw_item->[ $params->{fnum}{v_rel} ] + 0.5 );

        # distance computation
        foreach my $param_name (qw(dist dist_min dist_max)) {
            $item{$param_name} = get_dist_km( $param_name, $raw_item, $params );
        }

        # closest approact in local timezone (for mouseover text)
        my $cd_dt = DateTime::Format::Flexible->parse_datetime( $item{cd} . ":00 UTC" )
            ->set_time_zone($TIMEZONE);
        $item{cd_local} = dt2dttz($cd_dt);

        # background color computation based on distance
        $item{bgcolor} = dist2bgcolor( $item{dist} );

        # diameter is not always known - must deal with missing or null values
        $item{diameter} = get_diameter( $raw_item, $params );

        # cell background for diameter
        $item{diameter_bgcolor} = diameter2bgcolor( $item{diameter} );

        # save NASA NEO web URL
        $item{link} = $NEO_LINK_URL . URI::Escape::uri_escape_utf8( $item{des} );

        # save NEO record
        push @{ $params->{neos} }, \%item;
    }

    # process template
    my $config = {
        INCLUDE_PATH => $OUTDIR,    # or list ref
        INTERPOLATE  => 1,          # expand "$var" in plain text
        POST_CHOMP   => 1,          # cleanup whitespace
                                    #PRE_PROCESS  => 'header',        # prefix each template
        EVAL_PERL    => 0,          # evaluate Perl code blocks
    };
    my $template = Template->new($config);
    $template->process( $TEMPLATE, $params, $OUTDIR . "/" . $OUTHTML, binmode => ':utf8' )
        or croak "template processing error: " . $template->error();

    # in test mode, exit before messing with symlink or removing old files
    if ($TEST_MODE) {
        say "test mode: params=" . Dumper($params);
        exit 0;
    }

    # make a symlink to new data
    if ( -l $paths->{outlink} ) {
        unlink $paths->{outlink};
    }
    symlink basename( $paths->{outjson} ), $paths->{outlink}
        or croak "failed to symlink " . $paths->{outlink} . " to " . $paths->{outjson} . "; $!";

    # clean up old data files
    opendir( my $dh, $OUTDIR )
        or croak "Can't open $OUTDIR: $!";
    my @datafiles = sort { $b cmp $a } grep { /^ $OUTJSON -/x } readdir $dh;
    closedir $dh;
    if ( scalar @datafiles > 5 ) {
        splice @datafiles, 0, 5;
        foreach my $oldfile (@datafiles) {

            # double check we're only removing old JSON files
            next if ( ( substr $oldfile, 0, length($OUTJSON) ) ne $OUTJSON );

            my $delpath = "$OUTDIR/$oldfile";
            next if not -e $delpath;               # skip if the file doesn't exist
            next if ( ( -M $delpath ) < 0.65 );    # don't remove files newer than 15 hours

            is_interactive() and say "removing $delpath";
            unlink $delpath;
        }
    }

    return;
}

# run main and catch exceptions
try {
    main();
} catch ($e) {
    croak "error: $e";
}

