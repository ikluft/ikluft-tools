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
use feature qw(say);
use Readonly;
use Carp qw(croak confess);
use File::Basename;
use FindBin;
use DateTime;
use IPC::Run;
use Getopt::Long;
use File::Slurp;
use IO::Interactive qw(is_interactive);
use JSON;
use Template;
use Data::Dumper;

# parse command-line
my %options;
GetOptions( \%options, "test|test_mode", "proxy:s" );

# constants
Readonly::Scalar my $TEST_MODE => $options{test}     // 0;
Readonly::Scalar my $PROXY     => $options{proxy}    // undef;
Readonly::Scalar my $TIMEZONE  => $options{timezone} // "UTC";
Readonly::Scalar my $TIMESTAMP => DateTime->now( time_zone => $TIMEZONE );
Readonly::Scalar my $SWPC_JSON_URL => "https://services.swpc.noaa.gov/products/alerts.json";
Readonly::Scalar my $OUTDIR   => $FindBin::Bin;
Readonly::Scalar my $OUTJSON  => "swpc-data.json";
Readonly::Scalar my $TEMPLATE => "noaa-swpc-alerts.tt";
Readonly::Scalar my $OUTHTML  => "noaa-swpc-alerts.html";
Readonly::Hash my %MONTH_NUM => (
    "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
    "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
    "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12,
);

# convert date string to DateTime object
sub datestr2dt
{
    my $date_str = shift;
    my ( $year, $mon_str, $day, $time, $zone ) = split qr(\s+)x, $date_str;
    if ( not exists $MONTH_NUM{$mon_str}) {
        croak "bad month '$mon_str' in date";
    }
    my $mon = int($MONTH_NUM{$mon_str});
    my $hour = int(substr($time, 0, 2));
    my $min = int(substr($time, 2, 2));
    return DateTime->new( year => int($year), mon => $mon, day => int($day), hour => $hour, min => $min,
        time_zone => $zone );
}

# perform SWPC request and save result in named file
sub do_swpc_request
{
    my ( $paths, $params ) = @_;

    # perform SWPC request
    if ($TEST_MODE) {
        if ( not -e $paths->{outlink} ) {
            croak "test mode requires $paths->{outlink} to exist";
        }
        say "*** skip network access in test mode ***";
    } else {
        my $url = sprintf $SWPC_JSON_URL, $params->{start_date};
        my ( $outstr, $errstr );
        my @cmd = ( "/usr/bin/curl", "--proxy", $PROXY, "--output", $paths->{outjson}, $url );
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

# template data & setup
my $params = {};
my $paths  = {};

# clear destination symlink
$paths->{outlink} = $OUTDIR . "/" . $OUTJSON;
if ( -e $paths->{outlink} ) {
    if ( not -l $paths->{outlink} ) {
        croak "destination file $paths->{outlink} is not a symlink";
    }
}
$paths->{outjson} = $paths->{outlink} . "-" . $TIMESTAMP;

# perform SWPC request
do_swpc_request( $paths, $params );

# read JSON into template data
# in case of JSON error, allow these to crash the program here before proceeding to symlinks
my $json_path = $TEST_MODE ? $paths->{outlink} : $paths->{outjson};
my $json_text = File::Slurp::read_file($json_path);
$params->{json} = JSON::from_json $json_text;

# convert response JSON data to template-able result
$params->{alerts} = [];
foreach my $raw_item ( @{ $params->{json}{data} } ) {
    # start SWPC alert record
    my %item;
    foreach my $key (keys %$raw_item) {
        $item{$key} = $raw_item->{$key};
    }
    $item{msg_data} = {};

    # decode message text info further data fields
    foreach my $msg_line (split "\r\n", $item{message}) {
        if ( $msg_line =~ /^([^-:]*)\s*[-:]\s*(.*)/x ) {
            $item{msg_data}{$1} = $2;
        }
    }

    # skip expired fields
    # TODO
}
