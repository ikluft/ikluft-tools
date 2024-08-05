#!/usr/bin/env perl
#===============================================================================
#         FILE: pull-swpc-alerts.pl
#        USAGE: ./pull-swpc-alerts.pl  
#  DESCRIPTION: 
#       AUTHOR: Ian Kluft (IKLUFT), ikluft@cpan.org
#      CREATED: 07/17/2024 07:57:08 PM
#===============================================================================

use strict;
use warnings;
use utf8;
use autodie;
use Modern::Perl qw(2023);  # Perl 5.36 allows built-in boolean types
use experimental qw(builtin);
use builtin qw(true false);
use Readonly;
use Carp qw(croak confess);
use File::Basename;
use FindBin;
use DateTime;
use DateTime::Duration;
use DateTime::Format::ISO8601;
use IPC::Run;
use Getopt::Long;
use Set::Tiny;
use File::Slurp;
use IO::Interactive qw(is_interactive);
use JSON;
use Template;
use Data::Dumper;

# parse command-line
my %options;
GetOptions( \%options, "test|test_mode", "verbose", "proxy:s", "timezone|tz:s" );

# global template data & config
my $paths  = {};
my $params = {};
my %msgid;

# constants
Readonly::Scalar my $TEST_MODE => $options{test}       // false;
Readonly::Scalar my $VERBOSE_MODE => $options{verbose} // false;
Readonly::Scalar my $PROXY     => $options{proxy}      // $ENV{PROXY} // $ENV{SOCKS_PROXY};
Readonly::Scalar my $TIMEZONE  => $options{timezone}   // "UTC";
Readonly::Scalar my $TIMESTAMP => DateTime->now( time_zone => $TIMEZONE );
Readonly::Scalar my $SWPC_JSON_URL => "https://services.swpc.noaa.gov/products/alerts.json";
Readonly::Scalar my $OUTDIR   => $FindBin::Bin;
Readonly::Scalar my $OUTJSON  => "swpc-data.json";
Readonly::Scalar my $TEMPLATE => "noaa-swpc-alerts.tt";
Readonly::Scalar my $OUTHTML  => "noaa-swpc-alerts.html";
Readonly::Scalar my $S_NONE   => "none";
Readonly::Scalar my $S_ACTIVE => "active";
Readonly::Scalar my $S_INACTIVE => "inactive";
Readonly::Scalar my $S_CANCEL => "cancel";
Readonly::Scalar my $S_SUPERSEDE => "supersede";
Readonly::Hash   my %MONTH_NUM => (
    "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
    "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
    "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12,
);
Readonly::Scalar my $ISSUE_HEADER => "Issue Time";
Readonly::Scalar my $ORIG_ISSUE_HEADER => "Original Issue Time";
Readonly::Scalar my $SERIAL_HEADER => "Serial Number";
Readonly::Array  my @BEGIN_HEADERS => (
    "Begin Time",
    "Valid From",
);
Readonly::Array my @END_HEADERS => (
    "Valid To",
    "End Time",
    "Now Valid Until",
);
Readonly::Scalar my $EXTEND_SERIAL_HEADER => "Extension to Serial Number";
Readonly::Scalar my $CANCEL_SERIAL_HEADER => "Cancel Serial Number";
Readonly::Array  my @INSTANTANEOUS_HEADERS => (
    "Threshold Reached",
    "Observed",
    "IP Shock Passage Observed",
);
Readonly::Scalar my $HIGHEST_LEVEL_HEADER => "Highest Storm Level Predicted by Day";
Readonly::Scalar my $RETAIN_TIME => 6;  # hours to keep items after expiration
Readonly::Array  my @TITLE_KEYS => ("SUMMARY", "ALERT", "WATCH", "WARNING", "EXTENDED WARNING");
Readonly::Array  my @LEVEL_COLORS => ( "#bbb", "#F6EB14", "#FFC800", "#FF9600", "#FF0000", "#C80000" ); # NOAA scales

# convert date string to DateTime object
sub datestr2dt
{
    my $date_str = shift;
    my ( $year, $mon_str, $day, $time, $zone ) = split qr(\s+)x, $date_str;
    if ( not exists $MONTH_NUM{lc $mon_str}) {
        croak "bad month '$mon_str' in date";
    }
    my $mon = int($MONTH_NUM{lc $mon_str});
    my $hour = int(substr($time, 0, 2));
    my $min = int(substr($time, 2, 2));
    return DateTime->new( year => int($year), month => $mon, day => int($day), hour => $hour, minute => $min,
        time_zone => $zone );
}

# convert issue time to DateTime
sub issue2dt
{
    my $date_str = shift;
    my ( $year, $mon, $day, $hour, $min, $sec ) = split qr([-:\s])x, $date_str;
    return DateTime->new( year => int($year), month => $mon, day => int($day), hour => $hour, minute => $min,
        second => int($sec), time_zone => "UTC" );
}

# convert DateTime to date/time/tz string
sub dt2dttz
{
    my $dt = shift;
    return $dt->ymd('-') . " " . $dt->hms(':') . " " . $dt->time_zone_short_name();
}

# perform SWPC request and save result in named file
sub do_swpc_request
{
    # perform SWPC request
    if ($TEST_MODE) {
        if ( not -e $paths->{outlink} ) {
            croak "test mode requires $paths->{outlink} to exist";
        }
        say STDERR "*** skip network access in test mode ***";
    } else {
        my $url = $SWPC_JSON_URL;
        my ( $outstr, $errstr );
        my @cmd = ( "/usr/bin/curl", "--silent", ( defined $PROXY ? ( "--proxy", $PROXY ) : ()),
            "--output", $paths->{outjson}, $url );
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
            $params->{curl_stderr} = $errstr;
        }
        if ($outstr) {
            say STDERR "stdout from command: $outstr";
            $params->{curl_stdout} = $outstr;
        }
    }
    return;
}

# parse a message entry
sub parse_message
{
    my $item_ref = shift;

    # decode message text info further data fields
    $item_ref->{msg_data} = {};
    my @msg_lines = split "\r\n", $item_ref->{message};
    my $last_header;
    for ( my $line=0; $line <= scalar @msg_lines; $line++ ) {
        if (( not defined $msg_lines[$line] ) or ( length($msg_lines[$line]) == 0 )) {
            undef $last_header;
            next;
        }
        if ( $msg_lines[$line]  =~ /^ \s* ([^:]*) : \s* (.*)/x ) {
            my ( $key, $value ) = ( $1, $2 );
            $item_ref->{msg_data}{$key} = $value;
            $last_header = $key;

            # check for continuation line (ends with ':')
            if ( $msg_lines[$line]  =~ /^ \s* [^:]* : $/x ) {
                # bring in next line for continuation
                if ( exists $msg_lines[$line+1]) {
                    $item_ref->{msg_data}{$key} = $msg_lines[$line+1];
                    $line++;
                }
            }
            next;
        }
        if ( defined $last_header ) {
            $item_ref->{msg_data}{$last_header} .= "\n".$msg_lines[$line];
        } else {
            if ( exists $item_ref->{msg_data}{notes}) {
                $item_ref->{msg_data}{notes} .= "\n".$msg_lines[$line];
            } else {
                $item_ref->{msg_data}{notes} = $msg_lines[$line];
            }
        }
    }
    return;
}

# get an internal message id number from an alert (because Serial Number header turned out not to be unique)
sub get_msgid
{
    my $item_ref = shift;
    my $serial = $item_ref->{msg_data}{$SERIAL_HEADER};
    my $issue = $item_ref->{msg_data}{$ISSUE_HEADER};
    my $msg_key = $serial."_".$issue;
    if ( exists $msgid{$msg_key}) {
        return $msgid{$msg_key};
    }

    # generate new msgid
    my $msg_count = scalar keys %msgid;
    my $new_msgid = sprintf "%04x", $msg_count;
    if ( exists $msgid{$new_msgid}) {
        say STDERR "data dump due to non-unique msgid $new_msgid:";
        say STDERR Dumper($params);
        confess "message id $new_msgid already exists when it should be uniquely new";
    }
    $msgid{$msg_key} = $new_msgid;
    return $new_msgid;
}

# set status of an alert
sub alert_set
{
    my ( $msgid, $state_str ) = @_;
    if ( not exists $params->{alerts}{$msgid} ) {
        croak "attempt to set as $state_str a non-existent alert: $msgid";
    }
    my $alert = $params->{alerts}{$msgid};
    my $serial = $alert->{msg_data}{$SERIAL_HEADER};

    # skip if serial number is marked as canceled or superseded
    if ($params->{cancel}->contains($serial)) {
        $alert->{derived}{status} = $S_CANCEL;
        return;
    }
    if ($params->{supersede}->contains($serial)) {
        $alert->{derived}{status} = $S_SUPERSEDE;
        return;
    }

    # set alert state
    $alert->{derived}{status} = $state_str;
    return;

}

# set an alert as active
sub alert_set_active
{
    my $msgid = shift;
    alert_set( $msgid, $S_ACTIVE );
    return;
}

# set an alert as inactive
sub alert_set_inactive
{
    my $msgid = shift;
    alert_set( $msgid, $S_INACTIVE );
    return;
}

# set an alert as canceled
sub alert_set_cancel
{
    my $msgid = shift;
    alert_set( $msgid, $S_CANCEL );
    return;
}

# set an alert as superseded
sub alert_set_supersede
{
    my $msgid = shift;
    alert_set( $msgid, $S_SUPERSEDE );
    return;
}

# set a serial number as canceled, which may be set before the alert is read
sub serial_cancel
{
    my $serial = shift;

    # add msgid to cancel set
    $params->{cancel}->insert($serial);
    return;
}

# set a serial number as superseded, which may be set before the alert is read
sub serial_supersede
{
    my $serial = shift;

    # add msgid to supersede set
    $params->{supersede}->insert($serial);
    return;
}

# query status of an alert
sub alert_is {
    my ( $msgid, $state_str ) = @_;
    my $alert = $params->{alerts}{$msgid};
    return $alert->{derived}{status} eq $state_str;
}
sub alert_is_none { my $msgid = shift; return alert_is( $msgid, $S_NONE ); }
sub alert_is_active { my $msgid = shift; return alert_is( $msgid, $S_ACTIVE ); }
sub alert_is_inactive { my $msgid = shift; return alert_is( $msgid, $S_INACTIVE ); }
sub alert_is_cancel { my $msgid = shift; return alert_is( $msgid, $S_CANCEL ); }
sub alert_is_supersede { my $msgid = shift; return alert_is( $msgid, $S_SUPERSEDE ); }

# save list of active alert msgid's
sub save_active_alerts
{
    $params->{active} = [ sort grep { alert_is_active($_) } keys %{$params->{alerts}}];
    return;
}

# in test mode, dump program status for debugging
sub test_dump
{
    # in verbose mode, dump the params hash
    if ( $VERBOSE_MODE ) {
        say STDERR Dumper($params);
    }

    # in test mode, dump status then exit before messing with symlink or removing old files
    if ($TEST_MODE) {
        say 'test mode';
        say '* alert keys: '.join(" ", sort keys %{$params->{alerts}});
        say '* active '.join(" ", @{$params->{active}});
        say '* cancel: '.join(" ", sort $params->{cancel}->elements());
        say '* supersede: '.join(" ", sort $params->{supersede}->elements());

        # display active alerts
        foreach my $alert_serial ( @{$params->{active}}) {
            say "alert $alert_serial: ".Dumper($params->{alerts}{$alert_serial});
        }
        exit 0;
    }
    return;
}

# if 'Highest Storm Level Predicted by Day' is set, use those dates for effective times
sub date_from_level_forecast
{
    my ( $item_ref ) = @_;
    if ( exists $item_ref->{msg_data}{$HIGHEST_LEVEL_HEADER}) {
        my $forecast_line = $item_ref->{msg_data}{$HIGHEST_LEVEL_HEADER};
        my @matches = ( $forecast_line =~ /([A-Z][a-z][a-z] \s+ [0-9]+ : \s+ [^\s]+ \s+ \([^\)]+\))/gx );
        my $last_date;
        foreach my $by_day ( @matches ) {
            if ( $by_day =~ /([A-Z][a-z][a-z]) \s+ ([0-9]+) : \s+ ([^\s]+) \s+ \([^\)]+\)/x ) {
                my $mon = int($MONTH_NUM{lc $1}) // "";
                my $day = int($2);
                my $mag = $3;
                if ( $mag ne "None" and $mon ) {
                    $last_date = [ $mon, $day ];
                }
            }
        }
        if ( defined $last_date ) {
            my $issue_dt = issue2dt($item_ref->{issue_datetime});
            my $issue_year = $issue_dt->year();
            my $issue_month = $issue_dt->month();
            my $expire_year = $issue_year + (( $issue_month == 12 and $last_date->[0] == 1 ) ? 1 : 0 );
            my $expire_dt = DateTime->new( year => $expire_year, month => $last_date->[0], day => $last_date->[1],
                hour => 23, minute => 59, time_zone => 'UTC' );
            $item_ref->{derived}{end} = $expire_dt->stringify();
        }
    }
    return;
}

# save alert status - active, inactive, canceled, superseded
sub save_alert_status
{
    my ( $item_ref ) = @_;
    my $msgid = $item_ref->{derived}{id};
    my $serial = $item_ref->{msg_data}{$SERIAL_HEADER};

    # check if serial number is marked as canceled or superseded
    if ($params->{cancel}->contains($serial)) {
        alert_set_cancel($msgid);
        return;
    }
    if ($params->{supersede}->contains($serial)) {
        alert_set_supersede($msgid);
        return;
    }

    # process cancellation of another serial number
    if ( exists $item_ref->{msg_data}{$CANCEL_SERIAL_HEADER}) {
        serial_cancel($item_ref->{msg_data}{$CANCEL_SERIAL_HEADER});
        alert_set_inactive($msgid);
        return;
    }

    # process extension/superseding of another serial number
    if ( exists $item_ref->{msg_data}{$EXTEND_SERIAL_HEADER}) {
        serial_supersede($item_ref->{msg_data}{$EXTEND_SERIAL_HEADER});
    }

    # set begin and expiration times based on various headers to that effect
    foreach my $begin_hdr ( @BEGIN_HEADERS ) {
        if ( exists $item_ref->{msg_data}{$begin_hdr}) {
            my $begin_dt = datestr2dt($item_ref->{msg_data}{$begin_hdr});
            $item_ref->{derived}{begin} = $begin_dt->stringify();
            last;
        }
    }
    foreach my $end_hdr ( @END_HEADERS ) {
        if ( exists $item_ref->{msg_data}{$end_hdr}) {
            my $end_dt = datestr2dt($item_ref->{msg_data}{$end_hdr});
            $item_ref->{derived}{end} = $end_dt->stringify();
            last;
        }
    }

    # set times for instantaneous events
    foreach my $instant_hdr ( @INSTANTANEOUS_HEADERS ) {
        if ( exists $item_ref->{msg_data}{$instant_hdr}) {
            my $tr_dt = datestr2dt($item_ref->{msg_data}{$instant_hdr});
            $item_ref->{derived}{end} = $tr_dt->stringify();
            last;
        }
    }

    # if end time was set but no begin, use issue time
    if (( not exists $item_ref->{derived}{begin}) and ( exists $item_ref->{derived}{end})) {
        $item_ref->{derived}{begin} = issue2dt($item_ref->{issue_datetime})->stringify();
    }

    # if begin time was set but no end, copy begin time to end time
    if (( exists $item_ref->{derived}{begin}) and ( not exists $item_ref->{derived}{end})) {
        $item_ref->{derived}{end} = $item_ref->{derived}{begin};
    }

    # if 'Highest Storm Level Predicted by Day' is set, use those dates for effective times
    date_from_level_forecast($item_ref);

    # set status as inactive if outside begin and end times
    if ( exists $item_ref->{derived}{begin}) {
        my $begin_dt = DateTime::Format::ISO8601->parse_datetime($item_ref->{derived}{begin});
        if ($TIMESTAMP < $begin_dt) {
            # begin time has not yet been reached
            alert_set_inactive($msgid);
        }
    }
    if ( exists $item_ref->{derived}{end}) {
        my $end_dt = DateTime::Format::ISO8601->parse_datetime($item_ref->{derived}{end})
            + DateTime::Duration->new(hours => $RETAIN_TIME);
        if ($TIMESTAMP > $end_dt) {
            # expiration time has been reached
            alert_set_inactive($msgid);
        }
    }

    # activate the serial number if it is not expired, canceled or superseded
    if ( alert_is_none($msgid)) {
        alert_set_active($msgid);
    }

    # save sorted list of active alerts
    save_active_alerts();
    return;
}

# process alert data - extract message header information
sub process_alerts
{
    # convert response JSON data to template-able result
    foreach my $raw_item ( @{ $params->{json} } ) {
        # start SWPC alert record
        my %item;
        foreach my $key (keys %$raw_item) {
            $item{$key} = $raw_item->{$key};
        }

        # decode message text info further data fields - we can use msg_data after this point
        parse_message(\%item);

        # save alert indexed by msgid
        my $msgid = get_msgid(\%item);
        $item{derived} = {};
        $item{derived}{id} = $msgid;
        $params->{alerts}{$msgid} = \%item;

        # set initial status as none
        $item{derived}{status} = $S_NONE;

        # find and save title
        foreach my $title_key ( @TITLE_KEYS ) {
            if ( exists $item{msg_data}{$title_key}) {
                $item{derived}{title} = $item{msg_data}{$title_key};
                last;
            }
        }
        $item{derived}{serial} = $item{msg_data}{$SERIAL_HEADER};

        # save serial number

        # set row color based on NOAA scales
        $item{derived}{level} = 0; # default setting for no known NOAA alert level (will be colored gray)
        if (( exists $item{msg_data}{'NOAA Scale'}) and $item{msg_data}{'NOAA Scale'} =~ /^ [GMR] ([0-9]) \s/x ) {
            $item{derived}{level} = int($1);
        } elsif (( exists $item{derived}{title} ) and $item{derived}{title} =~ /Category \s [GMR] ([0-9]) \s/x ) {
            $item{derived}{level} = int($1);
        }
        $item{derived}{bgcolor} = $LEVEL_COLORS[$item{derived}{level}];

        # save alert status - active, inactive, canceled, superseded
        save_alert_status(\%item);
    }

    return;
}

sub main
{
    # initialize globals
    $params->{timestamp} = dt2dttz($TIMESTAMP);
    $params->{alerts} = {};
    $params->{cancel} = Set::Tiny->new();
    $params->{supersede} = Set::Tiny->new();

    # clear destination symlink
    $paths->{outlink} = $OUTDIR . "/" . $OUTJSON;
    if ( -e $paths->{outlink} ) {
        if ( not -l $paths->{outlink} ) {
            croak "destination file $paths->{outlink} is not a symlink";
        }
    }
    $paths->{outjson} = $paths->{outlink} . "-" . $TIMESTAMP;

    # perform SWPC request
    do_swpc_request();

    # read JSON into template data
    # in case of JSON error, allow these to crash the program here before proceeding to symlinks
    my $json_path = $TEST_MODE ? $paths->{outlink} : $paths->{outjson};
    my $json_text = File::Slurp::read_file($json_path);
    $params->{json} = JSON::from_json $json_text;

    # convert response JSON data to template-able result
    process_alerts();

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

    # in test mode, dump program status for debugging
    test_dump();

    # make a symlink to new data
    if ( -l $paths->{outlink} ) {
        unlink $paths->{outlink};
    }
    symlink basename($paths->{outjson}), $paths->{outlink}
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
            next if not -e $delpath;               # skip if the file doesn't exist
            next if ( ( -M $delpath ) < 1.5 );     # don't remove files newer than 36 hours

            is_interactive() and say "removing $delpath";
            unlink $delpath;
        }
    }

    return;
}

# run main

main();
