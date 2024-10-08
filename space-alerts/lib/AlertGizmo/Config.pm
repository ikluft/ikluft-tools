# AlertGizmo::Config
# ABSTRACT: configuration data for AlertGizmo classes
# Copyright (c) 2024 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);   # includes strict & warnings
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Config; 

use utf8;
use autodie;
use parent qw(Class::Singleton);
use Carp qw(croak confess);

# helper function to allow methods to get the singleton instance whether called as a class or instance method
sub _class_or_obj
{
    my $coo = shift;    # coo = class or object

    # safety net: all-stop if we received an undef
    if ( not defined $coo ) {
        confess "coo got undef from:" . ( join "|", caller 1 );
    }

    # safety net: the class or object must be compatible, belonging to for derived from this class
    if ( not $coo->isa(__PACKAGE__) ) {
        confess "incompatible class $coo from:" . ( join "|", caller 1 );
    }

    # instance method if it got an object reference
    return $coo if ref $coo;

    # class method: return the instance via the instance() class method
    # if the singleton object wasn't already instantiated, this will take care of it
    # assumption: it must be string name of class AlertGizmo::Config or subclass of it - so it has instance()
    return $coo->instance();
}

# helper function to read paths to a hash-of-hash entry
sub hash_path
{
    my ($class, @path) = @_;
    my $instance = __PACKAGE__->instance();
    my $return_value = $instance->{ $path[0] };
    for (1 .. (scalar @path - 1)) {
        $return_value = $return_value->{ $path[$_] };
    }
    return $return_value;
}

# check for existence of a config entry
sub contains
{
    my ( $class_or_obj, @keys ) = @_;
    my $instance = _class_or_obj($class_or_obj);
    my $data = $instance->hash_path( @keys );
    return defined $data;
}

# TODO
