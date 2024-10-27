# AlertGizmo
# ABSTRACT: base class for AlertGizmo feed monitors
# Copyright (c) 2024 by Ian Kluft

# pragmas to silence some warnings from Perl::Critic
## no critic (Modules::RequireExplicitPackage)
# This solves a catch-22 where parts of Perl::Critic want both package and use-strict to be first
use Modern::Perl qw(2023);   # includes strict & warnings, boolean requires 5.36, try/catch requires 5.34
## use critic (Modules::RequireExplicitPackage)

package AlertGizmo;

use utf8;
use autodie;
use experimental qw(builtin try);
use feature      qw(say try);
use builtin      qw(true false);
use Readonly;
use Carp qw(croak confess);
use FindBin;
use AlertGizmo::Config;
use File::Basename;
use Getopt::Long;
use Template;
use results;
use Data::Dumper;

# initialize class static variables
AlertGizmo::Config->accessor( [ "options" ], {} );
AlertGizmo::Config->accessor( [ "params" ], {} );
AlertGizmo::Config->accessor( [ "paths" ], {} );

# constants
Readonly::Scalar our $PROGNAME  => basename( $0 );
Readonly::Array  our @CLI_OPTIONS => ( "dir:s", "test|test_mode", "proxy:s", "timezone|tz:s" );
Readonly::Scalar our $DEFAULT_OUTPUT_DIR    => $FindBin::Bin;

# return AlertGizmo (or subclass) version number
sub version
{
    my $class = shift;
    {
        ## no critic (TestingAndDebugging::ProhibitNoStrict)
        no strict 'refs';
        if ( defined ${ $class . "::VERSION" } ) {
            return ${ $class . "::VERSION" };
        }
    }
    return "00-dev";
}


#
# Configuration wrapper functions for AlertGizmo::Config
#

# wrapper for AlertGizmo::Config read/write accessor
sub config
{
    my ( $class, $keys_ref, $value ) = @_;
    my $result = AlertGizmo::Config->accessor( $keys_ref, $value );
    if ( $result->is_err() ) {
        if ( $result->isa( AlertGizmo::Config::NotFound )) {
            # process not found error into undef result as common Perl code expects
            return;
        }
    }
    return $result->unwrap(); # returns on success, fatal error if any other than not found
}

# wrapper for AlertGizmo::Config existence-test method
sub has_config
{
    my ( $class, @keys ) = @_;
    return AlertGizmo::Config->contains( @keys );
}

# wrapper for AlertGizmo::Config delete method
sub del_config
{
    my ( $class, @keys ) = @_;
    return AlertGizmo::Config->del(@keys);
}

# accessor wrapper for options top-level config
sub options
{
    my ( $class, $keys_ref, $value ) = @_;
    return $class->config( [ "options", @{ $keys_ref // [] } ], $value )->unwrap();
}

# accessor wrapper for params top-level config
sub params
{
    my ( $class, $keys_ref, $value ) = @_;
    return $class->config( [ "params", @{ $keys_ref // [] } ], $value )->unwrap();
}

# accessor wrapper for paths top-level config
sub paths
{
    my ( $class, $keys_ref, $value ) = @_;
    return $class->config( [ "paths", @{ $keys_ref // [] } ], $value )->unwrap();
}

# accessor for test mode config
sub config_test_mode
{
    my $class = shift;
    return $class->options( [ "test" ] ) // false;
}

# accessor for proxy config
sub config_proxy
{
    my $class = shift;
    return $class->options( [ "proxy" ] ) // $ENV{PROXY} // $ENV{SOCKS_PROXY};
}

# accessor for timezone config
sub config_timezone
{
    my $class = shift;

    if ( $class->has_config( qw(params timezone) )) {
        return $class->params( [ "timezone" ] );
    }
    my $tz = $class->options( [ "timezone" ] ) // "UTC"; # get TZ value from CLI options or default UTC
    $class->params( [ "timezone" ], $tz )->unwrap(); # save to template params
    return $tz; # and return value to caller
}

# accessor for timestamp config
sub config_timestamp
{
    my $class = shift;

    if ( $class->has_config( qw(params timestamp) )) {
        return $class->params( [ "timestamp" ] );
    }
    my $timestamp_str = DateTime->now( time_zone => $class->config_timezone() );
    $class->params( [ "timezone" ], $timestamp_str );
    return $timestamp_str;
}

# accessor for output directory config
# It should not be necessary for subclasses to override this. But it's technically possible.
sub config_dir
{
    my $class = shift;

    if ( $class->has_config( qw(params output_dir) )) {
        return $class->params( [ "output_dir" ] );
    }
    my $dir;
    if ( $class->has_config( qw(options dir) )) {
        $dir = $class->options( [ "dir" ] );
    } else {
        $dir = $DEFAULT_OUTPUT_DIR;
    }
    my $result = $class->params( [ "output_dir" ], $dir );
    if ( not $result->ok()) {
        croak "failed to save output_dir param ($dir)";
    }
    return $dir;
}

# class method to set the subclass it was called as to provide the implementation for this run
sub set_class
{
    my $class = shift;

    if ( not $class->isa( __PACKAGE__ )) {
        croak "error: $class is not a subclass of ".__PACKAGE__;
    }
    $class->config( [ "class" ], $class );
    return;
}

#
# common functions used by AlertGizmo feed monitors
#

# convert DateTime to date/time/tz string
sub dt2dttz
{
    my $dt = shift;
    return $dt->ymd('-') . " " . $dt->hms(':') . " " . $dt->time_zone_short_name();
}

# generate class name from program name
# class function
sub gen_class_name
{
    # If "class" config is set, then this is already decided. So use that.
    if ( __PACKAGE__->has_config( "class" )) {
        return __PACKAGE__->config( [ "class" ] );
    }

    # use the name of the script to determine which AlertGizmo subclass to load
    my $progname = $PROGNAME;
    $progname =~ s/^alert-//x;  # remove alert- prefix from program name
    $progname =~ s/\.pl$//x;    # remove .pl suffix if present
    my $subclassname = __PACKAGE__."::".ucfirst(lc($progname));
    my $subclasspath = $subclassname.".pm";
    $subclasspath =~ s/::/\//gx;
    try {
        require $subclasspath;
    } catch ( $e ) {
        croak "failed to load class $subclassname: $e";
    };
    if ( not $subclassname->isa( __PACKAGE__ )) {
        croak "error: $subclassname is not a subclass of ".__PACKAGE__;
    }
    return $subclassname;
}

# inner mainline called from main() exception-catching wrapper
sub main_inner
{
    my $class = gen_class_name();

    # load subclass-specific argument list, then read command line arguments
    my @cli_options = ( @CLI_OPTIONS );
    if ( $class->can( "cli_options" )) {
            push @cli_options, $class->cli_options();
    }
    GetOptions( AlertGizmo::options(), @cli_options );

    # save timestamp
    $class->params( [ qw( timestamp ) ], dt2dttz( $class->config_timestamp() ));

    # subclass-specific processing for before template
    if ( $class->can( "pre_template" )) {
        $class->pre_template();
    }

    # process template
    my $config = {
        INCLUDE_PATH => $class->config_dir(),
        INTERPOLATE  => 1,          # expand "$var" in plain text
        POST_CHOMP   => 1,          # cleanup whitespace
        EVAL_PERL    => 0,          # evaluate Perl code blocks
    };
    my $template = Template->new($config);
    $template->process( $class->path_template(), $class->params(), $class->config_dir()
        . "/" . $class->path_output(), binmode => ':utf8' )
        or croak "template processing error: " . $template->error();

    # in test mode, exit before messing with symlink or removing old files
    if ( $class->config_test_mode()) {
        say "test mode: params=" . Dumper( $class->params() );
        exit 0;
    }

    # subclass-specific processing for after template
    if ( $class->can( "post_template" )) {
        $class->post_template();
    }

    return;
}

# exception-catching wrapper for mainline
## no critic (Subroutines::RequireFinalReturn)
sub main
{
    # catch exceptions
    try {
        main_inner();
    } catch ($e) {
        # simple but a functional start until more specific exception-catching gets added
        confess "error: $e";
    }
    exit 0;
}
## critic (Subroutines::RequireFinalReturn)

1;
