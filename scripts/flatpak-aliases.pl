#!/usr/bin/perl 
# flatpak-aliases.pl - generate shell aliases to run all installed Linux Flatpaks from the command line
#
# Copyright 2018 by Ian Kluft
# released as Open Source Software under the GNU General Public License Version 3.
# See https://www.gnu.org/licenses/gpl.txt
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
# 3) Edit the script so $flatpak_prog correctly names the full path to your flatpak binary.
#    Use "which flatpak" to find the full path.  If you don't have it, this is where you need to install it.
#    See https://flatpak.org/ for instructions.
#
# 4) Make it executable: (adjust the path as needed for your installation)
#    chmod u=rwx,go=rx ~/bin/flatpak-aliases.pl
#
# 5) Then add this line to your ~/.bashrc script: (adjust the path as needed for your installation)
#    eval $(~/bin/flatpak-aliases.pl)
#
# Step #5 will take effect as each shell starts. But alliases aren't defined in shells already running at the time.
# You may run that command in any shell which is currently running, in order to define aliases for your flatpaks.

use strict;
use warnings;
use utf8;
use v5.18;	# require Perl 5.18 (2014) or later so the script can use "say" and other recent features

# configuration
my $flatpak_prog = "/usr/bin/flatpak";

#globals
my %flatpaks;

# collect list of installed Flatpaks from both system-wide and user-specific installations
# note: this only considers apps, not runtimes - that's what makes sense to run from the command-line
open( my $pipefh, "-|", "$flatpak_prog list --app" )
	|| die "$0: pipe open failed: $!";
while (<$pipefh>) {
	if ( m=^([^/]+)= ) {
		$flatpaks{$1} = 1;
	}
}
close $pipefh
	|| die "$0: pipe close failed: $!";

# process each Flatpak app that was found
# Make a shell function for the full identifier name which runs it via "flatpak run"
# Make shell aliases which point to the function for basename and lowercase-basename versions of the command
# Example: a Flatpak for org.gnome.GIMP would make "org.gnome.GIMP()" function along with aliases "GIMP" and "gimp"
foreach my $flatpak (sort keys %flatpaks) {
	my $flatpak_base = $flatpak;
	$flatpak_base =~ s=^.*\.==;
	my $flatpak_base_lc = lc $flatpak_base;
	say "function $flatpak() { $flatpak_prog run $flatpak \"\$@\"; };";
	say "alias $flatpak_base=$flatpak;";
	if ($flatpak_base ne  $flatpak_base_lc) {
		say "alias $flatpak_base_lc=$flatpak;";
	}
}
