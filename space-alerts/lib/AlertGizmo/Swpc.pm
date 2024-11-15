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
use DateTime;
use DateTime::Duration;
use DateTime::Format::ISO8601;
use IPC::Run;
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
        say STDERR Dumper($class->params());
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

# perform SWPC request and save result in named file
sub do_swpc_request
{
    my $class = shift;
    my $paths = $class->paths();

    # perform SWPC request
    if ( $class->config_test_mode() ) {
        if ( not -e $paths->{outlink} ) {
            croak "test mode requires $paths->{outlink} to exist";
        }
        say STDERR "*** skip network access in test mode ***";
    } else {
        my $url = $SWPC_JSON_URL;
        my $proxy = $class->config_proxy();
        my ( $outstr, $errstr );
        my @cmd = (
            "/usr/bin/curl", "--silent", ( defined $proxy ? ( "--proxy", $proxy ) : () ),
            "--output", $paths->{outjson}, $url
        );
        IPC::Run::run( \@cmd, '<', \undef, '>', \$outstr, '2>', \$errstr );

        # check results of request
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
            say STDERR "stderr from command: $errstr";
            $class->params( [ "curl_stderr" ], $errstr );
        }
        if ($outstr) {
            say STDERR "stdout from command: $outstr";
            $class->params( [ "curl_stdout" ], $outstr );
        }
    }
    return;
}
# process alert data - extract message header information
sub process_alerts
{
    my $class = shift;
    my $params = $class->params();

    # convert response JSON data to template-able result
    foreach my $raw_item ( @{ $params->{json} } ) {

        # start SWPC alert record
        my %item;
        foreach my $key ( keys %$raw_item ) {
            $item{$key} = $raw_item->{$key};
        }

        # decode message text info further data fields - we can use msg_data after this point
        $class->parse_message( \%item );

        # save alert indexed by msgid
        my $msgid = $class->get_msgid( \%item );
        $item{derived}            = {};
        $item{derived}{id}        = $msgid;
        $params->{alerts}{$msgid} = \%item;

        # set initial status as none
        $item{derived}{status} = $S_NONE;

        # find and save title
        foreach my $title_key (@TITLE_KEYS) {
            if ( exists $item{msg_data}{$title_key} ) {
                $item{derived}{title} = $item{msg_data}{$title_key};
                last;
            }
        }
        $item{derived}{serial} = $item{msg_data}{$SERIAL_HEADER};

        # reformat and save issue time
        $item{derived}{issue} =
            DateTime::Format::ISO8601->format_datetime( $class->issue2dt( $item{issue_datetime} ) );

        # set row color based on NOAA scales
        $item{derived}{level} =
            0;    # default setting for no known NOAA alert level (will be colored gray)
        if ( ( exists $item{msg_data}{'NOAA Scale'} )
            and $item{msg_data}{'NOAA Scale'} =~ /^ [GMR] ([0-9]) \s/x )
        {
            $item{derived}{level} = int($1);
        } elsif ( ( exists $item{derived}{title} )
            and $item{derived}{title} =~ /Category \s [GMR] ([0-9]) \s/x )
        {
            $item{derived}{level} = int($1);
        }
        $item{derived}{bgcolor} = $LEVEL_COLORS[ $item{derived}{level} ];

        # save alert status - active, inactive, canceled, superseded
        $class->save_alert_status( \%item );
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
    $class->do_swpc_request();

    # read JSON into template data
    # in case of JSON error, allow these to crash the program here before proceeding to symlinks
    my $json_path = $class->config_test_mode() ? $outlink : $outjson;
    my $json_text = File::Slurp::read_file($json_path);
    $class->params( [ "json" ], JSON::from_json $json_text );

    # convert response JSON data to template-able result
    $class->process_alerts();

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
