#!/usr/bin/perl
# generate ICal event data and a QR code image
# by Ian Kluft, 2020-08-31
# originally written for ISC² Silicon Valley Chapter meetings
# latest code at https://github.com/ikluft/ikluft-tools/tree/master/scripts
# Open Source terms: GNU General Public License v3.0 https://github.com/ikluft/ikluft-tools/blob/master/LICENSE
use Modern::Perl qw(2018); # includes strict and warnings
use autodie;
use Readonly;
use Carp qw(croak);
use Getopt::Long;
use DateTime;
use DateTime::Duration;
use Data::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::TimeZone;
use Data::ICal::DateTime;
use GD;
use IPC::Run;
use Data::Dumper;

# configuration
Readonly::Scalar my $pixel_size => 3;
Readonly::Scalar my $margin => 8;
Readonly::Scalar my $default_font => "FreeSans";
Readonly::Scalar my $default_size => 12;
Readonly::Scalar my $default_fgcolor_rgb => "000000";

# print usage and exit
sub usage
{
	say STDERR "usage: $0 --date=yyyy-mm-dd --time=hh:mm:ss --duration=minutes --description=text";
	say STDERR "  --organization=text --timezone=text [--location=text] [--conference=text] [--url=url]";
	say STDERR "  [--comment=text] [--qrcode=path] [--fgcolor] [--subtitle=text] [--subtitle-height=n]";
	say STDERR "  [--subtitle-font=font] [--subtitle-size=n] [--logo=path]";
	exit 1;
}

# process command line
my %options;
if (not GetOptions(\%options, "date=s", "time=s", "duration=s", "description=s", "organization=s", "timezone:s",
	"location:s", "conference:s", "url:s", "comment:s", "qrcode:s", "fgcolor:s", "subtitle:s@", "subtitle-height:i",
	"subtitle-font:s", "subtitle-size:i", "logo:s"))
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
	croak "missing required options: ".(join " ", @missing);
}
say STDERR "debug: options = ".Dumper(\%options);

# process date, time and duration
my @date = ($options{date} =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/);
if (not @date) {
	croak "date parsing failure";
}
my @time = ($options{time} =~ /^([0-9]{1,2}):([0-9]{2}):([0-9]{2})$/);
if (not @time) {
	croak "time parsing failure";
}
my $start = DateTime->new(
	year => $date[0], month => $date[1], day => $date[2],
	hour => $time[0], minute => $time[1], second => $time[2],
	time_zone => $options{timezone});
my $duration = DateTime::Duration->new(minutes => $options{duration});
say STDERR "debug: duration = ".Dumper($duration);
my $end = $start + $duration;

# build ICal object
my $ical = Data::ICal->new(auto_uid => 1);
my $zone = Data::ICal::TimeZone->new( timezone => $options{timezone} );
if (not $zone) {
	croak "failed to find timezone ".$options{timezone};
}
#$ical->add_event( $zone->definition );
my $event = Data::ICal::Entry::Event->new();
$event->start($start);
$event->end($end);
#$event->duration($duration);
my @properties = (
	class => 'PUBLIC',
    summary => $options{organization}.' meeting '.($start->ymd),
);
foreach my $optname (qw(description location conference url comment)) {
	if (exists $options{$optname}) {
		push @properties, $optname => $options{$optname};
	}
}
$event->add_properties(@properties);
$ical->add_entry($event);

# if only ICal output was selected, print the ICal object as text and exit
if (not exists $options{qrcode}) {
	say $ical->as_string;
	exit 0;
}

# get foreground color parameter or default value
my $fgcolor_rgb = $default_fgcolor_rgb;
if (exists $options{fgcolor}) {
	if ($options{fgcolor} =~ /^[0-9a-fA-F]{6}$/) {
		$fgcolor_rgb = uc($options{fgcolor});
	}
}

# generate QR code
my @cmd = (qw(/usr/bin/qrencode --type=PNG --level=M --output=-), "--size=$pixel_size",
	"--foreground=$fgcolor_rgb", "--margin=$margin");
my $in = $ical->as_string;
my $rawimg;
IPC::Run::run(\@cmd, '<', \$in, '>', \$rawimg)
	or croak "error in qrencode";

#
# add subtitle to QR code to describe what is in it
#

# collect data about QR code image
my $qr_in = GD::Image->newFromPngData($rawimg);
my $qr_in_width = $qr_in->width;
my $qr_in_height = $qr_in->height;
my $subtitle_height = $options{'subtitle-height'} // int($qr_in_height/4);
my $qr_out_height = $qr_in_height + $subtitle_height;

# create a larger image for the QR code and subtitle
my $qr_out = GD::Image->new($qr_in_width, $qr_out_height);
$qr_out->copy($qr_in, 0, 0, 0, 0, $qr_in_width, $qr_in_height);

# copy logo image if provided
my $logo_width = 0;
if (exists $options{logo}) {
	my $logo_img = GD::Image->new($options{logo});
	$logo_width = int($logo_img->width * ($subtitle_height/$logo_img->height));
	$qr_out->copyResized($logo_img, 0, $qr_in_height, 0, 0, $logo_width, $subtitle_height,
		$logo_img->width, $logo_img->height);
}

# add subtitle text in remainder of subtitle area
my $bgcolor = $qr_out->getPixel(0,0);
my $fgcolor = $qr_out->colorAllocate(hex(substr($fgcolor_rgb,0,2)),
	hex(substr($fgcolor_rgb,2,2)), hex(substr($fgcolor_rgb,4,2)));
my $subtitle_text = join("\n", @{$options{subtitle}});
my $subtitle_width = $qr_in_width - ($logo_width + $margin);

# draw subtitle text line by line
GD::Image->useFontConfig(1);
my $lines = scalar @{$options{subtitle}};
for (my $line=0; $line < $lines; $line++) {
	# test fit line to get its size
	# check if line font/size fits in its share of the subtitle area
	my $line_text = $options{subtitle}[$line];
	my @line_bounds = GD::Image->stringFT($fgcolor,
		$options{'subtitle-font'} // $default_font, $options{'subtitle-size'} // $default_size, 0,
		0, 0,
		$line_text);
	if (!@line_bounds) {
		croak "subtitle rendering error: $@ (test fit line $line)";
	}
	my $line_width = $line_bounds[2]-$line_bounds[6];
	my $line_height = $line_bounds[3]-$line_bounds[7];
	say STDERR "line $line width=$line_width height=$line_height";
	if ($line_height > $subtitle_height/$lines or $line_width > $subtitle_width) {
		croak "subtitle line $line too large in specified font and size";
	}

	my @bounds = $qr_out->stringFT($fgcolor,
		$options{'subtitle-font'} // $default_font, $options{'subtitle-size'} // $default_size, 0,
		$qr_in_width - $subtitle_width/2 - $line_width/2,
		$qr_out_height - $subtitle_height + $subtitle_height/$lines*($line+.5),
		$line_text);
	if (!@bounds) {
		croak "subtitle rendering error: $@ (line $line)";
	}
}

# output QR/subtitle image
open(my $out_fh, '>', $options{qrcode})
	or croak "failed to open QR code image file for writing: $!";
print $out_fh $qr_out->png
	or croak "failed to write to QR code image file: $!";
close $out_fh
	or croak "failed to close QR code image file: $!";
