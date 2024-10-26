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
use JSON;
use URI::Escape;

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
Readonly::Scalar my $KM_IN_AU => 1.4959787e+08;
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

# TODO bring in functions from pull-nasa-neo.pl script here

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
    my $class = @_;

    # perform NEO query
    if ( $class->config_test_mode() ) {
        if ( not -e $class->paths( [ "outlink" ] ) ) {
            croak "test mode requires " . $class->paths( [ "outlink" ] ) . " to exist";
        }
        say "*** skip API access in test mode ***";
    } else {
        my $url = sprintf $NEO_API_URL, $class->params( [ "start_date" ] );
        my ( $outstr, $errstr );
        my $proxy = $class->config_proxy();
        my @cmd = (
            "/usr/bin/curl", "--silent", ( ( defined $proxy ) ? ( "--proxy", $proxy ) : () ),
            "--output", $class->paths( [ "outjson" ] ), $url
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
        if ( -z $class->paths( [ "outjson" ] ) ) {
            croak "JSON data file " . $class->paths( [ "outjson" ] ) . " is empty";
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

# get distance as km (convert from AU)
sub get_dist_km
{
    my ( $class, $param_name, $raw_item ) = @_;

    my $dist_au = $raw_item->[ $class->params( [ "fnum", $param_name ] ) ];
    my $dist_km = $dist_au * $KM_IN_AU;
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
    my ( $class, $raw_item ) = @_;

    # if diameter data was provided, use it
    my $fnum_diameter = $class->params( [ qw( fnum diameter ) ] );
    if (    ( exists $raw_item->[ $fnum_diameter ] )
        and ( defined $raw_item->[ $fnum_diameter ] )
        and ( $raw_item->[ $fnum_diameter ] ne "null" ) )
    {
        # diameter data found - format it with or without diameter_sigma
        my $diameter = "" . int( $raw_item->[ $fnum_diameter * 1000.0 ] + 0.5 );
        my $fnum_diameter_sigma = $class->params( [ qw( fnum diameter_sigma ) ] );
        if (    ( exists $raw_item->[ $fnum_diameter_sigma ] )
            and ( defined $raw_item->[ $fnum_diameter_sigma ] )
            and ( $raw_item->[ $fnum_diameter_sigma ] ne "null" ) )
        {
            $diameter .= " "
                . $UC_PLMIN . " "
                . int( $raw_item->[ $fnum_diameter_sigma ] * 1000.0 + 0.5 );
        }
        return $diameter;
    }

    # if magnitude data was provided, estimate diameter from it
    # according to API definition, h (absolute magnitude) should be provided
    my $fnum_h = $class->params( [ qw( fnum h ) ] );
    if (    ( exists $raw_item->[ $fnum_h ] )
        and ( defined $raw_item->[ $fnum_h ] )
        and ( $raw_item->[ $fnum_h ] ne "null" ) )
    {
        my $min = int( h_to_diameter_m( $raw_item->[ $fnum_h ], 0.25 ) + 0.5 );
        my $max = int( h_to_diameter_m( $raw_item->[ $fnum_h ], 0.05 ) + 0.5 );
        return $min . $UC_NDASH . $max;
    }

 # if diameter and magnitude were both unknown, deal with missing data by displaying a question mark
    return $UC_QMARK;
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

    # perform NEO query
    $class->do_neo_query();

    # read JSON into template data
    # in case of JSON error, allow these to crash the program here before proceeding to symlinks
    my $json_path = $class->config_test_mode()
        ? $class->paths( [ qw( outlink ) ] )
        : $class->paths( [ qw( outjson ) ] );
    my $json_text = File::Slurp::read_file($json_path);
    $class->params( [ "json" ], JSON::from_json $json_text );
    my $json_data = $class->params( [ qw( json data ) ] );

    # check API version number
    my $api_version = $class->params( [ qw( json signature version ) ] );
    if ( $api_version ne "1.5" ) {
        croak "API version changed to " . $api_version . " - code needs update to handle it";
    }

    # collect field names/numbers from JSON
    $class->params( [ "fnum" ], {} );
    my $fields_ref = $class->params( [ qw( json fields ) ] );
    for ( my $fnum = 0 ; $fnum < scalar @$fields_ref ; $fnum++ ) {
        $class->params( [ "fnum", $fields_ref->[$fnum] ], $fnum );
    }

    # convert API results to template-able list
    $class->params( [ "neos" ], [] );
    my $neos_ref = $class->params( [ "neos" ] );
    foreach my $raw_item ( @$json_data ) {

        # start NEO record
        my %item;
        $item{des}   = $raw_item->[ $class->params( [ qw( fnum des ) ] ) ];
        $item{cd}    = $raw_item->[ $class->params( [ qw( fnum cd ) ] ) ];
        $item{v_rel} = int( $raw_item->[ $class->params( [ qw( fnum v_rel ) ] ) ] + 0.5 );

        # distance computation
        foreach my $param_name (qw(dist dist_min dist_max)) {
            $item{$param_name} = $class->get_dist_km( $param_name, $raw_item, $class->params() );
        }

        # closest approact in local timezone (for mouseover text)
        my $cd_dt = DateTime::Format::Flexible->parse_datetime( $item{cd} . ":00 UTC" )
            ->set_time_zone( $class->config_timezone() );
        $item{cd_local} = dt2dttz($cd_dt);

        # background color computation based on distance
        $item{bgcolor} = dist2bgcolor( $item{dist} );

        # diameter is not always known - must deal with missing or null values
        $item{diameter} = $class->get_diameter( $raw_item, $class->params() );

        # cell background for diameter
        $item{diameter_bgcolor} = diameter2bgcolor( $item{diameter} );

        # save NASA NEO web URL
        $item{link} = $NEO_LINK_URL . URI::Escape::uri_escape_utf8( $item{des} );

        # save NEO record
        push @$neos_ref, \%item;
    }

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
