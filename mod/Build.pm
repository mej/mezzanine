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
# $Id: Build.pm,v 1.5 2001/07/26 03:13:50 mej Exp $
#

package Avalon::Build;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use Avalon::Pkg;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&count_cpus', '&prepare_build_tree', '&get_source_list', '&create_source_file', '&create_source_files', '&cleanup_build_tree', '&build_spm', '&build_cfst', '&build_fst', '&build_srpm', '&build_tarball', '&build_package');
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
sub build_spm($$$$);
sub build_cfst($$$$);
sub build_fst($$$$);
sub build_srpm($$$$$);
sub build_tarball($$$$$);
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
    my ($n, $t, $b) = @_;
    my ($name, $topdir, $buildroot);
    my ($rpmmacros, $rpmrc);
    local *RPMMACROS;
    local *RPMRC;

    # In order to alter the values of $name, $topdir, and $buildroot in the caller,
    # we are passed references to the variables, not the values.  The brief quantity
    # of goop below uses $n, $t, and $b as the references, then copies the values to
    # $name, $topdir, and $buildroot so that the rest of the code is readable. :-)
    if (! $$n) {
        $$n = &basename(&getcwd());
    }
    if (! $$t) {
        $$t = &getcwd() . "/build.avalon";
    }
    if (! $$b) {
        $$b = "/var/tmp/avalon-buildroot.$$/$name";
    }
    ($name, $topdir, $buildroot) = ($$n, $$t, $$b);
    ### End of reference-handling goop

    # If the topdir doesn't exist, create it.
    if (! -d "$topdir") {
        if (!mkdir("$topdir", 0755)) {
            &fatal_error("Cannot create $topdir -- $!\n");
        }
    }

    # Create the RPM directories also.  Same deal as above.
    foreach my $dir ("BUILD", "SRPMS", "RPMS", "SPECS", "SOURCES") {
        if (! -d "$topdir/$dir") {
            mkdir("$topdir/$dir", 0755) || &fatal_error("Cannot create $topdir/$dir -- $!\n");
        }
    }

    # If the build root exists, get rid of it, then make a new (empty) one.
    if (-d $buildroot) {
        nprint "Buildroot $buildroot exists.  I am removing it.\n";
        &nuke_tree($buildroot);
    }
    mkdir($buildroot, 0775);

    # Create basic rpmmacros
    $rpmmacros = "$buildroot/$pkg-rpmmacros";
    open(RPMMACROS, ">$rpmmacros") || &fatal_error("Cannot create $rpmmacros -- $!\n");
    print RPMMACROS "\%_topdir           $topdir\n";
    close(RPMMACROS);

    # Create basic rpmrc
    $rpmrc = "$buildroot/$pkg-rpmrc";
    open(RPMRC, ">$rpmrc") || &fatal_error("Cannot create $rpmrc -- $!\n");
    print RPMRC "optflags:   i386 $$ENV{CFLAGS}\n";
    print RPMRC "optflags:   i486 $$ENV{CFLAGS}\n";
    print RPMRC "optflags:   i586 $$ENV{CFLAGS}\n";
    print RPMRC "optflags:   i686 $$ENV{CFLAGS}\n";
    print RPMRC "macrofiles: /usr/lib/rpm/macros:/usr/lib/rpm/\%{_target}/macros:/etc/rpm/macros.specspo:",
                "/etc/rpm/macros:/etc/rpm/\%{_target}/macros:~/.rpmmacros:$rpmmacros\n";
    close(RPMRC);

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

    if ($module && (!chdir($module))) {
        return AVALON_BAD_MODULE;
    }
    if ($destdir && $destdir !~ /\/$/) {
        $destdir .= "/";
    }
    &parse_spec_file($specfile) if ($specfile);

    if ($srcs) {
        @srcs = split(/[\s,]/, $srcs);
    } elsif (-s "avalon.srcs") {
        @srcs = &parse_srcs_file("avalon.srcs");
    } else {
        my $fname;

        wprint "No SRCS variable found.  Proceeding with default assumptions.  If the assumptions don't work,\n";
        wprint "you will need to create an avalon.srcs file for this package.\n";

        foreach my $fname (&grepdir(sub {! &should_ignore($_);}, ".")) {
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

    dprint "Preparing to generate sources \"", join(" ", @srcs), "\".\n";
    return @srcs;
}

sub
create_source_file
{
    my ($src_files, $tarball, $destdir, $tar, $zip) = @_;
    my $cmd;
    local *CMD;

    dprint "Source files:  \"$src_files\"\n";
    if ($tarball) {
        print "Generating $tarball...\n";
        $destdir .= '/' if (substr($destdir, -1, 1) ne '/');
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
        dprint "Creating $tarball:  $cmd\n";
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
        dprint "Command returned $?\n";
        if ($?) {
            eprint "Creation of vendor source tarball $tarball failed\n";
            return AVALON_BUILD_FAILURE;
        }
    } else {
        my $rc;

        print "Copying $src_files to $destdir.\n";
        $rc = system("cp -f $src_files $destdir") >> 8;
        if ($rc) {
            eprint "Unable to copy $src_files to $destdir -- $!\n";
            return AVALON_BUILD_FAILURE;
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
        @dirs = ("$topdir/BUILD", "$topdir/SOURCES", "$topdir/SPECS", $buildroot);
    } elsif ($type =~ /rpm/i) {
        @dirs = ("$topdir/BUILD", "$topdir/SOURCES", "$topdir/SRPMS", "$topdir/RPMS", "$topdir/SPECS");
    } elsif ($type =~ /(build)?root/) {
        @dirs = ($buildroot);
    } else {
        @dirs = ("$topdir/BUILD", "$topdir/SOURCES", "$topdir/SRPMS", "$topdir/RPMS", "$topdir/SPECS", $buildroot);
    }
    foreach my $f (@dirs) {
        nprint "$progname:  Cleaning up $f\n";
        &nuke_tree($f) || qprint "Warning:  Removal of $f failed -- $!\n";
    }
}

# This function knows how to build packages from Source Package Modules (SPM's).  It
# is usually called by build_package() but can be called directly as long as the
# chdir() has been done already and we're 100% certain that it's an SPM.
sub
build_spm
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;

}

# This function handles the "special case" FST's which have their very own
# Makefile.avalon.  As with build_spm(), the chdir() must have already been done.
sub
build_cfst
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my ($err, $msg, $cmd, $make, $pkgdir, $outfiles);
    local *MAKE;

    if (!(-f "Makefile.avalon" && -s _)) {
        &show_backtrace();
        &fatal_error("Call to build_cfst() in non-CFST module.\n");
    }
    &prepare_build_tree($pkg, $topdir, $buildroot);

    $make = "make -f Makefile.avalon";
    $cmd = "$make $target_format BUILD_DIR=$topdir BUILD_ROOT=$buildroot RPMRC=$buildroot/$pkg-rpmrc PKG_DIR=$pkgdir";

    dprint "About to run \"$cmd\"\n";
    if (!open(MAKE, "$cmd </dev/null 2>&1 |")) {
        return (AVALON_COMMAND_FAILED, "Execution of \"$cmd\" failed -- $!", undef);
    }
    $err = 0;
    while (<MAKE>) {
        chomp($line = $_);
        nprint "$line\n";
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

    # Look for the build instructions (spec file, debian/ directory, etc.)
    if ($target_format eq "rpms") {
        @tmp = &grep_dir(sub {/spec(\.in)?$/}, ".");
    } elsif ($target_format eq "debs") {
        @tmp = &grep_dir(sub {$_ =~ m/debian/ && -d $_}, ".");
    } else {
        @tmp = &grep_dir(sub {/spec(\.in)?$/ || ($_ =~ m/debian/ && -d $_)}, ".");
    }
    if (!scalar(@tmp)) {
        return (AVALON_BAD_PACKAGE, "I'm sorry, but \"$pkg\" doesn't seem to have instructions for building $target_format", undef);
    }
    $specfile = $tmp[0];
    if (! &cp($specfile, "$topdir/SPECS/")) {
        return (AVALON_SYSTEM_ERROR, "Unable to copy $specfile to $topdir/SPECS/ -- $!\n", undef);
    }
    # Get ready to build, figure out what sources we need, and create them all.
    &prepare_build_tree($pkg, $topdir, $buildroot);
    @srcs = &get_source_list($specfile, ".", undef);
    $ret = &create_source_files("$topdir/SOURCES", undef, undef, @srcs);
    if ($ret != AVALON_SUCCESS) {
        return ($ret, "Creation of source files failed", undef);
    }

    return &build_topdir($topdir, $buildroot, $target_format);
}

# Source RPM's can be rebuilt with this function.  build_package() usually handles the
# extraction of the module name, but this function can be called directly as long as
# that isn't an issue or has already been taken care of by the calling function.
sub
build_srpm
{
    my ($pkg, $module, $topdir, $buildroot, $target_format) = @_;

    &prepare_build_tree($pkg, $topdir, $buildroot);
    # Explode SRPM here
    return &build_topdir($topdir, $buildroot, $target_format);
}

# Plain old tarballs can be rebuilt into packages using this function, as long as they
# contain the necessary file(s) inside them (spec file and/or debian/ directory).
sub
build_tarball
{
    my ($pkg, $module, $topdir, $buildroot, $target_format) = @_;

}

# This is the main routine for building stuff.  Its job is to figure out what type of
# stuff it is that you're trying to build, and then call the right function to build it.
sub
build_package
{
    my ($pkg, $topdir, $buildroot, $target_format) = @_;
    my $pwd;

    $pwd = &getcwd();

    if ($target_format =~ /rpm/i) {
        $target_format = "rpms";
        $pkgdir = "$topdir/RPMS";
    } elsif ($target_format =~ /deb/i) {
        $target_format = "debs";
    } else {
        $target_format = "all";
    }

    if (-d $pkg) {
        # It's a directory.  That means it's some type of module.
        if (!chdir($pkg)) {
            eprint "Unable to chdir into \"$pkg\" -- $!\n";
            return AVALON_SYSTEM_ERROR;
        }
        if (-d "F") {
            # Okay, there's an F/ directory.  I bet it's an SPM.
            return &build_spm(".", $topdir, $buildroot, $target_format);
        } elsif (-f "Makefile.avalon" && -s _) {
            # There's a custom Makefile.  It's a Custom Full Source Tree (FST).
            return &build_cfst(".", $topdir, $buildroot, $target_format);
        } else {
            # If it's not either of the above, it better be a standard Full Source Tree (FST),
            # and it better conform to the proper assumptions or provide other instructions.
            return &build_fst(".", $topdir, $buildroot, $target_format);
        }
    } elsif (-f _ && -s _) {
        # It's a file.  Must be a package file of some type.
        my $module;

        # Split the actual package name from any path information.
        if ($pkg =~ m|^(.*)/([^/]+)$|) {
            ($module, $pkg) = ($1, $2);
        } else {
            $module = $pwd;
        }
        if ($pkg =~ /src\.rpm$/) {
            return &build_srpm($pkg, $module, $topdir, $buildroot, $target_format);
        } elsif ($pkg =~ /\.(tar\.|t)(gz|Z|bz2)$/) {
            return &build_tarball($pkg, $module, $topdir, $buildroot, $target_format);
        } elsif ($pkg =~ /\.rpm$/) {
            eprint "Alright...  Who's the wiseguy that told me to recompile \"$pkg,\" a binary RPM? :-P\n";
            return AVALON_BAD_PACKAGE;
        } else {
            eprint "I'm sorry, but I don't know how to build \"$pkg.\"\n";
            return AVALON_BAD_PACKAGE;
        }
    } else {
        # Okay, it's neither a file nor a directory.  What the hell is it?
        eprint "I'm sorry, but I can't figure out what to do with \"$pkg.\"\n";
        return AVALON_BAD_PACKAGE;
    }
    return AVALON_SUCCESS;
}

### Private functions


1;
