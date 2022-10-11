#!/usr/bin/env perl 
#===============================================================================
#         FILE: pathfilter.pl
#        USAGE: ./pathfilter.pl  
#  DESCRIPTION: add to Unix PATH with deduplication
#        USAGE: pathfilter.pl [--before dir:dir:dir]  [--after dir:dir:dir]
#       AUTHOR: IKLUFT 
#      CREATED: 04/26/2021 04:19:20 PM
#===============================================================================

use strict;
use warnings;
use 5.24.0;
use utf8;
use Getopt::Long;
use Cwd qw(abs_path);

# globals
my ($debug, @before, @after, @path, %path);
my $var = "PATH";
my $delimiter = ":";

# fetch before/after path elements from command line
GetOptions("debug" => \$debug, "before:s" => \@before, "after:s" => \@after, "var:s" => \$var,
    "delimiter:s" => \$delimiter);

# load before/path/after elements and deduplicate
foreach my $dir (map {split /$delimiter/x, $_} @before, ($ENV{$var} // ()), @after) {
    $debug and say STDERR "debug: found $dir";
	if ($dir eq "." ) {
        # omit "." for good security practice
        next;
    }

    # skip if the path doesn't exist or isn't a directory
    if (not -e $dir or not -d $dir) {
        next
    }

    # convert to canonical path
    my $abs_dir = abs_path($dir);

    # add the path if it hasn't already been seen, and it exists
	if (not exists $path{$abs_dir} and -d $abs_dir) {
        push @path, $abs_dir;
        $debug and say STDERR "debug: pushed $abs_dir";
	}
	$path{$abs_dir} = 1;
}
say join $delimiter, @path;
