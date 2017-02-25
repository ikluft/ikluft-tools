#!/usr/bin/perl
use strict;
use warnings;
use Device::SerialPort;

my $STALL_DEFAULT=300; # how many seconds to wait for new input
my $timeout=$STALL_DEFAULT;

my $port=Device::SerialPort->new("/dev/ttyS0");

$port->baudrate(9600);
$port->parity("none");
$port->databits(8);
$port->stopbits(1);
$port->handshake("none");
$port->read_char_time(0);     # don't wait for each character
$port->read_const_time(1000); # 1 second per unfulfilled "read" call
$port->write_settings;

my $chars=0;
my $buffer="";
while ($timeout>0) {
	my ($count,$saw)=$port->read(255); # will read _up to_ 255 chars
	if ($count > 0) {
		$chars+=$count;
		$buffer.=$saw;
		print $saw;
	} else {
		$timeout--;
	}
}

if ($timeout==0) {
	die "Waited $STALL_DEFAULT seconds - timed out waiting for input\n";
}
