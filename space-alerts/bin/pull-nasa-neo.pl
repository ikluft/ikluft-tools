#!/usr/bin/env perl
#  PODNAME: pull-nasa-neo.pl
# ABSTRACT: get upcoming & recent Near Earth Object approaches from NASA JPL API
#   AUTHOR: Ian Kluft (IKLUFT)
#===============================================================================

use strict;
use warnings;
use utf8;
use autodie;
use Modern::Perl qw(2023);          # built-in boolean types require 5.36, try/catch requires 5.34
use AlertGizmo;
use AlertGizmo::Neo;

# set implementation subclass to AlertGizmo::Neo, then run AlertGizmo's main()
AlertGizmo::Neo->set_class();
AlertGizmo->main();

exit 0;

__END__

=encoding utf8

=head1 USAGE

    pull-nasa-neo.pl [--dir=directory] [--tz=timezone] [--proxy=proxy-string]

=head1 OPTIONS

=head1 EXIT STATUS

The program returns the standard Unix exit codes of 0 for success and non-zero for errors.

=head1 LICENSE

AlertGizmo is Open Source software licensed under the GNU General Public License Version 3.
See L<https://www.gnu.org/licenses/gpl-3.0-standalone.html>.

=head1 BUGS AND LIMITATIONS

=cut

