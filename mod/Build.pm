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
# $Id: Build.pm,v 1.1 2001/07/20 15:13:55 mej Exp $
#

package Avalon::Build;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.0;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ();
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

### Initialize private global variables

### Function prototypes

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

# Do the initial directory/file creation stuff.  Used to be in the
# bootstrap stage, but it's not parallel-safe.
sub
initial_setup
{
    my @contents;

    # Create the build directory if it doesn't exist.  If we can't, die.
    if (! -d "$builddir") {
        if (!mkdir("$builddir", 0755)) {
            &fatal_error("Cannot create $builddir -- $!\n");
        }
    }

    # Create the RPM directories also.  Same deal as above.
    foreach $dir ("BUILD", "SRPMS", "RPMS", "SPECS", "SOURCES") {
        if (! -d "$builddir/$dir") {
            mkdir("$builddir/$dir", 0755) || &fatal_error("Cannot create $builddir/$dir -- $!\n");
        }
    }

    # If the build root exists, get rid of it, then make a new (empty) one.
    if (-d $buildroot) {
        nprint "Buildroot $buildroot exists.  I am removing it.\n";
        &nuke_tree($buildroot);
    }
    mkdir($buildroot, 0775);

    chdir("$builddir");

    # Pre-scan all the binary RPM's for future use in possibly parallel processes.  We need
    # to know what SRPM each binary came from, because some (lame) packages change the base name.
    if (! $opt_nocache) {
        nprint "Updating state information....\n";
        dprint "Scanning binary RPM's in $builddir/RPMS for their corresponding SRPM's.\n";
        @contents = glob("$builddir/RPMS/*/*.rpm");
        foreach $rpm (@contents) {
            dprint "Checking $rpm\n";
            $srpm_of_rpm{$rpm} = `rpm -qp $rpm --queryformat \"%{SOURCERPM}\"`;
        }
    }
}

# Build package files
sub
build_pkgs
{
    my ($pkg, $filename) = @_;
    my ($cmd, $prog, $line, $target, $out_files, $rpmrc);
    my ($err, $msg, $srpm) = (0, 0, 0);
    local *PKGTOOL;

    $prog = ($pkgs->{$pkg}{RPMCMD} ? $pkgs->{$pkg}{RPMCMD} : "rpm");
    if ($pkgs->{$pkg}{MACROS}) {
        my @macro_list = split(",", $pkgs->{$pkg}{MACROS});
        my $macro;

        foreach $macro (@macro_list) {
            my ($name, $value) = split(":", $macro);

            $prog .= " --define \"$name $value\"";
        }
    }
    $rpmrc = "$buildroot/$pkg-rpmrc";
    # Create the rpmrc and rpmmacros files if they don't exist
    &create_rpm_files($pkg) if (! -s $rpmrc);
    $target = ($main::target ? " --target=$main::target" : ($pkgs->{$pkg}{ARCH} ? " --target=$pkgs->{$pkg}{ARCH}" : ""));
    $prog = "-P '$prog$target'";
    $cmd = "$pkgtool $prog -b -R \"/usr/lib/rpm/rpmrc:$rpmrc\" --root \"$buildroot/$pkg-root\" ";
    if ($pkgs->{$pkg}{TYPE} eq "tar") {
        $cmd .= "-p $filename";
    } else {
        $cmd .= "-s $filename";
    }
    if ($pkgs->{$pkg}{TAGFILE}) {
        $cmd .= " --tagfile $pkgs->{$pkg}{TAGFILE}";
    }
    # Run pkgtool with above parameters to build the package
    dprint "About to run \"$cmd\"\n";
    if (!open(PKGTOOL, "$cmd </dev/null 2>&1 |")) {
        return (1, "Execution of \"$cmd\" failed -- $!", undef);
    }
    $err = 0;
    while (<PKGTOOL>) {
        chomp($line = $_);
        nprint "$line\n";
        if ($line =~ /^pkgtool:\s+Error:\s+(.*)$/) {
            $msg = $1;
        } elsif ($line =~ /^Package files generated:\s+(.*)$/) {
            $out_files = $1;
        }
    }
    close(PKGTOOL);
    dprint "pkgtool returned $?\n";
    if ($? != 0 && $err == 0) {
        $err = $?;
        $msg = "Unhandled RPM build error" if (! $msg);
    }

    # Record output files for later use
    if ($out_files) {
        $pkgs->{$pkg}{OUTFILES} = $out_files;
        if ($out_files =~ /src\.rpm/) {
            ($srpm = $out_files) =~ s/^(.*\s+)?(\S+src\.rpm)(\s+.*)?$/$2/;
        }
    }
    dprint "build_pkgs():  Returning $err, $msg, $srpm\n";
    return ($err, $msg, $srpm);
}

# Generate source files and patches using pkgtool
sub
gen_sources
{
    my ($pkg, $specfile) = @_;
    my ($cmd, $prog, $line, $target, $srcs, $htag, $rtag, $tar, $zip, $rpmrc);
    my ($err, $msg) = (0, 0);
    local *PKGTOOL;

    # pkgtool does all the work.  Really this routine just sets up the parameters and
    # grabs the output.  There's nothing fancy going on here at all.
    $rpmrc = "$buildroot/$pkg-rpmrc";
    &create_rpm_files($pkg) if (! -s $rpmrc);
    $prog = ($pkgs->{$pkg}{RPMCMD} ? $pkgs->{$pkg}{RPMCMD} : "rpm");
    $target = ($pkgs->{$pkg}{ARCH} ? " --target=$pkgs->{$pkg}{ARCH}" : ($main::target ? $main::target : ""));
    $prog = "-P '$prog$target'";
    $srcs = ($pkgs->{$pkg}{SRCS} ? "-o '$pkgs->{$pkg}{SRCS}'" : "");
    if ($pkgs->{$pkg}{TAR}) {
        $tar = $pkgs->{$pkg}{TAR};
        $tar = "--tar '$tar'";
    } elsif ($pkgs->{$pkg}{ZIP}) {
        $zip = "--zip '$pkgs->{$pkg}{ZIP}'";
    }
    if ($pkgs->{$pkg}{REVISION}) {
        my $btp = &branch_tag_prefix();

        ($rtag, $htag) = split(":", $pkgs->{$pkg}{REVISION});
        if (! $htag && $rtag =~ /^$btp/) {
            $htag = $rtag;
            undef $rtag;
        }
    } elsif ($pkgs->{$pkg}{VERSION}) {
        $rtag = &pkg_to_release_tag($pkg, $pkgs->{$pkg}{VERSION});
        $htag = &pkg_to_branch_tag($pkg, $pkgs->{$pkg}{VERSION});
    }
    $rtag = ($rtag ? "-r $rtag" : "");
    $htag = ($htag ? "-t $htag" : "");
    $cmd = ("$pkgtool $prog -g -R \"/usr/lib/rpm/rpmrc:$rpmrc\" --root \"$buildroot/$pkg-root\""
            . " -s $specfile -D $builddir/SOURCES $srcs $htag $rtag");
    if ($pkgs->{$pkg}{TAGFILE}) {
        $cmd .= " --tagfile $pkgs->{$pkg}{TAGFILE}";
    }
    dprint "About to run \"$cmd\"\n";
    if (!open(PKGTOOL, "$cmd </dev/null 2>&1 |")) {
        return (1, "Execution of \"$cmd\" failed -- $!", undef);
    }
    $err = 0;
    while (<PKGTOOL>) {
        chomp($line = $_);
        nprint "$line\n";
        if ($line =~ /^pkgtool:\s+Error:\s+(.*)$/) {
            $msg = $1;
        }
    }
    close(PKGTOOL);
    dprint "pkgtool returned ", $? >> 8, "\n";
    if ($? != 0 && $err == 0) {
        $err = $? >> 8;
        $msg = "Unhandled RPM build error" if (! $msg);
    }
    dprint "gen_sources():  Returning $err, $msg\n";
    return ($err, $msg);
}

# Create the rpmrc and rpmmacros files for a package
sub
create_rpm_files
{
    my $pkg = $_[0];
    my ($rpmmacros, $rpmrc, $cflags);
    local *RPMMACROS;
    local *RPMRC;

    if (defined($pkgs->{$pkg}{CFLAGS})) {
        $cflags = $pkgs->{$pkg}{CFLAGS};
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
}

# Build a package that has its own buildtool makefile
sub
special_build
{
    my $pkg = $_[0];
    my ($err, $msg, $srpm, $cmd, $make, $rpmdir);
    local *MAKE;

    if (! chdir("$builddir/$pkgs->{$pkg}{MODULE}")) {
        return (AVALON_PACKAGE_FAILED, "Could not chdir into $builddir/$pkgs->{$pkg}{MODULE} -- $!", 0);
    }

    $rpmdir = "$builddir/$pkgs->{$pkg}{MODULE}/RPMS";
    $make = ($pkgs->{$pkg}{MAKE} ? $pkgs->{$pkg}{MAKE} : "make -f Makefile.avalon");
    $cmd = "$make BASE_DIR=$basedir BUILD_DIR=$builddir BUILD_ROOT=$buildroot RPMRC=$buildroot/$pkg-rpmrc RPM_DIR=$rpmdir";

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
    @rpms = &grepdir(sub {/\.rpm$/}, $rpmdir);
    if ($#rpms >= 0) {
	foreach $i (@rpms) {
	    $srpm = $rpmdir . "/" .$i if ($i =~ /\.src\.rpm$/);
	    $pkgs->{$pkg}{OUTFILES} .= $rpmdir . "/" . $i . " ";
	}
	dprint "Found RPMS: $pkgs->{$pkg}{OUTFILES}\n";
	dprint "Found SRPM: $srpm\n";
    } else {
	dprint "No RPMS at $rpmdir\n";
        $err = AVALON_PACKAGE_FAILED;
        $msg = "Make returned good return code, but no RPMs at $rpmdir";
    }
    chdir($builddir);
    return ($err, $msg, $srpm);
}


### Private functions


1;
