#!/usr/bin/perl
# generate ICal event data for ISC² Silicon Valley Chapter meetings
# by Ian Kluft, 2020-08-31
use Modern::Perl qw(2018); # includes strict and warnings
use autodie;
use Readonly;
use Getopt::Long;
use DateTime;
use DateTime::Duration;
use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::TimeZone;
use Data::ICal::DateTime;
use IPC::Run;
use Data::Dumper;

# configuration
Readonly::Scalar my $timezone => "America/Los_Angeles";
Readonly::Scalar my $organization => "ISC² Silicon Valley Chapter";

# print usage and exit
sub usage
{
	say STDERR "usage: $0 --date=yyyy-mm-dd --time=hh:mm:ss --duration='n hours' --description=text";
	say STDERR "  [--location=text] [--conference=text] [--url=url] [--comment=text]";
	exit 1;
}

# process command line
my %options;
if (not GetOptions(\%options, "date=s", "time=s", "duration=s", "description=s", "qrcode:s", "location:s",
	"conference:s", "url:s", "comment:s"))
{
	usage();
}
my @missing;
foreach my $optname (qw(date time duration description)) {
	if (not exists $options{$optname}) {
		push @missing, $optname;
	}
}
if (@missing) {
	die "missing required options: ".(join " ", @missing);
}
say STDERR "debug: options = ".Dumper(\%options);

# process date, time and duration
my @date = ($options{date} =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/);
if (not @date) {
	die "date parsing failure";
}
my @time = ($options{time} =~ /^([0-9]{1,2}):([0-9]{2}):([0-9]{2})$/);
if (not @time) {
	die "time parsing failure";
}
my $start = DateTime->new(
	year => $date[0], month => $date[1], day => $date[2],
	hour => $time[0], minute => $time[1], second => $time[2],
	time_zone => $timezone);
my $duration = DateTime::Duration->new(minutes => $options{duration});
say STDERR "debug: duration = ".Dumper($duration);
my $end = $start + $duration;

# build ICal object
my $ical = Data::ICal->new(auto_uid => 1);
my $zone = Data::ICal::TimeZone->new( timezone => $timezone );
if (not $zone) {
	die "failed to find timezone $timezone";
}
#$ical->add_event( $zone->definition );
my $event = Data::ICal::Entry::Event->new();
$event->start($start);
$event->end($end);
#$event->duration($duration);
my @properties = (
	class => 'PUBLIC',
    summary => $organization.' meeting '.($start->ymd),
);
foreach my $optname (qw(description location conference url comment)) {
	if (exists $options{$optname}) {
		push @properties, $optname => $options{$optname};
	}
}
$event->add_properties(@properties);
$ical->add_entry($event);

# print the ICal object as text or a QR code
if (exists $options{qrcode}) {
	my @cmd = (qw(/usr/bin/qrencode --type=PNG --size=3 --margin=8 --level=M), "--output=".$options{qrcode});
	my $in = $ical->as_string;
	IPC::Run::run(\@cmd, '<', \$in)
		or die "error in qrencode";
} else {
	say $ical->as_string;
}
