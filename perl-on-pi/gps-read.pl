#!/usr/bin/perl
use strict;
use warnings;
use GPS::NMEA;

#use Data::Dumper;

my $gps = new GPS::NMEA( 'Port' => '/dev/ttyS0', 'Baud' => 9600 );

while (1) {
    $gps->parse;
    $gps->nmea_data_dump;

    #my ($sec,$min,$hour,$mday,$mon,$year) = $gps->get_time;
    #print "time ($sec,$min,$hour,$mday,$mon,$year)\n";
    #my ($ns,$lat,$ew,$lon) = $gps->get_position;
    #print "pos ($ns,$lat,$ew,$lon)\n";
    print "\n";
    sleep(5);
}
