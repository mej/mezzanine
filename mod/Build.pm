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
# $Id: Build.pm,v 1.4 2001/07/25 02:57:32 mej Exp $
#

package Avalon::Build;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&count_cpus', '&prepare_build_tree', '&get_source_list', '&create_source_file', '&create_source_files', '&special_build', '&cleanup_build_tree');
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
sub prepare_build_tree($$$);
sub get_source_list($$$$);
sub create_source_file($$$$$);
sub create_source_files($$$\@);
sub special_build($$$);
sub cleanup_build_tree($$$);

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
prepare_build_tree
{
    my ($module, $buildroot, $cflags) = @_;
    my ($rpmmacros, $rpmrc);
    local *RPMMACROS;
    local *RPMRC;

    if (! -d "$module") {
        if (!mkdir("$module", 0755)) {
            &fatal_error("Cannot create $module -- $!\n");
        }
    }

    # Create the RPM directories also.  Same deal as above.
    foreach my $dir ("BUILD", "SRPMS", "RPMS", "SPECS", "SOURCES") {
        if (! -d "$module/$dir") {
            mkdir("$module/$dir", 0755) || &fatal_error("Cannot create $module/$dir -- $!\n");
        }
    }

    # If the build root exists, get rid of it, then make a new (empty) one.
    if (-d $buildroot) {
        nprint "Buildroot $buildroot exists.  I am removing it.\n";
        &nuke_tree($buildroot);
    }
    mkdir($buildroot, 0775);

    if (defined($cflags)) {
        $cflags =~ s/\&/ /g;
    } else {
        $cflags = $ENV{CFLAGS};
    }

    # Create basic rpmmacros
    $rpmmacros = "$buildroot/$pkg-rpmmacros";
    open(RPMMACROS, ">$rpmmacros") || &fatal_error("Cannot create $rpmmacros -- $!\n");
    print RPMMACROS "\%_topdir           $builddir\n";
    close(RPMMACROS);

    # Create basic rpmrc
    $rpmrc = "$buildroot/$pkg-rpmrc";
    open(RPMRC, ">$rpmrc") || &fatal_error("Cannot create $rpmrc -- $!\n");
    print RPMRC "optflags:   i386 $cflags\n";
    print RPMRC "optflags:   i486 $cflags\n";
    print RPMRC "optflags:   i586 $cflags\n";
    print RPMRC "optflags:   i686 $cflags\n";
    print RPMRC "macrofiles: /usr/lib/rpm/macros:/usr/lib/rpm/\%{_target}/macros:/etc/rpm/macros.specspo:",
                "/etc/rpm/macros:/etc/rpm/\%{_target}/macros:~/.rpmmacros:$rpmmacros\n";
    close(RPMRC);

    # Pre-scan all the binary RPM's for future use in possibly parallel processes.  We need
    # to know what SRPM each binary came from, because some (lame) packages change the base name.
    #if (! $opt_nocache) {
    #    nprint "Updating state information....\n";
    #    dprint "Scanning binary RPM's in $module/RPMS for their corresponding SRPM's.\n";
    #    @contents = glob("$module/RPMS/*/*.rpm");
    #    foreach my $rpm (@contents) {
    #        dprint "Checking $rpm\n";
    #        $srpm_of_rpm{$rpm} = `rpm -qp $rpm --queryformat \"%{SOURCERPM}\"`;
    #    }
    #}
}

sub
get_source_list
{
    my ($specfile, $module, $srcs, $destdir) = @_;
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
            next if (&should_ignore($fname));
            if (-d $fname) {
                my @tmp;

                @tmp = grep($_ =~ /^\Q$fname\E\.(tgz|tar\.gz|tar\.Z|tar\.bz2|tbz)$/, values %{$specdata->{SOURCE}});
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
    dprint "Sources:  ", join(", ", @{$specdata->{SOURCES}}), "\n";
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

# Build a package that has its own buildtool makefile
sub
special_build
{
    my ($module, $buildroot, $make) = @_;
    my ($err, $msg, $srpm, $cmd, $make, $rpmdir, $pwd, $outfiles);
    local *MAKE;

    if ($module) {
        $pwd = &getcwd();
        if (! chdir($module)) {
            return (AVALON_PACKAGE_FAILED, "Could not chdir into $module -- $!", 0);
        }
    }

    $rpmdir = "$module/RPMS";
    if (! $make) {
        $make = "make -f Makefile.avalon";
    }
    $cmd = "$make BUILD_DIR=$module BUILD_ROOT=$buildroot RPMRC=$buildroot/$pkg-rpmrc RPM_DIR=$rpmdir";

    dprint "About to run \"$cmd\"\n";
    if (!open(MAKE, "$cmd </dev/null 2>&1 |")) {
        return (1, "Execution of \"$cmd\" failed -- $!", undef);
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

    # Find the RPMs
    $outfiles = join(" ", &grepdir(sub {/\.rpm$/}, $rpmdir));
    if (! $outfiles) {
	dprint "No RPMS at $rpmdir\n";
        $err = AVALON_PACKAGE_FAILED;
        $msg = "Make returned good return code, but no RPMs at $rpmdir";
    }
    chdir($pwd) if (defined($pwd));
    return ($err, $msg, $outfiles);
}

# Clean up the RPM build directories and the build root
sub
cleanup_build_tree
{
    my ($module, $buildroot, $type) = @_;
    my @dirs;

    if ($type =~ /no(ne)?/i) {
        return;
    } elsif ($type =~ /temp/i) {
        @dirs = ("$module/BUILD", "$module/SOURCES", "$module/SPECS", $buildroot);
    } elsif ($type =~ /rpm/i) {
        @dirs = ("$module/BUILD", "$module/SOURCES", "$module/SRPMS", "$module/RPMS", "$module/SPECS");
    } elsif ($type =~ /(build)?root/) {
        @dirs = ($buildroot);
    } else {
        @dirs = ("$module/BUILD", "$module/SOURCES", "$module/SRPMS", "$module/RPMS", "$module/SPECS", $buildroot);
    }
    foreach my $f (@dirs) {
        nprint "$progname:  Cleaning up $f\n";
        &nuke_tree($f) || qprint "Warning:  Removal of $f failed -- $!\n";
    }
}

### Private functions


1;
