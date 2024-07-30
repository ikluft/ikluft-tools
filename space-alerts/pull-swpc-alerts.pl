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
use Modern::Perl qw(2015);
use feature qw(say try);
use boolean ':all';
use Readonly;
use Carp qw(croak confess);
use File::Basename;
use FindBin;
use DateTime;
use DateTime::Duration;
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
GetOptions( \%options, "test|test_mode", "proxy:s", "timezone|tz:s" );

# global template data & config
my $paths  = {};
my $params = {};

# constants
Readonly::Scalar my $TEST_MODE => $options{test}     // 0;
Readonly::Scalar my $PROXY     => $options{proxy}    // $ENV{PROXY} // $ENV{SOCKS_PROXY};
Readonly::Scalar my $TIMEZONE  => $options{timezone} // "UTC";
Readonly::Scalar my $TIMESTAMP => DateTime->now( time_zone => $TIMEZONE );
Readonly::Scalar my $SWPC_JSON_URL => "https://services.swpc.noaa.gov/products/alerts.json";
Readonly::Scalar my $OUTDIR   => $FindBin::Bin;
Readonly::Scalar my $OUTJSON  => "swpc-data.json";
Readonly::Scalar my $TEMPLATE => "noaa-swpc-alerts.tt";
Readonly::Scalar my $OUTHTML  => "noaa-swpc-alerts.html";
Readonly::Hash   my %MONTH_NUM => (
    "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
    "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
    "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12,
);
Readonly::Scalar my $SERIAL_HEADER => "Serial Number";
Readonly::Scalar my $BEGIN_TIME_HEADER => "Begin Time";
Readonly::Scalar my $VALID_FROM_HEADER => "Valid From";
Readonly::Scalar my $VALID_TO_HEADER => "Valid To";
Readonly::Scalar my $END_TIME_HEADER => "End Time";
Readonly::Scalar my $EXTEND_TIME_HEADER => "Now Valid Until";
Readonly::Scalar my $EXTEND_SERIAL_HEADER => "Extension to Serial Number";
Readonly::Scalar my $CANCEL_SERIAL_HEADER => "Cancel Serial Number";
Readonly::Scalar my $THRESHOLD_REACHED_HEADER => "Threshold Reached";
Readonly::Scalar my $RETAIN_TIME => 48;  # hours to keep items with no end time (i.e. threshold reached alert)
Readonly::Array  my @TITLE_KEYS => ("SUMMARY", "ALERT", "WATCH", "WARNING", "EXTENDED WARNING");
Readonly::Array  my @LEVEL_COLORS => qw( #bbb #F6EB14 #FFC800 #FF9600 #FF0000 #C80000 ); # NOAA scales

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
        say "*** skip network access in test mode ***";
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
            say "stderr from command: $errstr";
        }
        if ($outstr) {
            say "stdout from command: $outstr";
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
        if ( $msg_lines[$line]  =~ /^\s*([^:]*)[:]\s*(.*)/x ) {
            $item_ref->{msg_data}{$1} = $2;
            $last_header = $1;
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

# set an alert as active
sub alert_active
{
    my $serial = shift;
    if ( not exists $params->{alerts}{$serial} ) {
        croak "attempt to set as active a non-existent alert: $serial";
    }

    # if a cancellation was issued for this serial number, do not activate it
    if ($params->{cancel}->contains($serial)) {
        $params->{active}->remove($serial);
        $params->{inactive}->remove($serial);
        return;
    }

    # if this serial number was superseded, do not activate it
    if ($params->{supersede}->contains($serial)) {
        $params->{active}->remove($serial);
        $params->{inactive}->remove($serial);
        return;
    }

    # set alert as active
    $params->{active}->insert($serial);
    if ($params->{inactive}->contains($serial)) {
        $params->{inactive}->remove($serial);
    }
    return;
}

# set an alert as inactive
sub alert_inactive
{
    my $serial = shift;
    if ( not exists $params->{alerts}{$serial} ) {
        croak "attempt to set as inactive a non-existent alert: $serial";
    }
    $params->{inactive}->insert($serial);
    if ($params->{active}->contains($serial)) {
        $params->{active}->remove($serial);
    }
    return;
}

# set an alert as canceled, which may be set before the record is read
sub alert_cancel
{
    my $serial = shift;
    $params->{cancel}->insert($serial);
    if ($params->{active}->contains($serial)) {
        $params->{active}->remove($serial);
    }
    return;
}

# set an alert as superseded, which may be set before the record is read
sub alert_supersede
{
    my $serial = shift;
    $params->{supersede}->insert($serial);
    if ($params->{active}->contains($serial)) {
        $params->{active}->remove($serial);
    }
    return;
}

# query status of an alert
sub alert_is_active { my $serial = shift; return $params->{active}->contains($serial); }
sub alert_is_inactive { my $serial = shift; return $params->{inactive}->contains($serial); }
sub alert_is_cancel { my $serial = shift; return $params->{cancel}->contains($serial); }
sub alert_is_supersede { my $serial = shift; return $params->{supersede}->contains($serial); }
sub alert_status
{
    my $serial = shift;
    my @states;
    foreach my $set_type ( qw(active inactive cancel supersede)) {
        if ( $params->{$set_type}->contains($serial)) {
            push @states, $set_type;
        }
    }
    return join(" ", @states);
}

# in test mode, dump program status for debugging
sub test_dump
{
    # in test mode, dump status then exit before messing with symlink or removing old files
    if ($TEST_MODE) {
        say 'test mode';
        say '* alert keys: '.join(" ", sort {$a <=> $b} keys %{$params->{alerts}});
        say '* active: '.join(" ", sort {$a <=> $b} $params->{active}->elements());
        say '* inactive: '.join(" ", sort {$a <=> $b} $params->{inactive}->elements());
        say '* cancel: '.join(" ", sort {$a <=> $b} $params->{cancel}->elements());
        say '* supersede: '.join(" ", sort {$a <=> $b} $params->{supersede}->elements());

        # display active alerts
        foreach my $alert_serial ( sort {$a <=> $b} $params->{active}->elements()) {
            say "alert $alert_serial: ".Dumper($params->{alerts}{$alert_serial});
        }
        exit 0;
    }
    return;
}

sub main
{
    # initialize globals
    $params->{timestamp} = dt2dttz($TIMESTAMP);
    $params->{alerts} = {};
    $params->{active} = Set::Tiny->new();
    $params->{inactive} = Set::Tiny->new();
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
    foreach my $raw_item ( @{ $params->{json} } ) {
        # start SWPC alert record
        my %item;
        foreach my $key (keys %$raw_item) {
            $item{$key} = $raw_item->{$key};
        }

        # decode message text info further data fields - we can use msg_data after this point
        parse_message(\%item);

        # save alert indexed by serial number
        if (not exists $item{msg_data}{$SERIAL_HEADER}) {
            # if no serial number then the record is not a valid alert
            next;
        }
        my $serial = $item{msg_data}{$SERIAL_HEADER};
        $item{derived} = {};
        $item{derived}{id} = $serial;  
        $params->{alerts}{$serial} = \%item;

        # find and save title
        foreach my $title_key ( @TITLE_KEYS ) {
            if ( exists $item{msg_data}{$title_key}) {
                $item{derived}{title} = $item{msg_data}{$title_key};
                last;
            }
        }

        # set row color based on NOAA scales
        $item{derived}{level} = 0; # default setting for no known NOAA alert level (will be colored gray)
        if (( exists $item{msg_data}{'NOAA Scale'}) and $item{msg_data}{'NOAA Scale'} =~ /^ [GMR] ([0-9]) \s/x ) {
            $item{derived}{level} = int($1);
        } elsif (( exists $item{derived}{title} ) and $item{derived}{title} =~ /Category \s [GMR] ([0-9]) \s/x ) {
            $item{derived}{level} = int($1);
        }
        $item{derived}{bgcolor} = $LEVEL_COLORS[$item{derived}{level}];

        # process cancellation of another serial number
        if ( exists $item{msg_data}{$CANCEL_SERIAL_HEADER}) {
            alert_cancel($item{msg_data}{$CANCEL_SERIAL_HEADER});
            alert_inactive($serial);
            next;
        }

        # process extension/superseding of another serial number
        if ( exists $item{msg_data}{$EXTEND_SERIAL_HEADER}) {
            alert_supersede($item{msg_data}{$EXTEND_SERIAL_HEADER});
        }

        # set status as active or inactive based on begin and expiration headers
        foreach my $begin_hdr ( $BEGIN_TIME_HEADER, $VALID_FROM_HEADER ) {
            if ( exists $item{msg_data}{$begin_hdr}) {
                my $begin_dt = datestr2dt($item{msg_data}{$begin_hdr});
                if (DateTime->compare(DateTime->now(), $begin_dt) < 0) {
                    # begin time has not yet been reached
                    alert_inactive($serial);
                    last;
                }
            }
        }
        foreach my $end_hdr ( $END_TIME_HEADER, $VALID_TO_HEADER, $EXTEND_TIME_HEADER ) {
            if ( exists $item{msg_data}{$end_hdr}) {
                my $end_dt = datestr2dt($item{msg_data}{$end_hdr});
                if (DateTime->compare(DateTime->now(), $end_dt) > 0) {
                    # expiration time has been reached
                    alert_inactive($serial);
                    last;
                }
            }
        }

        # set status active or inactive if threshold reached within $RETAIN_TIME hours ago
        if ( exists $item{msg_data}{$THRESHOLD_REACHED_HEADER}) {
            my $tr_dt = datestr2dt($item{msg_data}{$THRESHOLD_REACHED_HEADER});
            if (DateTime->compare(DateTime->now(), $tr_dt + DateTime::Duration->new(hours => $RETAIN_TIME)) > 0) {
                # expiration time has been reached
                alert_inactive($serial);
                last;
            }
        }
        if ( exists $item{msg_data}{$BEGIN_TIME_HEADER} and not exists $item{msg_data}{$END_TIME_HEADER}) {
            my $bt_dt = datestr2dt($item{msg_data}{$BEGIN_TIME_HEADER});
            if (DateTime->compare(DateTime->now(), $bt_dt + DateTime::Duration->new(hours => $RETAIN_TIME)) > 0) {
                # expiration time has been reached
                alert_inactive($serial);
                last;
            }
        }

        # activate the serial number if it is not expired or canceled
        if ( not alert_is_cancel($serial) and not alert_is_inactive($serial) and not alert_is_supersede($serial)) {
            alert_active($serial);
        }
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

# run main

main();
