#!/usr/bin/env perl
#  PODNAME: pull-nasa-neo.pl
# ABSTRACT: get upcoming & recent Near Earth Object approaches from NASA JPL API
#   AUTHOR: Ian Kluft (IKLUFT)
#===============================================================================

use strict;
use warnings;
use utf8;
use autodie;
use Modern::Perl qw(2023);    # built-in boolean types require 5.36, try/catch requires 5.34
use AlertGizmo;
use AlertGizmo::Neo;

# set implementation subclass to AlertGizmo::Neo, then run AlertGizmo's main()
AlertGizmo::Neo->set_class();
AlertGizmo->main();

exit 0;

__END__

=encoding utf8

=head1 USAGE

    pull-nasa-neo.pl [--dir=directory] [--tz=timezone] [--proxy=proxy-string] [--verbose] [--test]

=head1 OPTIONS

=over

=item --dir=directory

This sets the directory where the script looks for templates, saves remote data and generates HTML output.
The default is the directory where the script is located, which probably only makes sense if it's a symlink
in the directory where the templates, data and output are located.

=item --tz=timezone

This sets the time zone which will be used for displaying local time (normally on HTML mouse-over text).
The default is the current timezone setting for the running process.

=item --proxy=proxy-string

This sets a network proxy. The default is not to change the proxy setting, or not use one if it wasn't set in the environment.

=item --verbose

This sets verbose mode, which is mainly of interest to developers for printing program status and progress.

=item --test

This sets test mode, which is mainly of interest to developers for stopping processing before writing to output files and just dumping the internal data set.

=back

=head1 EXIT STATUS

The program returns the standard Unix exit codes of 0 for success and non-zero for errors.

=head1 LICENSE

AlertGizmo is Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/ikluft-tools/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/ikluft-tools/pulls>

=cut

