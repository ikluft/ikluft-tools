#!/usr/bin/env perl 
#===============================================================================
#         FILE: bootstrap-prereqs.pl
#        USAGE: ./bootstrap-prereqs.pl  
#  DESCRIPTION: install prerequisite modules for a Perl script with minimal prerequisites for this tool
#       AUTHOR: Ian Kluft (IKLUFT), 
#      CREATED: 04/14/2022 05:45:29 PM
#===============================================================================

use strict;
use warnings;
use utf8;
use autodie;
use feature qw(say);
use Data::Dumper;

# system environment & globals
my %sysenv;
my %sources = (
    "App::cpanminus" => 'https://cpan.metacpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7045.tar.gz',
);
my @module_deps = (qw(Module::ScanDeps HTTP::Tiny));
my %pkg_override = (
    alpine => {
        "perl-cpan" => "perl-utils",
    },
    debian => {
        "libapp-cpanminus-perl" => "cpanminus",
    },
);
my %pkg_skip = (
    "strict" => 1,
    "warnings" => 1,
    "utf8" => 1,
    "feature" => 1,
    "autodie" => 1,
);
my $debug = 1;

# run an external command and capture its standard output
sub capture_cmd
{
    my $cmd = shift;
    no autodie;
    open my $fh, "-|", $cmd
        or die "failed to run pipe command '$cmd': $!";
    my @output;
    while (<$fh>) {
        chomp;
        push @output, $_;
    }
    if (close $fh) {
        return wantarray ? @output : join("\n", @output);
    }
    if ($!) {
        warn "failed to close pipe for command '$cmd': $!";
    }
    warn "exit status $? from command '$cmd'";
    return;
}

# get working directory (with minimal library prerequisites)
sub pwd
{
    my $pwd = capture_cmd('pwd');
    chomp $pwd;
    return $pwd;
}

# determine if a Perl module is installed
sub module_installed
{
    my $name = shift;

    # check each path element for the module
    my $modfile = join("/", split(/::/, $name));
    foreach my $element (@INC) {
        my $filepath = "$element/$modfile.pm";
        if (-f $filepath) {
            return 1;
        }
    }
    return 0;
}

# find executable files in the $PATH and standard places
sub cmd_path
{
    my $name = shift;

    # collect and cache path info
    if (not exists $sysenv{path_list} or not exists $sysenv{path_flag}) {
        $sysenv{path_list} = [split /:/, $ENV{PATH}];
        $sysenv{path_flag} = {map { ($_ => 1) } @{$sysenv{path_list}}};
        foreach my $dir (qw(/bin /usr/bin /sbin /usr/sbin /opt/bin)) {
            -d $dir or next;
            if (not exists $sysenv{path_flag}{$dir}) {
                push @{$sysenv{path_list}}, $dir;
                $sysenv{path_flag}{$dir} = 1;
            }
        }
    }

    # check each path element for the file
    foreach my $element (@{$sysenv{path_list}}) {
        my $filepath = "$element/$name";
        if (-x $filepath) {
            return $filepath;
        }
    }
    return;
}

# de-duplicate a colon-delimited path
sub dedup_path
{
    my @in_paths = @_;
    my @out_path;
    my %path_seen;
    
    # construct path lists and deduplicate
    foreach my $dir (map {split /:/, $_} @in_paths) {
        $debug and say STDERR "debug: found $dir";
        if ($dir eq "." ) {
            # omit "." for good security practice
            next;
        }
        # add the path if it hasn't already been seen, and it exists
        if (not exists $path_seen{$dir} and -d $dir) {
            push @out_path, $dir;
            $debug and say STDERR "debug: pushed $dir";
        }
        $path_seen{$dir} = 1;
    }
    return join ":", @out_path;
}

# set up user library and environment variables
# this is called for non-root users
sub set_user_env
{
    # find or create library under home directory
    if (exists $ENV{HOME}) {
        $sysenv{home} = $ENV{HOME};
    }

    # use environment variables to look for user's Perl library
    my @lib_hints;
    my %hints_seen;
    if (exists $ENV{PERL_LOCAL_LIB_ROOT}) {
        foreach my $item (split /:/, $ENV{PERL_LOCAL_LIB_ROOT}) {
            if ($item =~ qr(^$sysenv{home}/)) {
                $item =~ s=/$==; # remove trailing slash if present
                if (not exists $hints_seen{$item}) {
                    push @lib_hints, $item;
                    $hints_seen{$item} = 1;
                }
            }
        }
    }
    if (exists $ENV{PERL5LIB}) {
        foreach my $item (split /:/, $ENV{PERL5LIB}) {
            if ($item =~ qr(^$sysenv{home}/)) {
                $item =~ s=/$==; # remove trailing slash if present
                $item =~ s=/[^/]+$==; # remove last directory from path
                if (not exists $hints_seen{$item}) {
                    push @lib_hints, $item;
                    $hints_seen{$item} = 1;
                }
            }
        }
    }
    if (exists $ENV{PATH}) {
        foreach my $item (split /:/, $ENV{PATH}) {
            if ($item =~ qr(^$sysenv{home}/) and $item =~ qr(/perl[5]?/)) {
                $item =~ s=/$==; # remove trailing slash if present
                $item =~ s=/[^/]+$==; # remove last directory from path
                if (not exists $hints_seen{$item}) {
                    push @lib_hints, $item;
                    $hints_seen{$item} = 1;
                }
            }
        }
    }
    foreach my $dirpath (@lib_hints) {
        if (-d $dirpath and -w $dirpath) {
            $sysenv{perlbase} = $dirpath;
            last;
        }
    }
    
    # more exhaustive search for user's local perl library directory
    if (not exists $sysenv{perlbase}) {
        DIRLOOP: foreach my $dirpath ($sysenv{home}, $sysenv{home}."/lib", $sysenv{home}."/.local") {
            foreach my $perlname (qw(perl perl5)) {
                if (-d $dirpath."/".$perlname and -w $dirpath."/".$perlname) {
                    $sysenv{perlbase} = $dirpath."/".$perlname;
                    last DIRLOOP;
                }
            }
        }
    }

    # if the user's local perl library doesn't exist, create it
    if (not exists $sysenv{perlbase}) {
        # use a default that complies with XDG directory structure
        my $need_path;
        foreach my $need_dir ($sysenv{home}, ".local", "perl", "lib", "perl5") {
            $need_path = (defined $need_path) ? "$need_path/$need_dir" : $need_dir;
            if (! -d $need_path) {
                mkdir $need_path, 755
                    or die "failed to create $need_path: $!";
            }
        }
        $sysenv{perlbase} = $sysenv{home}."/.local/perl";
        symlink $sysenv{home}."/.local/perl", $sysenv{perlbase}
            or die "failed to symlink $sysenv{home}/.local/perl to $sysenv{perlbase}: $!";
    }

    #
    # set user environment variables similar to local::lib
    #

    # update PATH
    if (exists $ENV{PATH}) {
        $ENV{PATH} = dedup_path($ENV{PATH}, $sysenv{perlbase}."/bin");
    } else {
        $ENV{PATH} = dedup_path("/usr/bin:/bin", $sysenv{perlbase}."/bin", "/usr/local/bin");
    }
    delete $sysenv{path_list}; # because we modified PATH: remove path cache and force it to be regenerated
    delete $sysenv{path_flag}; # because we modified PATH: remove path cache flags and force it to be regenerated

    # update PERL5LIB
    if (exists $ENV{PERL5LIB}) {
        $ENV{PERL5LIB} = dedup_path($ENV{PERL5LIB}, $sysenv{perlbase}."/lib/perl5");
    } else {
        $ENV{PERL5LIB} = dedup_path(@INC, $sysenv{perlbase}."/lib/perl5");
    }

    # update PERL_LOCAL_LIB_ROOT/PERL_MB_OPT/PERL_MM_OPT for local::lib
    if (exists $ENV{PERL_LOCAL_LIB_ROOT}) {
        $ENV{PERL_LOCAL_LIB_ROOT} = dedup_path($ENV{PERL_LOCAL_LIB_ROOT}, $sysenv{perlbase});
    } else {
        $ENV{PERL_LOCAL_LIB_ROOT} = $sysenv{perlbase};
    }
    $ENV{PERL_MB_OPT} = '--install_base "'.$sysenv{perlbase}.'"';
    $ENV{PERL_MM_OPT} = 'INSTALL_BASE='.$sysenv{perlbase};

    # update MANPATH
    if (exists $ENV{MANPATH}) {
        $ENV{MANPATH} = dedup_path($ENV{MANPATH}, $sysenv{perlbase}."/man");
    } else {
        $ENV{MANPATH} = dedup_path("usr/share/man", $sysenv{perlbase}."/man", "/usr/local/share/man");
    }

    # display updated environment variables
    say "using environment settings: (add these to login shell rc script if needed)";
    foreach my $varname (qw(PATH PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT MANPATH)) {
        say "export $varname=$ENV{$varname}";
    }
}

# collect system environment info
sub collect_sysenv
{
    # find command locations
    foreach my $cmd (qw(uname curl tar cpan cpanm rpm yum repoquery dnf apt apk brew)) {
        my $filepath = cmd_path($cmd);
        if (defined $filepath) {
            $sysenv{$cmd} = $filepath;
        }
    }

    # collect uname info
    my $uname = $sysenv{uname};
    if (not defined $uname) {
        die "error: can't find uname command to collect system information";
    }
    $sysenv{os} = capture_cmd($uname);
    $sysenv{kernel} = capture_cmd($uname, "-r");
    $sysenv{machine} = capture_cmd($uname, "-m");

    # if /etc/os-release exists (on most Linux systems), read it
    if (-f "/etc/os-release") {
        if (open my $fh, "<", "/etc/os-release") {
            while (<$fh>) {
                chomp;
                if (/^([A-Z0-9_]+)="(.*)"$/) {
                    $sysenv{$1} = $2;
                } elsif (/^([A-Z0-9_]+)='(.*)'$/) {
                    $sysenv{$1} = $2;
                } elsif (/^([A-Z0-9_]+)=(.*)$/) {
                    $sysenv{$1} = $2;
                } else {
                    warn "warning: unable to parse line from /etc/os-release: $_";
                }
            }
            close $fh;
        }
    }

    # check if user is root
    if ($> == 0) {
        # set the flag to indicate they are root
        $sysenv{root} = 1;

        # on Alpine, refresh the package data
        if (exists $sysenv{apk}) {
            run_cmd($sysenv{apk}, "update");
        }
    } else {
        # set user environment variables as necessary (similar to local::lib but without that as a dependency)
        set_user_env();
    }

    # debug dump
    if ($debug) {
        say STDERR "debug: sysenv:";
        foreach my $key (sort keys %sysenv) {
            if (ref $sysenv{$key} eq "ARRAY") {
                say STDERR "   $key => [".join(" ", @{$sysenv{$key}})."]";
            } else {
                say STDERR "   $key => ".($sysenv{$key} // "(undef)");
            }
        }
    }
}

# run an external command
sub run_cmd
{
    my @cmd = @_;
    system @cmd;
    if ($? == -1) {
        say STDERR "failed to execute '".(join " ", @cmd)."': $!";
        exit 1;
    } elsif ($? & 127) {
        printf STDERR "child '".(join " ", @cmd)."' died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
        exit 1;
    } else {
        my $retval = $? >> 8;
        if ($retval != 0) {
            printf STDERR "child '".(join " ", @cmd)."' exited with value %d\n", $? >> 8;
            return 0;
        }
    }

    # it only gets here if it succeeded
    return 1;
}

# check if the user is root - if so, return true
sub is_root
{
    return ($sysenv{root} // 0) != 0;
}

# install a Perl module as an OS package
sub module_package
{
    my $module = shift;

    # check if we can install a package
    if ($sysenv{os} ne "Linux") {
        # currently only Linux can install OS packages
        return 0;
    }
    if (not is_root()) {
        # must be root to install an OS package
        return 0;
    }

    my @mod_parts = split /::/, $module;
    if ($sysenv{ID} eq "fedora" or $sysenv{ID} eq "rhel" or $sysenv{ID} eq "centos") {
        if (not exists $sysenv{dnf} and not exists $sysenv{yum}) {
            # no command to install RPM packages
            return 0;
        }
        my $pkgname = join("-", "perl", @mod_parts);
        if (exists $pkg_override{fedora}{$pkgname}) {
            $pkgname = $pkg_override{fedora}{$pkgname};
        }
        my $pkgcmd = (exists $sysenv{dnf}) ? $sysenv{dnf} : $sysenv{yum};
        return run_cmd($pkgcmd, "install", $pkgname);
    } elsif ($sysenv{ID} eq "alpine") {
        if (not exists $sysenv{apk}) {
            # no command to install APK packages
            return 0;
        }
        my $pkgname = join("-", "perl", map {lc $_} @mod_parts);
        if (exists $pkg_override{alpine}{$pkgname}) {
            $pkgname = $pkg_override{alpine}{$pkgname};
        }
        my $pkgcmd = $sysenv{apk};
        my @pkglist = capture_cmd($pkgcmd, "list", "--available", "--quiet", $pkgname);
        if (scalar @pkglist == 0) {
            return 0;
        }
        return run_cmd($pkgcmd, "add", $pkgname);
    } elsif ($sysenv{ID} eq "debian" or $sysenv{ID} eq "ubuntu") {
        if (not exists $sysenv{apt}) {
            # no command to install DEB packages
            return 0;
        }
        my $pkgname = "lib".join("-", (map {lc $_} @mod_parts), "perl");
        if (exists $pkg_override{debian}{$pkgname}) {
            $pkgname = $pkg_override{debian}{$pkgname};
        }
        my $pkgcmd = $sysenv{apt};
        return run_cmd($pkgcmd, "install", $pkgname);
    }

    # unrecognized distribution - assume no package management available
    return 0;
}

# bootstrap CPAN-Minus in a subdirectory of the current directory
sub bootstrap_cpanm
{
    # save current directory
    my $old_pwd = pwd();

    # make build directory and change into it
    if (! -d "build") {
        mkdir "build"
            or die "can't make build directory in current directory: $!";
    }
    chdir "build";

    # verify required commands are present
    my @missing;
    foreach my $cmd (qw(curl tar)) {
        if (not exists $sysenv{$cmd}) {
            push @missing, $cmd;
        }
    }
    if (scalar @missing > 0) {
        die "missing ".(join ", ", @missing)." command - can't bootstrap cpanm";
    }

    # download cpanm
    run_cmd($sysenv{curl}, "-L", "--output", "app-cpanminus.tar.gz", $sources{"App::cpanminus"})
        or die "download failed for App::cpanminus";
    my $cpanm_path = grep {qr(/bin/cpanm$)x} capture_cmd($sysenv{tar}, "-tf", "app-cpanminus.tar.gz");
    run_cmd($sysenv{tar}, "-xf", "app-cpanminus.tar.gz", $cpanm_path);
    $sysenv{cpanm} = pwd()."/".$cpanm_path;

    # change back up to previous directory
    chdir $old_pwd;
}

# check if module is installed, and install it if not present
sub check_module
{
    my $name = shift;

    # check if module is installed
    if (not module_installed($name)) {
        # try first to install it with an OS package (root required)
        my $done=0;
        if (is_root()) {
            if (module_package($name)) {
                $done=1;
            }
        }

        # try again if it wasn't installed by a package
        if (not $done) {
            run_cmd($sysenv{cpan}, $name)
                or die "failed to install $name module";
        }
    }
    return;
}

# establish CPAN if not already present
sub establish_cpan
{
    # install CPAN-Minus if it doesn't exist
    if (not exists $sysenv{cpanm}) {
        # try to install CPAN-Minus as an OS package
        if (is_root()) {
            if (module_package("App::cpanminus")) {
                $sysenv{cpanm} = cmd_path("cpanm");
            }
        }

        # try again if it wasn't installed by a package
        if (not exists $sysenv{cpanm}) {
            bootstrap_cpanm();
        }
    }

    # install CPAN if it doesn't exist
    if (not exists $sysenv{cpan}) {
        # try to install CPAN as an OS package
        if (is_root()) {
            if (module_package("CPAN")) {
                $sysenv{cpan} = cmd_path("cpan");
            }
        }

        # try again if it wasn't installed by a package
        if (not exists $sysenv{cpan}) {
            run_cmd($sysenv{cpanm}, "CPAN");
        }
    }

    # install dependencies for this tool
    foreach my $dep (@module_deps) {
        check_module($dep);
    }
    return;
}

sub process
{
    my $filename = shift;
    my $basename;
    if (index($filename, '/') == -1) {
        # no / in $filename will break Module::ScanDeps, so add full path
        $basename = $filename;
        $filename = pwd()."/".$filename;
    } else {
        # $filename is a path so keep it that way, and extract basename
        $basename = substr($filename, rindex($filename, '/')+1);
    }
    $debug and say STDERR "debug(process): filename=$filename basename=$basename";
    require Module::ScanDeps;
    my $deps_ref = Module::ScanDeps::scan_deps(files => [$filename], recurse => 0, compile => 0);
    if ($debug) {
        say "debug: deps_ref = ".Dumper($deps_ref);
    }
    my @deps = @{$deps_ref->{$basename}{uses}};
    foreach my $module (sort @deps) {
        next if $deps_ref->{$module}{type} ne "module";
        $module =~ s/\.pm$//;
        $module =~ s=/=::=;
        next if exists $pkg_skip{$module};
        $debug and say STDERR "check_module($module)";
        check_module($module);
    }
    return;
}

#
# mainline
#

# set up
collect_sysenv(); # collect system environment info
establish_cpan(); # make sure CPAN is available

# process command line
foreach my $arg (@ARGV) {
    process($arg);
}
