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

# globals
my ($debug, @before, @after, @path, %path);
my $var = "PATH";

# fetch before/after path elements from command line
GetOptions("debug" => \$debug, "before:s" => \@before, "after:s" => \@after, "var:s" => \$var);

# load before/path/after elements and deduplicate
foreach my $dir (map {split /:/, $_} @before, ($ENV{$var} // ()), @after) {
    $debug and say STDERR "debug: found $dir";
	if ($dir eq "." ) {
        # omit "." for good security practice
        next;
    }

    # add the path if it hasn't already been seen, and it exists
	if (not exists $path{$dir} and -d $dir) {
        push @path, $dir;
        $debug and say STDERR "debug: pushed $dir";
	}
	$path{$dir} = 1;
}
say join ":", @path;
