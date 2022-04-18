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
my @module_deps = qw(Perl::PrereqScanner::NotQuiteLite HTTP::Tiny);
my %module_cpanonly = (
    alpine => {
        #"Perl::PrereqScanner::NotQuiteLite" => 1,
    },
);
my @cpan_deps = (qw(make));
my %pkg_type = (
    "fedora" => "rpm",
    "rhel" => "rpm",
    "centos" => "rpm",
    "debian" => "deb",
    "ubuntu" => "deb",
    "alpine" => "apk",
    "arch" => "pacman",
);
my %pkg_override = (
    alpine => {
        "perl-cpan" => "perl-utils",
    },
    debian => {
        "libapp-cpanminus-perl" => "cpanminus",
    },
    ubuntu => {
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
my $debug = (($ENV{DEBUG} // 0) ? 1 : 0);

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
        foreach my $dir (qw(/bin /usr/bin /sbin /usr/sbin /opt/bin /usr/local/bin)) {
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
    say '-' x 75;
    foreach my $varname (qw(PATH PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT MANPATH)) {
        say "export $varname=$ENV{$varname}";
    }
    say '-' x 75;
    say '';
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
    $sysenv{kernel} = capture_cmd("$uname -r");
    $sysenv{machine} = capture_cmd("$uname -m");

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
    $debug and say STDERR "debug(run_cmd): ".join(" ", @cmd);
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
    return (($sysenv{root} // 0) != 0);
}

# check if packager command found (rpm)
sub pkg_pkgcmd_rpm
{
    return ((exists $sysenv{dnf} or (exists $sysenv{yum} and exists $sysenv{repoquery})) ? 1 : 0);
}

# find name of package for Perl module (rpm)
sub pkg_modpkg_rpm
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_rpm();
    #return join("-", "perl", @{$args_ref->{mod_parts}}); # rpm format for Perl module packages
    my $querycmd = ((exists $sysenv{dnf}) ? "dnf repoquery" : "repoquery");
    my @pkglist = sort capture_cmd("$querycmd --quiet --available --whatprovides perl($args_ref->{module})");
    return if not scalar @pkglist; # empty list means nothing found
    return $pkglist[-1]; # last of sorted list should be most recent version
}

# find named package in repository (rpm)
sub pkg_find_rpm
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_rpm();
    my $querycmd = ((exists $sysenv{dnf}) ? "dnf repoquery" : "repoquery");
    my @pkglist = sort capture_cmd("$querycmd --available --quiet $args_ref->{pkg}");
    return if not scalar @pkglist; # empty list means nothing found
    return $pkglist[-1]; # last of sorted list should be most recent version
}

# install package (rpm)
sub pkg_install_rpm
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_rpm();

    # determine packages to install
    my @packages;
    if (exists $args_ref->{pkg}) {
        if (ref $args_ref->{pkg} eq "ARRAY") {
            push @packages, @{$args_ref->{pkg}};
        } else {
            push @packages, $args_ref->{pkg};
        }
    }

    # install the packages
    my $pkgcmd = $sysenv{dnf} // $sysenv{yum};
    return run_cmd($pkgcmd, "install", @packages);
}

# check if packager command found (alpine)
sub pkg_pkgcmd_apk
{
    return (exists $sysenv{apk} ? 1 : 0);
}

# find name of package for Perl module (alpine)
sub pkg_modpkg_apk
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_apk();
    return join("-", "perl", map {lc $_} @{$args_ref->{mod_parts}}); # alpine format for Perl module packages
}

# find named package in repository (alpine)
sub pkg_find_apk
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_apk();
    my $querycmd = $sysenv{apk};
    my @pkglist = sort map {s/ .*//} capture_cmd("$querycmd list --available --quiet $args_ref->{pkg}");
    return if not scalar @pkglist; # empty list means nothing found
    return $pkglist[-1]; # last of sorted list should be most recent version
}

# install package (alpine)
sub pkg_install_apk
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_apk();

    # determine packages to install
    my @packages;
    if (exists $args_ref->{pkg}) {
        if (ref $args_ref->{pkg} eq "ARRAY") {
            push @packages, @{$args_ref->{pkg}};
        } else {
            push @packages, $args_ref->{pkg};
    }
        }

    # install the packages
    my $pkgcmd = $sysenv{apk};
    return run_cmd($pkgcmd, "add", @packages);
}

# check if packager command found (deb)
sub pkg_pkgcmd_deb
{
    return (exists $sysenv{apt} ? 1 : 0);
}

# find name of package for Perl module (deb)
sub pkg_modpkg_deb
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_deb();
    return "lib".join("-", (map {lc $_} @{$args_ref->{mod_parts}}), "perl"); # deb format for Perl module packages
}

# find named package in repository (deb)
sub pkg_find_deb
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_deb();
    my $querycmd = $sysenv{apt};
    my @pkglist = sort capture_cmd("$querycmd list --all-versions $args_ref->{pkg}");
    return if not scalar @pkglist; # empty list means nothing found
    return $pkglist[-1]; # last of sorted list should be most recent version
}

# install package (deb)
sub pkg_install_deb
{
    my $args_ref = shift;
    return if not pkg_pkgcmd_deb();

    # determine packages to install
    my @packages;
    if (exists $args_ref->{pkg}) {
        if (ref $args_ref->{pkg} eq "ARRAY") {
            push @packages, @{$args_ref->{pkg}};
        } else {
            push @packages, $args_ref->{pkg};
        }
    }

    # install the packages
    my $pkgcmd = $sysenv{apt};
    return run_cmd($pkgcmd, "install", @packages);
}

# handle various systems' packagers
# op parameter is a string:
#   implemented: 1 if packager implemented for this system, otherwise undef
#   pkgcmd: 1 if packager command found, 0 if not found
#   modpkg(module): find name of package for Perl module
#   find(pkg): 1 if named package exists, 0 if not
#   install(pkg): 0 = failure, 1 = success
# returns undef if not implemented
#   for ops which return a numeric status: 0 = failure, 1 = success
#   some ops return a value such as query results
sub manage_pkg
{
    my %args = @_;
    if (not exists $args{op}) {
        die "manage_pkg() requires op parameter";
    }

    # check if packager is implemented for currently-running system
    if ($args{op} eq "implemented") {
        if ($sysenv{os} eq "Linux") {
            if (not exists $sysenv{ID}) {
                # for Linux packagers, we need ID to tell distros apart - all modern distros should provide one
                return;
            }
            if (not exists $pkg_type{$sysenv{ID}}) {
                # it gets here on Linux distros which we don't have a packager implementation
                return;
            }
        } else {
            # so far only Linux packagers are implemented
            return;
        }
        return 1;
    }

    # if a pkg parameter is present, apply package name override if one is configured
    if (exists $args{pkg} and exists $pkg_override{$sysenv{ID}}{$args{pkg}}) {
        $args{pkg} = $pkg_override{$sysenv{ID}}{$args{pkg}};
    }

    # if a module parameter is present, add mod_parts parameter
    if (exists $args{module}) {
        $args{mod_parts} = [split /::/, $args{module}];
    }

    # look up function which implements op for package type
    my $funcname = join("_", "pkg", $args{op}, $pkg_type{$sysenv{ID}});
    $debug and say STDERR "debug: $funcname(".join(" ", map {$_."=".$args{$_}} sort keys %args).")";
    my $funcref = __PACKAGE__->can($funcname);
    if (not defined $funcref) {
        # not implemented
        $debug and say STDERR "debug: $funcname not implemented";
        return;
    }

    # call the function
    return $funcref->(\%args);
}

# install a Perl module as an OS package
sub module_package
{
    my $module = shift;

    # check if we can install a package
    if (not is_root()) {
        # must be root to install an OS package
        return 0;
    }
    if (not manage_pkg(op => "implemented")) {
        return 0;
    }

    # skip prepared packages in some platforms for known problems
    if (exists $sysenv{ID} and exists $module_cpanonly{$sysenv{ID}}) {
        if (exists $module_cpanonly{$sysenv{ID}}{$module} and $module_cpanonly{$sysenv{ID}}{$module}) {
            return 0;
        }
    }

    # handle various package managers
    my $pkgname = manage_pkg(op => "modpkg", module => $module);
    return manage_pkg(op => "install", pkg => $pkgname);
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
    my $cpanm_path = grep {qr(/bin/cpanm$)x} capture_cmd("$sysenv{tar} -tf app-cpanminus.tar.gz");
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
    if (is_root()) {
        manage_pkg(op => "install", pkg => \@cpan_deps); # package dependencies for CPAN (i.e. make)
    }
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
        # no / in $filename will break Perl::PrereqScanner::NotQuiteLite, so add full path
        $basename = $filename;
        $filename = pwd()."/".$filename;
    } else {
        # $filename is a path so keep it that way, and extract basename
        $basename = substr($filename, rindex($filename, '/')+1);
    }
    $debug and say STDERR "debug(process): filename=$filename basename=$basename";

    # scan for dependencies
    require Perl::PrereqScanner::NotQuiteLite;
    my $scanner = Perl::PrereqScanner::NotQuiteLite->new();
    my $deps_ref = $scanner->scan_file($filename);
    $debug and say STDERR "debug: deps_ref = ".Dumper($deps_ref);

    # load Perl modules for dependencies
    my $deps = $deps_ref->requires();
    $debug and say STDERR "deps = ".Dumper($deps);
    foreach my $module (sort keys %{$deps->{requirements}}) {
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
