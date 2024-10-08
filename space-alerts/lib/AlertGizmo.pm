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
use File::Basename;

# initialize class static variables
# TODO resolve perlcritic warning: move to singleton config class, like WebFetch does but lighter-weight
our %options = ();
our %params = ();
our %paths  = ();

# constants
Readonly::Scalar our $PROGNAME  => basename( $0 );
Readonly::Scalar our $TEST_MODE => $options{test}  // false;
Readonly::Scalar our $PROXY     => $options{proxy} // $ENV{PROXY} // $ENV{SOCKS_PROXY};
Readonly::Scalar our $TIMEZONE  => $options{timezone} // "UTC";
Readonly::Scalar our $TIMESTAMP => DateTime->now( time_zone => $TIMEZONE );
Readonly::Scalar our $OUTDIR    => $FindBin::Bin;

#
# common functions used by AlertGizmo feed monitors
#

# convert DateTime to date/time/tz string
sub dt2dttz
{
    my $dt = shift;
    return $dt->ymd('-') . " " . $dt->hms(':') . " " . $dt->time_zone_short_name();
}

# inner mainline called from main() exception-catching wrapper
sub main_inner
{
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

    # load subclass-specific argument list, then read command line arguments
    my @cli_options = ( "test|test_mode", "proxy:s", "timezone|tz:s" );
    if ( $subclassname->can( "cli_options" )) {
            push @cli_options, $subclassname->cli_options();
    }
    GetOptions( \%AlertGizmo::options, @cli_options );

    # save timestamp
    $params{timestamp} = dt2dttz($TIMESTAMP);

    # clear destination symlink
    $paths{outlink} = $OUTDIR . "/" . $OUTJSON;
    if ( -e $paths{outlink} ) {
        if ( not -l $paths{outlink} ) {
            croak "destination file $paths{outlink} is not a symlink";
        }
    }
    $paths{outjson} = $paths{outlink} . "-" . $TIMESTAMP;

    # TODO - domain-specific processing via subclass override

    # process template
    my $config = {
        INCLUDE_PATH => $OUTDIR,    # or list ref
        INTERPOLATE  => 1,          # expand "$var" in plain text
        POST_CHOMP   => 1,          # cleanup whitespace
                                    #PRE_PROCESS  => 'header',        # prefix each template
        EVAL_PERL    => 0,          # evaluate Perl code blocks
    };
    my $template = Template->new($config);
    $template->process( $TEMPLATE, \%params, $OUTDIR . "/" . $OUTHTML, binmode => ':utf8' )
        or croak "template processing error: " . $template->error();

    # in test mode, exit before messing with symlink or removing old files
    if ($TEST_MODE) {
        say "test mode: params=" . Dumper(\%params);
        exit 0;
    }

    # make a symlink to new data
    if ( -l $paths{outlink} ) {
        unlink $paths{outlink};
    }
    symlink basename( $paths{outjson} ), $paths{outlink}
        or croak "failed to symlink " . $paths{outlink} . " to " . $paths{outjson} . "; $!";

        # clean up old data files
    opendir( my $dh, $OUTDIR )
        or croak "Can't open $OUTDIR: $!";
    my @datafiles = sort { $b cmp $a } grep { /^ $OUTJSON -/x } readdir $dh;
    closedir $dh;
    if ( scalar @datafiles > 5 ) {
        splice @datafiles, 0, 5;
        foreach my $oldfile (@datafiles) {

            # double check we're only removing old JSON files
            next if ( ( substr $oldfile, 0, length($OUTJSON) ) ne $OUTJSON );

            my $delpath = "$OUTDIR/$oldfile";
            next if not -e $delpath;               # skip if the file doesn't exist
            next if ( ( -M $delpath ) < 0.65 );    # don't remove files newer than 15 hours

            is_interactive() and say "removing $delpath";
            unlink $delpath;
        }
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
        croak "error: $e";
    }
    exit 0;
}
## critic (Subroutines::RequireFinalReturn)

1;
