# Avalon Build Perl Module
# 
# Copyright (C) 2001, Michael Jennings
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies of the Software, its documentation and marketing & publicity
# materials, and acknowledgment shall be given in the documentation, materials
# and software packages that this Software was used.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# $Id: Build.pm,v 1.13 2001/08/14 00:00:24 mej Exp $
#

package Avalon::Build;

BEGIN {
    use Exporter   ();
    use Cwd;
    use File::Copy;
    use Avalon::Util;
    use Avalon::Pkg;
    use Avalon::RPM;
    use Avalon::Deb;
    use Avalon::Tar;
    use Avalon::Prod;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&count_cpus', '&prepare_build_tree', '&get_source_list', '&create_source_file', '&create_source_files', '&cleanup_build_tree', '&build_rpms_from_tarball', '&build_debs_from_tarball', '&build_rpms_from_topdir', '&build_debs_from_topdir', '&build_topdir', '&build_spm', '&build_cfst', '&build_fst', '&build_srpm', '&build_tarball', '&build_package');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

### Initialize private global variables

### Function prototypes
sub count_cpus();
sub prepare_build_tree(\$\$\$);
sub get_source_list($$$$);
sub create_source_file($$$$$);
sub create_source_files($$$\@);
sub cleanup_build_tree($$$);
sub build_rpms_from_tarball($$$);
sub build_debs_from_tarball($$$);
sub build_rpms_from_topdir($$$);
sub build_debs_from_topdir($$$);
sub build_topdir($$$$);
sub build_spm($$$$);
sub build_cfst($$$$);
sub build_fst($$$$);
sub build_srpm($$$$);
sub build_tarball($$$$);
sub build_package($$$$);

# Private functions

### Module cleanup
END {
}

### Function definitions

# Count CPU's for purposes of parallelization
sub
count_cpus
{
    my $cpus;
    my @lines;
    local *CPU;

    open(CPU, "/proc/cpuinfo") || return 1;
    @lines = <CPU>;
    close(CPU);
    @lines = grep(/^processor/, @lines);
    $cpus = $#lines + 1;
    dprint "Found $cpus processors.\n";
    return ($cpus >= 1 ? $cpus : 1);
}

# Create the RPM build directories, the buildroot, and the RPM config files
sub
prepare_build_tree(\$\$\$)
{
    my ($name, $topdir, $buildroot) = @_;
    my ($rpmmacros, $rpmrc);
    local *RPMMACROS;
    local *RPMRC;

    # In order to alter the values of $name, $topdir, and $buildroot in the caller,
    # we are passed references to the variables, not the values.
    if (! $name) {
        $name = &basename(&getcwd());
    }
    if (! $topdir) {
        $topdir = &getcwd() . "/build.avalon";
    }
    if (! $buildroot) {
        $buildroot = "/var/tmp/avalon-buildroot.$$/$name";
    }
    dprint "$name | $topdir | $buildroot\n";

    # If the topdir doesn't exist, create it.
    if (! -d "$topdir") {
        if (!mkdir("$topdir", 0755)) {
            &fatal_error("Cannot create $topdir -- $!\n");
        }
    }

    # Create the RPM directories also.  Same deal as above.
    foreach my $dir ("BUILD", "SRPMS", "RPMS", "SPECS", "SOURCES") {
        if (! -d "$topdir/$dir") {
            if (-f "$topdir/$dir") {
                # It's a bogus file.  Nuke it.
                &nuke_tree("$topdir/$dir");
            }
            mkdir("$topdir/$dir", 0755) || &fatal_error("Cannot create $topdir/$dir -- $!\n");
        }
    }

    # If the build root exists, get rid of it, then make a new (empty) one.
    if (-d $buildroot) {
        &nuke_tree($buildroot);
    }
    mkdir($buildroot, 0775);

    return ($name, $topdir, $buildroot);

    # Pre-scan all the binary RPM's for future use in possibly parallel processes.  We need
    # to know what SRPM each binary came from, because some (lame) packages change the base name.
    #if (! $opt_nocache) {
    #    nprint "Updating state information....\n";
    #    dprint "Scanning binary RPM's in $topdir/RPMS for their corresponding SRPM's.\n";
    #    @contents = glob("$topdir/RPMS/*/*.rpm");
    #    foreach my $rpm (@contents) {
    #        dprint "Checking $rpm\n";
    #        $srpm_of_rpm{$rpm} = `rpm -qp $rpm --queryformat \"%{SOURCERPM}\"`;
    #    }
    #}
}

sub
get_source_list
{
    my ($specfile, $module, $srcs) = @_;
    my @srcs;

    dprint &print_args(@_);

    if ($module && (!chdir($module))) {
        return AVALON_BAD_MODULE;
    }
    &parse_spec_file($specfile) if ($specfile);

    if ($srcs) {
        @srcs = split(/[\s,]/, $srcs);
    } else {
        my $fname;

        wprint "No SRCS variable found.  Proceeding with default assumptions.  If the assumptions don't work,\n";
        wprint "you will need to create an avalon.srcs file for this package.\n";

        foreach my $fname (&grepdir(sub {! &should_ignore($_);})) {
            if (-d $fname) {
                my @tmp;

                if (defined(%{$specdata->{SOURCE}})) {
                    @tmp = grep($_ =~ /^\Q$fname\E\.(tgz|tar\.gz|tar\.Z|tar\.bz2|tbz)$/, values %{$specdata->{SOURCE}});
                }
                if (scalar(@tmp)) {
                    push @srcs, "$fname:$tmp[0]";
                } else {
                    push @srcs, "$fname:$fname.tar.gz";
                }
            } else {
                push @srcs, $fname;
            }
        }
    }

    dprint "Using SRCS variable \"", join(" ", @srcs), "\".\n";
    return @srcs;
}

sub
create_source_file
{
    my ($src_files, $tarball, $destdir, $tar, $zip) = @_;
    my $cmd;
    local *CMD;

    dprint &print_args(@_);

    $destdir .= '/' if (substr($destdir, -1, 1) ne '/');
    if ($tarball) {
        dprint "Generating $destdir$tarball from \"$src_files\"...\n";
        if ($tar) {
            $cmd = $tar;
            $cmd =~ s/\%f/$src_files/;
            $cmd =~ s/\%t/$destdir$tarball/;
        } else {
            if (! $zip) {
                if ($tarball =~ /(gz|Z)$/) {
                    $zip = "gzip";
                } elsif ($tarball =~ /\.bz2$/) {
                    $zip = "bzip2";
                }
            }
            if ($zip) {
                $zip = " --use-compress-program=$zip";
            } else {
                $zip = " ";
            }
            $cmd = "tar --exclude CVS --exclude RCS --exclude BitKeeper --exclude SCCS"
                   . "$zip -cf ${destdir}$tarball $src_files";
        }
        unlink($tarball);
        if (!open(CMD, "$cmd 2>&1 |")) {
            eprint "Execution of \"$cmd\" failed -- $!\n";
            return AVALON_COMMAND_FAILED;
        }
        while (<CMD>) {
            chomp($line = $_);
            print "tar output -> $line\n";
        }
        close(CMD);
        if ($?) {
            dprint "Command returned $?\n";
            eprint "Creation of vendor source tarball $tarball failed\n";
            return AVALON_BUILD_FAILURE;
        }
    } else {
        my $rc;

        dprint "Copying $src_files to $destdir.\n";
        if (!&copy_files(split(' ', $src_files), $destdir)) {
            return AVALON_SYSTEM_ERROR;
        }
    }
    return AVALON_SUCCESS;
}

sub
create_source_files($ $ $ \@)
{
    my ($destdir, $tar, $zip, $srcs) = @_;
    my ($err, $src_files, $tarball);

    # Create all the source files we need.
    dprint "$destdir, $tar, $zip, $srcs (@{$srcs})\n";
    foreach my $src (@{$srcs}) {
        ($src_files, $tarball) = split(":", $src);
        $src_files =~ s/\&/ /g;
        $err = &create_source_file($src_files, $tarball, $destdir, $tar, $zip);
        if ($err) {
            return $err;
        }
    }
    return AVALON_SUCCESS;
}

# Clean up the RPM build directories and the build root
sub
cleanup_build_tree
{
    my ($topdir, $buildroot, $type) = @_;
    my @dirs;

    if ($type =~ /no(ne)?/i) {
        return;
    } elsif ($type =~ /temp/i) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES", "$topdir/SPECS") if ($topdir);
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /rpm/i) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES", "$topdir/SRPMS", "$topdir/RPMS", "$topdir/SPECS") if ($topdir);
    } elsif ($type =~ /(build)?root/) {
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /build/) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES", "$topdir/SRPMS", "$topdir/RPMS", "$topdir/SPECS") if ($topdir);
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /all/) {
        push(@dirs, $topdir) if ($topdir);
        push(@dirs, $buildroot) if ($buildroot);
    } else {
        dprint "Unknown cleaning type \"$type\"\n";
        return;
    }
    if (scalar(@dirs)) {
        foreach my $f (@dirs) {
            &nuke_tree($f) if (-e $f);
        }
    }
}

# Builds RPM's from a tarball
sub
build_rpms_from_tarball
{
    my ($tarball, $topdir, $buildroot) = @_;
    my $cmd;

    $cmd = "/bin/rpm --define '_topdir $topdir' --define 'optflags $ENV{CFLAGS}'";
    if ($buildroot) {
        $cmd .= " --buildroot=\"$buildroot\"";
    }
    $cmd .= " -ta $tarball";
    return &rpm_build($cmd);
}

# Builds DEB files from a tarball
sub
build_debs_from_tarball
{
    my ($script_dir, $topdir, $buildroot) = @_;
    my $cmd;

    # Goop goes here.
    return &deb_build($cmd);
}

# Builds RPM's from a topdir
sub
build_rpms_from_topdir
{
    my ($specfile, $topdir, $buildroot) = @_;
    my $cmd;

    $cmd = "/bin/rpm --define '_topdir $topdir' --define 'optflags $ENV{CFLAGS}'";
    if ($buildroot) {
        $cmd .= " --buildroot=\"$buildroot\"";
    }
    $cmd .= " -ba $specfile";
    return &rpm_build($cmd);
}

# Builds DEB files from an RPM-style topdir
sub
build_debs_from_topdir
{
    my ($script_dir, $topdir, $buildroot) = @_;
    my $cmd;

    # Goop goes here.
    return &deb_build($cmd);
}

# build_topdir() is called once the RPM/DEB directories have been propogated with all
# the right stuff.  It, in turn, calls the target-specific function above.
sub
build_topdir
{
    my ($specfile, $topdir, $buildroot, $target_format) = @_;

    dprint &print_args(@_);

    if ($target_format eq "rpms") {
        return &build_rpms_from_topdir($specfile, $topdir, $buildroot);
    } elsif ($target_format eq "debs") {
        return &build_debs_from_topdir($specfile, $topdir, $buildroot);
    } else {
        my ($err, $msg, $outfiles);

        ($err, $msg, $outfiles) = &build_rpms_from_topdir($specfile, $topdir, $buildroot);
        if ($err) {
            return ($err, $msg, $outfiles);
        }
        return &build_debs_from_topdir($specfile, $topdir, $buildroot);
    }
}

# This function knows how to build packages from Source Package Modules (SPM's).  It
# is usually called by build_package() but can be called directly as long as the
# chdir() has been done already and we're 100% certain that it's an SPM.
sub
build_spm
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my $specfile;
    my (@tmp, @tmp2);

    dprint &print_args(@_);

    if (! -d "F") {
        &show_backtrace();
        &fatal_error("Call to build_spm() in non-SPM module.\n");
    }
    &prepare_build_tree($pkg, $topdir, $buildroot);

    @tmp = &grepdir(sub {-f $_ && -s _}, "F");
    if (!scalar(@tmp)) {
        return (AVALON_MISSING_FILES, "@{[getcwd()]} does not seem to contain build instructions", undef);
    } elsif (scalar(@tmp) > 1) {
        return (AVALON_BAD_MODULE, "Only one specfile/script dir allowed per package (@tmp)", undef);
    }
    &copy_files($tmp[0], "$topdir/SPECS");
    $specfile = "$topdir/SPECS/" . &basename($tmp[0]);
    @tmp = &grepdir(sub {-f $_ && -s _}, "S");
    @tmp2 = &grepdir(sub {-f $_ && -s _}, "P");
    if (!scalar(@tmp)) {
        @tmp = @tmp2;
    } elsif (scalar(@tmp2)) {
        push @tmp, @tmp2;
    }
    if (scalar(@tmp)) {
        &copy_files(@tmp, "$topdir/SOURCES");
    }

    return &build_topdir($specfile, $topdir, $buildroot, $target_format);
}

# This function handles the "special case" FST's which have their very own
# Makefile.avalon.  As with build_spm(), the chdir() must have already been done.
sub
build_cfst
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my ($err, $msg, $cmd, $make, $pkgdir, $outfiles);
    local *MAKE;

    dprint &print_args(@_);

    if (!(-f "Makefile.avalon" && -s _)) {
        &show_backtrace();
        &fatal_error("Call to build_cfst() in non-CFST module.\n");
    }
    &prepare_build_tree($pkg, $topdir, $buildroot);

    $pkgdir = "$topdir/RPMS";
    $make = "make -f Makefile.avalon";
    $cmd = "$make $target_format BUILD_DIR=$topdir BUILD_ROOT=$buildroot RPMRC=$buildroot/$pkg-rpmrc PKG_DIR=$pkgdir";

    dprint "About to run \"$cmd\"\n";
    if (!open(MAKE, "$cmd </dev/null 2>&1 |")) {
        return (AVALON_COMMAND_FAILED, "Execution of \"$cmd\" failed -- $!", undef);
    }
    $err = 0;
    while (<MAKE>) {
        chomp($line = $_);
        dprint "$line\n";
        if ($line =~ /^make[^:]*:\s+\*\*\*\s+(.*)$/ && ! $msg) {
            $msg = $1;
        }
    }
    close(MAKE);
    dprint "make returned $?\n";
    if ($? != 0 && $err == 0) {
        $err = $?;
        $msg = "Unhandled make error" if (! $msg);
	return ($err, $msg, undef);
    }

    # Find the output packages
    if ($target_format eq "rpms") {
        $outfiles = join(" ", &grepdir(sub {/\.rpm$/}, $pkgdir));
    } elsif ($target_format eq "debs") {
        $outfiles = join(" ", &grepdir(sub {/\.deb$/}, $pkgdir));
    } else {
        $outfiles = join(" ", &grepdir(sub {/\.rpm$/ || /\.deb$/}, $pkgdir));
    }

    if (! $outfiles) {
	dprint "No packages found in $pkgdir\n";
        $err = AVALON_PACKAGE_FAILED;
        $msg = "make finished successfully, but no packages were found in $pkgdir";
    }
    chdir($pwd) if (defined($pwd));
    return ($err, $msg, $outfiles);
}

# All other FST's (those without their own Makefiles) are built here.  Once again, this
# function can be called directly as long as the current directory is the FST to build.
sub
build_fst
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my ($specfile, $cmd, $ret);
    my (@srcs, @tmp);

    dprint &print_args(@_);
    $pkg = &basename(&getcwd()) if ($pkg eq ".");

    # Look for the build instructions (spec file, debian/ directory, etc.)
    if ($target_format eq "rpms") {
        @tmp = &grepdir(sub {/spec(\.in)?$/});
    } elsif ($target_format eq "debs") {
        @tmp = &grepdir(sub {$_ =~ m/debian/ && -d $_});
    } else {
        @tmp = &grepdir(sub {/spec(\.in)?$/ || ($_ =~ m/debian/ && -d $_)});
    }
    dprint @tmp, "\n";
    if (!scalar(@tmp)) {
        return (AVALON_MISSING_FILES, "I'm sorry, but \"$pkg\" doesn't seem to have instructions for building $target_format", undef);
    }

    &prepare_build_tree($pkg, $topdir, $buildroot);
    $specfile = $tmp[0];
    if (! &copy($specfile, "$topdir/SPECS/")) {
        return (AVALON_SYSTEM_ERROR, "Unable to copy $specfile to $topdir/SPECS/ -- $!\n", undef);
    }
    # Get ready to build, figure out what sources we need, and create them all.
    &parse_prod_file();
    @srcs = &get_source_list($specfile, ".", $pkgs->{$pkg}{SRCS});
    dprint @srcs, "\n";
    $ret = &create_source_files("$topdir/SOURCES", "", "", \@srcs);
    if ($ret != AVALON_SUCCESS) {
        return ($ret, "Creation of source files failed", undef);
    }

    return &build_topdir($specfile, $topdir, $buildroot, $target_format);
}

# Source RPM's can be rebuilt with this function.  build_package() usually handles the
# extraction of the module name, but this function can be called directly as long as
# that isn't an issue or has already been taken care of by the calling function.
sub
build_srpm
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my $err;
    my (@tmp, @specs);

    dprint &print_args(@_);

    &prepare_build_tree($pkg, $topdir, $buildroot);
    @tmp = &rpm_show_contents($pkg);
    if (($err = shift @tmp) != AVALON_SUCCESS) {
        return (AVALON_NO_SOURCES, "Unable to examine the contents of $pkg ($err)", undef);
    }
    foreach my $f (grep(/spec(\.in)?$/, @tmp)) {
        chomp($f);
        push @specs, $f;
    }
    if (scalar(@specs) != 1) {
        wprint "Found ${\(scalar(@specs))} spec files in $pkg?!\n";
    }
    @tmp = &rpm_install($pkg, $topdir);
    if (($err = shift @tmp) != AVALON_SUCCESS) {
        return (AVALON_PACKAGE_FAILED, "Unable to install $pkg ($err)", undef);
    }
    @specs = grep(-f "$topdir/SPECS/$_" && -s _, @specs);
    if (scalar(@specs) != 1) {
        return (AVALON_NO_SOURCES, "Found ${\(scalar(@specs))} spec files in $pkg?!", undef);
    }
    return &build_topdir("$topdir/SPECS/$specs[0]", $topdir, $buildroot, $target_format);
}

# Plain old tarballs can be rebuilt into packages using this function, as long as they
# contain the necessary file(s) inside them (spec file and/or debian/ directory).
sub
build_tarball
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my $cmd;

    dprint &print_args(@_);

    if ($target_format eq "rpms") {
        return &build_rpms_from_tarball($pkg, $topdir, $buildroot);
    } elsif ($target_format eq "debs") {
        return &build_debs_from_tarball($pkg, $topdir, $buildroot);
    }
}

# This is the main routine for building stuff.  Its job is to figure out what type of
# stuff it is that you're trying to build, and then call the right function to build it.
sub
build_package
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my $pwd;
    my @ret;

    dprint &print_args(@_);

    $pwd = &getcwd();

    if ($target_format =~ /rpm/i) {
        $target_format = "rpms";
    } elsif ($target_format =~ /deb/i) {
        $target_format = "debs";
    } else {
        $target_format = "all";
    }

    if (-d $pkg) {

        # It's a directory.  That means it's some type of module.
        if (!chdir($pkg)) {
            return (AVALON_SYSTEM_ERROR, "Unable to chdir into \"$pkg\" -- $!", undef);
        }
        if (-d "F") {
            # Okay, there's an F/ directory.  I bet it's an SPM.
            @ret = &build_spm($pkg, $topdir, $buildroot, $target_format);
        } elsif (-f "Makefile.avalon" && -s _) {
            # There's a custom Makefile.  It's a Custom Full Source Tree (FST).
            @ret = &build_cfst($pkg, $topdir, $buildroot, $target_format);
        } else {
            # If it's not either of the above, it better be a standard Full Source Tree (FST),
            # and it better conform to the proper assumptions or provide other instructions.
            @ret = &build_fst($pkg, $topdir, $buildroot, $target_format);
        }
        chdir($pwd);
        return @ret;
    } elsif (-f _ && -s _) {
        # It's a file.  Must be a package file of some type.

        # Split the actual package name from any path information.
        if ($pkg =~ m|^(.*)/([^/]+)$|) {
            my $module;

            ($module, $pkg) = ($1, $2);
            if (!chdir($module)) {
                return (AVALON_SYSTEM_ERROR, "Unable to chdir into \"$module\" -- $!", undef);
            }
        }
        if ($pkg =~ /src\.rpm$/) {
            @ret = &build_srpm($pkg, $topdir, $buildroot, $target_format);
        } elsif ($pkg =~ /\.(tar\.|t)(gz|Z|bz2)$/) {
            @ret = &build_tarball($pkg, $topdir, $buildroot, $target_format);
        } elsif ($pkg =~ /\.rpm$/) {
            return (AVALON_NO_SOURCES, "Alright...  Who's the wiseguy that told me to recompile \"$pkg,\" a binary RPM? :-P", undef);
        } else {
            return (AVALON_NO_SOURCES, "I'm sorry, but I don't know how to build \"$pkg.\"", undef);
        }
        chdir($pwd);
        return @ret;
    } else {
        # Okay, it's neither a file nor a directory.  What the hell is it?
        return (AVALON_NO_SOURCES, "I'm sorry, but I can't figure out what to do with \"$pkg.\"", undef);
    }
}

### Private functions


1;
