#!/usr/bin/perl 
# flatpak-aliases.pl - generate shell aliases to run all installed Linux Flatpaks from the command line
#
# Copyright 2018-2020 by Ian Kluft
# released as Open Source Software under the GNU General Public License Version 3.
# See https://www.gnu.org/licenses/gpl.txt
#
# Current source code for this script can be found at
# https://github.com/ikluft/ikluft-tools/blob/master/scripts/flatpak-aliases.pl
#
# This script requires Flatpak on a Linux system. See https://flatpak.org/ for more info.
#
# Installation:
# 1) Put this somewhere your .bash_profile or .bashrc can get to it. It doesn't have to be in your $PATH.
#    For this example I've put it in ~/bin because it's a place to look for user-installed programs.
#    Adjust the paths from the examples to fit where you installed it.
#
# 2) Edit the script if needed so that the first line (starting with #!) points to your Perl interpreter.
#    For most Linux distributions, it should already be correct.
#
# 3) Make it executable: (adjust the path as needed for your installation)
#    chmod u=rwx,go=rx ~/bin/flatpak-aliases.pl
#
# 4) Then add this line to your ~/.bashrc script: (adjust the path as needed for your installation)
#    eval $(~/bin/flatpak-aliases.pl)
#
# Step #4 will take effect as each shell starts. But the aliases aren't defined in shells running prior to this edit.
# You may run that command in a currently-running shell, in order to define aliases for your flatpaks.

use strict;
use warnings;
use utf8;
use v5.18;	# require Perl 5.18 (2014) or later so the script can use "say" and other recent features
use Getopt::Long;

#
# configuration
#
my $debug;
my @min_path = qw(/sbin /usr/sbin /usr/bin /bin);
my @prognames = qw(flatpak);
my %prog;
foreach my $progname (@prognames) {
	foreach my $dir (@min_path) {
		if (-x "$dir/$progname") {
			$prog{$progname} = "$dir/$progname";
			last;
		}
	}
}

#
# debugging functions
#
sub debug
{
	if ($debug) {
		say STDERR "debug: ".join(" ", @_);
	}
}

sub dumpenv
{
	if ($debug) {
		say STDERR "environment:";
		foreach my $var (sort keys %ENV) {
			say STDERR "    ".$var." = ".$ENV{$var};
		}
	}

}

#
# command-line processing
#
if (! GetOptions("debug" => \$debug)) {
	die "usage: $0 [--debug]";
}

#
# check for error conditions
#

# detect if we're running in a flatpak container (may have been launched from ~/.bashrc inside the container)
# flatpak executable will not exist inside the container - handle that gracefully
if (! exists $prog{flatpak}) {
	# check environment for a container indicator
	foreach my $var (qw(FLATPAK_ID container)) {
		if (exists $ENV{$var}) {
			# we can't find flatpak because we're in a container - exit without complaint or error
			debug "running in $ENV{$var} - no flatpak processing necessary";
			exit 0;
		}
	}

	# we don't seem to be in a container - maybe flatpak needs to be installed
	dumpenv; # if debugging is turned on, this will dump the environment for indications what happened
	die "flatpak program not found - see https://flatpak.org/ for installation instructions";
}

#
# process flatpak list
#

# collect list of installed Flatpaks from both system-wide and user-specific installations
# note: this only considers apps, not runtimes - that's what makes sense to run from the command-line
my %flatpaks;
open( my $pipefh, "-|", $prog{flatpak}." list --app --columns=application" )
	|| die "$0: pipe open failed: $!";
my $linenum=0;
while (<$pipefh>) {
	if ($linenum++ == 0 and /Application ID/) {
		next; # skip heading
	}
	chomp;
	if ( m=^([^/]+)= ) {
		$flatpaks{$1} = 1;
	}
}
close $pipefh
	|| die "$0: pipe close failed: $!";

#
# print aliases for shell
#

# process each Flatpak app that was found
# Make a shell function for the full identifier name which runs it via "flatpak run"
# Make shell aliases which point to the function for basename and lowercase-basename versions of the command
# Example: a Flatpak for org.gnome.GIMP would make "org.gnome.GIMP()" function along with aliases "GIMP" and "gimp"
foreach my $flatpak (sort keys %flatpaks) {
	my $flatpak_base = $flatpak;
	$flatpak_base =~ s=^.*\.==;
	my $flatpak_base_lc = lc $flatpak_base;
	say "$flatpak() { $prog{flatpak} run $flatpak \"\$@\"; };";
	say "alias $flatpak_base=$flatpak;";
	if ($flatpak_base ne  $flatpak_base_lc) {
		say "alias $flatpak_base_lc=$flatpak;";
	}
}
