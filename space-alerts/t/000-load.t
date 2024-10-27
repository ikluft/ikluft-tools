#!/usr/bin/env perl -T

use strict;
use warnings;
use Test::More;
use Try::Tiny;

# always test these modules can load
my @modules = qw(
    AlertGizmo
    AlertGizmo::Config
    AlertGizmo::Neo
);

# count tests
plan tests => int(@modules);

# test loading modules
foreach my $mod (@modules) {
    require_ok($mod);
}

diag( "Testing AlertGizmo " . AlertGizmo->version() . ", Perl $], $^X" );
