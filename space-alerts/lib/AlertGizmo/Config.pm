# AlertGizmo::Config
# ABSTRACT: configuration data for AlertGizmo classes
# Copyright (c) 2024 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);    # includes strict & warnings
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo::Config;

use utf8;
use autodie;
use parent       qw(Class::Singleton);
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Carp         qw(confess);
use results;
use results::exceptions (
    'NotFound'        => { has => ['name'] },
    'NonIntegerIndex' => { has => ['str'] },
    qw( InvalidNodeType NoAutoArray UndefValue )
);

# helper function to allow methods to get the singleton instance whether called as a class or instance method
# private class function
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

# return ref to hash-of-hash (hoh) entry one level down by key
# private class function
sub _descend_hoh : Result
{
    my ( $node_ref, $key ) = @_;

    if ( ref $node_ref eq "HASH" ) {

        # descend into hash ref by string
        if ( exists $node_ref->{$key} ) {
            if ( not ref $node_ref->{$key} ) {
                return ok( \$node_ref->{$key} );
            }
            return ok( $node_ref->{$key} );
        } else {
            return NotFound->err( name => $key );
        }
    } elsif ( ref $node_ref eq "ARRAY" ) {

        # descend into array ref by int
        if ( _str_is_int($key) ) {
            if ( exists $node_ref->[$key] ) {
                if ( not ref $node_ref->[$key] ) {
                    return ok( \$node_ref->[$key] );
                }
                return ok( $node_ref->[$key] );
            } else {
                return NotFound->err( name => $key );
            }
        } else {
            return NonIntegerIndex->err( str => $key );
        }
    }

    # any other ref type (or non-reference) is invalid for a tree node
    return InvalidNodeType->err();
}

# find ref to hash-of-hash (hoh) node by a path
# returns results ok() or err()
# private class function
sub _get_hoh_path : Result
{
    my ( $class, @path ) = @_;
    my $instance = __PACKAGE__->instance();
    if (( scalar @path ) == 0 ) {
        return ok( $instance );
    }
    if ( not defined $path[0] ) {
        return UndefValue->err();
    }
    my $node_ref = $instance->{ $path[0] };

    # descend tree to arbitrary depth as long as data exists for each key
    for my $index ( 1 .. ( scalar @path - 1 ) ) {
        my $node_result = _descend_hoh( $node_ref, $path[$index] );
        if ( $node_result->is_ok() ) {

            # unwrap ref from result and continue
            $node_ref = $node_result->unwrap();
        } else {

            # return error result
            return $node_result;
        }
    }
    return ok( $node_ref );
}

# make sure a path exists for writing to a possibly-new node
# private class function
sub _mk_hoh_path : Result
{
    my ( $class, @path ) = @_;
    my $instance = __PACKAGE__->instance();
    my $node_ref = ( scalar @path > 0 ) ? $instance->{ $path[0] } : $instance;

    # descend tree creating nodes if necessary
    for my $index ( 1 .. ( scalar @path - 1 ) ) {
        my $node_result = _descend_hoh( $node_ref, $path[$index] );
        if ( $node_result->is_ok() ) {

            # unwrap ref from result and continue
            $node_ref = $node_result->unwrap();
        } else {

            # for NotFound errors, create missing nodes if possible
            my $node_err = $node_result->unwrap_err();
            if ( $node_err->isa('AlertGizmo::Config::Exception::NotFound') ) {
                if ( _str_is_int( $path[$index] ) ) {
                    return NoAutoArray->err();
                }
                if ( ref $node_ref ne "HASH" ) {
                    return InvalidNodeType->err();
                }
                $node_ref->{ $path[$index] } = {};
                $node_ref = $node_ref->{ $path[$index] };
            } else {

                # return error result
                return $node_result;
            }
        }
    }
    return ok($node_ref);
}

# get/set verbose flag
# class method
sub verbose
{
    my ( $class_or_obj, $value ) = @_;
    my $instance = _class_or_obj($class_or_obj);
    if ( defined $value ) {
        if ( not exists $instance->{options} ) {
            $instance->{options} = {};
        }
        $instance->{options}{verbose} = $value ? true : false;
        return;
    }
    return $instance->{options}{verbose} // false;
}

# check for existence of a config entry
# returns boolean: true if successful, false if item does not exist
# public class method
sub contains
{
    my ( $class_or_obj, @keys ) = @_;
    my $instance   = _class_or_obj($class_or_obj);
    my $hoh_result = $instance->_get_hoh_path(@keys);
    if ( $hoh_result->is_err() ) {
        __PACKAGE__->verbose() and say STDERR "contains( " . join( " ", @keys ) . " ) -> not found";
        $hoh_result->unwrap_err();    # touch error to satisfy results it wasn't ignored
        return false;
    }
    $hoh_result->unwrap();            # touch result to satisfy results it wasn't ignored
    return true;
}

# configuration read accessor
# returns result type: ok(value) if successful, err(type) if item does not exist
# public class method
sub read_accessor : Result
{
    my ( $class_or_obj, @keys ) = @_;
    my $instance   = _class_or_obj($class_or_obj);
    my $hoh_result = $instance->_get_hoh_path(@keys);
    if ( $hoh_result->is_err() ) {
        __PACKAGE__->verbose()
            and say STDERR "read_accessor( " . join( " ", @keys ) . " ) -> " . $hoh_result;
        return $hoh_result;
    }
    my $value = $hoh_result->unwrap();
    if ( ref $value eq "SCALAR" ) {
        return ok($$value);
    }
    return ok($value);
}

# configuration write accessor
# returns result type: ok() if successful, err(type) if item does not exist
# public class method
sub write_accessor : Result
{
    my ( $class_or_obj, $keys_ref, $value ) = @_;
    my $instance   = _class_or_obj($class_or_obj);
    my @keys       = ( ref $keys_ref eq "ARRAY" ) ? @$keys_ref : $keys_ref;
    my $last_key   = pop @keys;
    my $hoh_result = $instance->_mk_hoh_path(@keys);
    if ( $hoh_result->is_err() ) {
        return $hoh_result;
    }
    my $node = $hoh_result->unwrap();
    $node->{$last_key} = $value;
    return if not defined wantarray;    # return value prohibited in void context
    return ok();
}

# configuration read/write accessor
# top-level class config() method calls here
sub accessor : Result
{
    my ( $class_or_obj, $keys_ref, $value ) = @_;
    my $instance = _class_or_obj($class_or_obj);

    # if no value is provided, use read accessor
    $keys_ref //= [];
    if ( not defined $value ) {
        my @keys = ( ref $keys_ref eq "ARRAY" ) ? @$keys_ref : $keys_ref;
        return $instance->read_accessor(@keys);
    }

    # otherwise use write accessor
    return $instance->write_accessor( $keys_ref, $value );
}

# delete configuration item
sub del
{
    my ( $class_or_obj, @keys ) = @_;
    my $instance   = _class_or_obj($class_or_obj);
    my $last_key   = pop @keys;
    my $hoh_result = $instance->_get_hoh_path(@keys);
    if ( $hoh_result->is_err() ) {
        return $hoh_result;
    }
    my $node = $hoh_result->unwrap();

    if ( ref $node eq "HASH" ) {
        if ( $node->contains($last_key) ) {

            # delete entry from hash
            return delete $node->{$last_key};
        }
    } elsif ( ref $node eq "ARRAY" ) {
        if ( exists $node->[ int($last_key) ] ) {

            # delete nth entry from array, shift higher items down and shrink array size
            splice @$node, int($last_key), 1;
        }
    }
    return ok();
}

#
# utility functions
#

# test if a string is a valid integer (all numeric)
# private class function
sub _str_is_int
{
    my $str = shift;
    return true if $str =~ /^ \d+ $/x;
    return false;
}

1;

=pod

=encoding utf8

=head1 SYNOPSIS

    use AlertGizmo::Config;

    AlertGizmo::Config->accessor( ["example"], "value" );   # write accessor

    $value = AlertGizmo::Config->accessor( ["example"] );   # read accessor

    $value2 = AlertGizmo::Config->contains(@keys);          # check existence of keys in Config

    $result = AlertGizmo::Config->del(@keys);               # delete entries by keys from Config

    AlertGizmo::Config->verbose() and say STDERR "config: verbose mode on";

=head1 DESCRIPTION

=head1 INSTALLATION

=head1 FUNCTIONS AND METHODS

=head1 LICENSE

=head1 SEE ALSO

=head1 BUGS AND LIMITATIONS

Please report bugs via GitHub at L<https://github.com/ikluft/ikluft-tools/issues>

Patches and enhancements may be submitted via a pull request at L<https://github.com/ikluft/ikluft-tools/pulls>

=cut
