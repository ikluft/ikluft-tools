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
use Data::Dumper;
use FindBin;
use Set::Tiny;
use File::Slurp;
use JSON;

# constants
Readonly::Scalar my $SWPC_JSON_URL => "https://services.swpc.noaa.gov/products/alerts.json";
Readonly::Scalar my $OUTDIR        => $FindBin::Bin;
Readonly::Scalar my $OUTJSON       => "swpc-data.json";
Readonly::Scalar my $TEMPLATE      => "noaa-swpc-alerts.tt";
Readonly::Scalar my $OUTHTML       => "noaa-swpc-alerts.html";
Readonly::Scalar my $S_NONE        => "none";
Readonly::Scalar my $S_ACTIVE      => "active";
Readonly::Scalar my $S_INACTIVE    => "inactive";
Readonly::Scalar my $S_CANCEL      => "cancel";
Readonly::Scalar my $S_SUPERSEDE   => "supersede";
Readonly::Hash my %MONTH_NUM => (
    "jan" => 1,
    "feb" => 2,
    "mar" => 3,
    "apr" => 4,
    "may" => 5,
    "jun" => 6,
    "jul" => 7,
    "aug" => 8,
    "sep" => 9,
    "oct" => 10,
    "nov" => 11,
    "dec" => 12,
);
Readonly::Scalar my $ISSUE_HEADER      => "Issue Time";
Readonly::Scalar my $ORIG_ISSUE_HEADER => "Original Issue Time";
Readonly::Scalar my $SERIAL_HEADER     => "Serial Number";
Readonly::Array my @BEGIN_HEADERS => ( "Begin Time", "Valid From", );
Readonly::Array my @END_HEADERS => ( "Valid To", "End Time", "Now Valid Until", );
Readonly::Scalar my $EXTEND_SERIAL_HEADER => "Extension to Serial Number";
Readonly::Scalar my $CANCEL_SERIAL_HEADER => "Cancel Serial Number";
Readonly::Array my @INSTANTANEOUS_HEADERS =>
    ( "Threshold Reached", "Observed", "IP Shock Passage Observed", );
Readonly::Scalar my $HIGHEST_LEVEL_HEADER => "Highest Storm Level Predicted by Day";
Readonly::Scalar my $RETAIN_TIME          => 12;    # hours to keep items after expiration
Readonly::Array my @TITLE_KEYS => ( "SUMMARY", "ALERT", "WATCH", "WARNING", "EXTENDED WARNING" );
Readonly::Array my @LEVEL_COLORS =>
    ( "#bbb", "#F6EB14", "#FFC800", "#FF9600", "#FF0000", "#C80000" );    # NOAA scales

# in test mode, dump program status for debugging
sub test_dump
{
    my $class = shift;

    # in verbose mode, dump the params hash
    if (AlertGizmo::Config->verbose()) {
        say STDERR Dumper($params);
    }

    # in test mode, exit before messing with symlink or removing old files
    if ( $class->config_test_mode()) {
        my $params = $class->params();
        say 'test mode';
        say '* alert keys: ' . join( " ", sort keys %{ $params->{alerts} } );
        say '* active ' . join( " ", @{ $params->{active} } );
        say '* cancel: ' . join( " ", sort $params->{cancel}->elements() );
        say '* supersede: ' . join( " ", sort $params->{supersede}->elements() );

        # display active alerts
        foreach my $alert_serial ( @{ $params->{active} } ) {
            say "alert $alert_serial: " . Dumper( $params->{alerts}{$alert_serial} );
        }
        exit 0;
    }
    return;
}

# class method AlertGizmo (parent) calls before template processing
sub pre_template
{
    my $class = shift;

    # initialize globals
    $class->params( [ "timestamp" ], dt2dttz($class->config_timestamp()) );
    $class->params( [ "alerts" ], {} );
    $class->params( [ "cancel" ], Set::Tiny->new() );
    $class->params( [ "supersede" ], Set::Tiny->new() );

    # clear destination symlink
    my $outlink = $OUTDIR . "/" . $OUTJSON;
    $class->paths( [ "outlink" ], $outlink );
    if ( -e $outlink ) {
        if ( not -l $outlink ) {
            croak "destination file $outlink is not a symlink";
        }
    }
    my $outjson = $outlink . "-" . $class->config_timestamp();
    $class->paths( [ "outjson" ], $outjson );

    # perform SWPC request
    do_swpc_request();

    # read JSON into template data
    # in case of JSON error, allow these to crash the program here before proceeding to symlinks
    my $json_path = $class->config_test_mode() ? $outlink : $outjson;
    my $json_text = File::Slurp::read_file($json_path);
    $class->params( [ "json" ], JSON::from_json $json_text );

    # convert response JSON data to template-able result
    process_alerts();

    return;
}

# class method AlertGizmo (parent) called after template processing
sub post_template
{
    my $class = shift;

    # make a symlink to new data
    my $paths = $class->paths();
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
    if ( scalar @datafiles > 15 ) {
        splice @datafiles, 0, 15;
        foreach my $oldfile (@datafiles) {

            # double check we're only removing old JSON files
            next if ( ( substr $oldfile, 0, length($OUTJSON) ) ne $OUTJSON );

            my $delpath = "$OUTDIR/$oldfile";
            next if not -e $delpath;              # skip if the file doesn't exist
            next if ( ( -M $delpath ) < 1.5 );    # don't remove files newer than 36 hours

            is_interactive() and say "removing $delpath";
            unlink $delpath;
        }
    }
    return;
}

1;
