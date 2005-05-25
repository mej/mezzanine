# Mezzanine Build Perl Module
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
# $Id: Build.pm,v 1.48 2005/05/25 16:14:56 mej Exp $
#

package Mezzanine::Build;
use strict;
use Exporter;
use POSIX;
use File::Copy;
use Mezzanine::Util;
use Mezzanine::PkgVars;
use Mezzanine::Pkg;
use Mezzanine::Src;
use Mezzanine::RPM;
use Mezzanine::Deb;
use Mezzanine::Tar;
use Mezzanine::Prod;
use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

BEGIN {
    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('&count_cpus', '&set_hints_info', '&set_instroot_info',
               '&prepare_build_tree', '&install_hints',
               '&install_deps', '&get_source_list',
               '&create_source_file', '&create_source_files',
               '&cleanup_build_tree', '&build_rpms_from_tarball',
               '&build_debs_from_tarball', '&build_rpms_from_topdir',
               '&build_debs_from_topdir', '&build_topdir',
               '&build_spm', '&build_cfst', '&build_fst',
               '&build_srpm', '&build_tarball', '&build_package');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables
my @my_dirs = ();

### Initialize exported package variables

### Initialize private global variables

### Function prototypes
sub count_cpus();
sub set_hints_info($);
sub set_instroot_info($$$$);
sub prepare_build_tree($$$);
sub install_hints();
sub install_deps($);
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

# Set up hint directory and builddep installer.
sub
set_hints_info($)
{
    my ($hint, $installer) = @_;

    if ($hint && index($hint, '%') >= 0) {
        ($installer, $hint) = split('%', $hint);
    }
    if (! $hint) {
        $hint = &pkgvar_get("hints");
    }
    if (! $installer) {
        $installer = &pkgvar_get("dep_installer");
    }
    &pkgvar_set("hints", $hint);
    &pkgvar_set("dep_installer", $installer);
    return (&pkgvar_get("hints"), &pkgvar_get("dep_installer"));
}

# Set up instroot info
sub
set_instroot_info($$$$)
{
    my ($instroot, $instroot_init, $instroot_reset, $instroot_copy) = @_;

    if (! $instroot) {
        return ("", "", "", "");
    }

    &pkgvar_instroot($instroot);

    # Set INSTROOT_* using fallbacks.
    if (! $instroot_reset && $instroot_init) {
        $instroot_reset = $instroot_init;
    }
    if (! $instroot_copy && $instroot_init) {
        $instroot_copy = $instroot_init;
    }
    return ($instroot, $instroot_init, $instroot_reset, $instroot_copy);
}

# Create the RPM build directories, the buildroot, and the RPM config files
sub
prepare_build_tree
{
    my ($name, $topdir, $buildroot, $instroot, $instructions, $rpmmacros, $rpmrc, $ret);
    local *RPMMACROS;
    local *RPMRC;

    $name = &pkgvar_name();
    $topdir = &pkgvar_topdir();
    $buildroot = &pkgvar_buildroot();
    $instroot = &pkgvar_instroot();
    $instructions = &pkgvar_instructions();
    if (! $name) {
        $name = &basename(&getcwd());
    }
    if (! $topdir) {
        $topdir = &getcwd() . "/build.mezz";
    }
    if (! $buildroot) {
        $buildroot = "/var/tmp/mezzanine-buildroot.$$/$name";
    }

    dprint "$name | $topdir | $buildroot | $instroot | $instructions\n";
    &pkgvar_name($name);
    &pkgvar_topdir($topdir);
    &pkgvar_buildroot($buildroot);

    # If the topdir doesn't exist, create it.
    if (! -d $topdir) {
        if (!&mkdirhier($topdir, 0755)) {
            &fatal_error("Cannot create $topdir -- $!\n");
        }
        dprint "Created $topdir.\n";
        xpush @my_dirs, $topdir;
    }
    if ($instroot && ! -d "$instroot$topdir") {
        if (! -d $instroot) {
            xpush @my_dirs, $instroot;
        }
        dprint "Creating $instroot$topdir with mkdirhier().\n";
        if (! &mkdirhier("$instroot$topdir", 0755)) {
            &fatal_error("Cannot create $instroot$topdir -- $!\n");
        }
        xpush @my_dirs, "$instroot$topdir";
    }
    if ($instroot && $instructions && -e $instructions) {
        &pkgvar_instructions("$topdir/$instructions");
        &copy_files($instructions, $instroot . &pkgvar_instructions());
    }

    # Create the RPM directories also.  Same deal as above.
    foreach my $dir ("BUILD", "SRPMS", "RPMS", "SPECS", "SOURCES") {
        if (! -d "$topdir/$dir") {
            if (-f "$topdir/$dir") {
                # It's a bogus file.  Nuke it.
                &nuke_tree("$topdir/$dir");
            }
            dprint "I'm creating $topdir/$dir.\n";
            &mkdirhier("$topdir/$dir", 0755) || &fatal_error("Cannot create $topdir/$dir -- $!\n");
            xpush @my_dirs, "$topdir/$dir";
        }
        if ($instroot && ! -d "$instroot$topdir/$dir") {
            if (-f "$instroot$topdir/$dir") {
                # It's a bogus file.  Nuke it.
                &nuke_tree("$instroot$topdir/$dir");
            }
            dprint "I'm also creating $instroot$topdir/$dir.\n";
            &mkdirhier("$instroot$topdir/$dir", 0755) || &fatal_error("Cannot create $instroot$topdir/$dir -- $!\n");
            xpush @my_dirs, "$instroot$topdir/$dir";
        }
    }

    # If the build root exists and we're not already using it,
    # get rid of it and create a new (empty) one.
    if (-d $buildroot && !grep(/\Q$buildroot\E/, @my_dirs)) {
        &nuke_tree($buildroot);
    }
    &mkdirhier($buildroot, 0775);
    xpush @my_dirs, $buildroot;

    if ($instroot && ! -d "$instroot$buildroot") {
        dprint "Creating $instroot$buildroot with mkdirhier().\n";
        if (! &mkdirhier("$instroot$buildroot", 0755)) {
            &fatal_error("Cannot create $instroot$buildroot -- $!\n");
        }
        xpush @my_dirs, "$instroot$buildroot";
    }

    dprint "I created:  ", join(" ", @my_dirs), "\n";

    $ret = &install_hints();
    if ($ret) {
        wprint "Hint installation failed:  $ret\n";
    }

    return ($name, $topdir, $buildroot);
}

# Install hint packages into buildroot if needed.
sub
install_hints($)
{
    my $hints = $_[0] || &pkgvar_get("hints");
    my $inst;
    my @hint_packages;
    local *HINTFILE;

    if (! $hints) {
        dprint "No hint information provided.\n";
        return "";
    }

    if (-d $hints) {
        if (&pkgvar_type() eq "rpm") {
            my @tmp = &parse_rpm_name(&pkgvar_filename());
            $hints = "$hints/$tmp[0]";
        } else {
            $hints = "$hints/" . &pkgvar_name();
        }
        if (! -e $hints) {
            dprintf("No hints file (%s) for %s package %s.\n",
                    $hints, &pkgvar_type(), &pkgvar_name());
            return "";
        }
    }

    if (!open(HINTFILE, $hints)) {
        return "Unable to open hint file $hints -- $!";
    }
    while (<HINTFILE>) {
        my $line;

        chomp($line = $_);
        xpush @hint_packages, $line;
    }
    close(HINTFILE);

    # Install hints.
    dprintf("Installing hints:  %s\n", join(' ', @hint_packages));
    return &install_deps(join(' ', @hint_packages));
}

# Install dependencies.
sub
install_deps($)
{
    my $deps = $_[0];
    my ($inst, $err);
    my @tmp;

    if (! $deps) {
        dprint "Nothing to do.\n";
        return "";
    }
    dprint "Installing the following:  $deps\n";

    if (&pkgvar_instroot()) {
        $inst = "chroot " . &pkgvar_instroot() . ' ';
    } else {
        $inst = "";
    }
    $inst .= &pkgvar_get("dep_installer");
    @tmp = &run_cmd($inst, $deps, "pkg-installer:  ");
    if (($err = shift @tmp) != MEZZANINE_SUCCESS) {
        return "Unable to install $deps ($err)";
    }

    return "";
}

sub
get_source_list
{
    my @srcs;

    dprint &print_args(@_);

    if (! &pkgvar_srcs()) {
        my $fname;

        wprint "No SRCS variable found.  Proceeding with default assumptions.  If the assumptions don't work,\n";
        wprint "you will need to create a prod.mezz file for this package.\n";

        &parse_spec_file();

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
        &pkgvar_srcs(join(',', @srcs));
    }

    dprint "Using SRCS variable \"${\(&pkgvar_srcs())}\".\n";
}

sub
create_source_file
{
    my ($src_files, $tarball, $destdir) = @_;
    my ($cmd, $tar, $zip);
    local *CMD;

    dprint &print_args(@_);

    $tar = &pkgvar_tar();
    $zip = &pkgvar_zip();
    $destdir = &pkgvar_instroot() if (! $destdir);
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
            $cmd = "tar --owner=root --group=root "
                   . "--exclude CVS --exclude RCS --exclude BitKeeper --exclude SCCS"
                   . "$zip -cf ${destdir}$tarball $src_files";
        }
        unlink($tarball);
        if (!open(CMD, "$cmd 2>&1 |")) {
            eprint "Execution of \"$cmd\" failed -- $!\n";
            return MEZZANINE_COMMAND_FAILED;
        }
        while (<CMD>) {
            my $line;

            chomp($line = $_);
            print "tar output -> $line\n";
        }
        close(CMD);
        if ($?) {
            dprint "Command returned $?\n";
            eprint "Creation of vendor source tarball $tarball failed\n";
            return MEZZANINE_BUILD_FAILURE;
        }
    } else {
        dprint "Copying $src_files to $destdir.\n";
        if (!&copy_files(split(' ', $src_files), $destdir)) {
            return MEZZANINE_SYSTEM_ERROR;
        }
    }
    return MEZZANINE_SUCCESS;
}

sub
create_source_files($)
{
    my $destdir = shift;
    my ($err, $src_files, $tarball);

    # Create all the source files we need.
    foreach my $src (split(',', &pkgvar_srcs())) {
        ($src_files, $tarball) = split(":", $src);
        $src_files =~ s/\&/ /g;
        $err = &create_source_file($src_files, $tarball, $destdir);
        if ($err) {
            return $err;
        }
    }
    return MEZZANINE_SUCCESS;
}

# Clean up the RPM build directories and the build root
sub
cleanup_build_tree
{
    my ($topdir, $buildroot, $instroot, $type);
    my @dirs;

    $topdir = &pkgvar_topdir();
    $buildroot = &pkgvar_buildroot();
    $instroot = &pkgvar_instroot();
    $type = &pkgvar_cleanup();

    dprint "$topdir | $buildroot | $instroot | $type\n";
    dprint "Only allowing cleaning in:  ", join(" ", @my_dirs), "\n";

    if ($type =~ /no(ne)?/i) {
        return;
    } elsif ($type =~ /temp/i || $type =~ /mej/i) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES", "$topdir/SPECS") if ($topdir);
        push(@dirs, "$instroot$topdir/BUILD", "$instroot$topdir/SOURCES", "$instroot$topdir/SPECS") if ("$instroot$topdir");
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /orc/i) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES") if ($topdir);
        push(@dirs, "$instroot$topdir/BUILD", "$instroot$topdir/SOURCES") if ("$instroot$topdir");
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /rpm/i) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES", "$topdir/SRPMS", "$topdir/RPMS", "$topdir/SPECS") if ($topdir);
        push(@dirs, "$instroot$topdir/BUILD", "$instroot$topdir/SOURCES", "$instroot$topdir/SRPMS",
             "$instroot$topdir/RPMS", "$instroot$topdir/SPECS") if ("$instroot$topdir");
    } elsif ($type =~ /buildroot/) {
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /instroot/) {
        push(@dirs, $instroot) if ($instroot);
    } elsif ($type =~ /build/) {
        push(@dirs, "$topdir/BUILD", "$topdir/SOURCES", "$topdir/SRPMS", "$topdir/RPMS", "$topdir/SPECS") if ($topdir);
        push(@dirs, "$instroot$topdir/BUILD", "$instroot$topdir/SOURCES", "$instroot$topdir/SRPMS",
             "$instroot$topdir/RPMS", "$instroot$topdir/SPECS") if ("$instroot$topdir");
        push(@dirs, $buildroot) if ($buildroot);
    } elsif ($type =~ /all/) {
        push(@dirs, $topdir) if ($topdir);
        push(@dirs, $instroot) if ($instroot);
        push(@dirs, $buildroot) if ($buildroot);
    } else {
        dprint "Unknown cleaning type \"$type\"\n";
        return;
    }
    if (scalar(@dirs)) {
        foreach my $f (@dirs) {
            dprint "Cleaning $f?\n";
            if (! -e $f) {
                dprint "No; it no longer exists.\n";
                next;
            }
            if (!scalar(grep(($_ eq $f), @my_dirs))) {
                dprint "No; I did not create it.\n";
                next;
            }
            dprint "Yes.\n";
            &nuke_tree($f);
        }
    }
}

# Builds RPM's from a tarball
sub
build_rpms_from_tarball
{
    return &rpm_build();
}

# Builds DEB files from a tarball
sub
build_debs_from_tarball
{
    my $cmd;

    ### FIXME:  This needs to be fixed for Debian
    $cmd = &deb_form_command("build");
    if (&pkgvar_instructions()) {
        $cmd .= " -ba " . &pkgvar_instructions();
    } elsif (&pkgvar_filename()) {
        # Paranoia
        $cmd .= " --rebuild " . &pkgvar_filename();
    } else {
        &show_backtrace();
        &fatal_error("Bad call to build_debs_from_topdir()!\n");
    }
    return &deb_build($cmd);
}

# Builds RPM's from a topdir
sub
build_rpms_from_topdir
{
    return &rpm_build();
}

# Builds DEB files from an RPM-style topdir
sub
build_debs_from_topdir
{
    my $cmd;

    ### FIXME:  This needs to be fixed for Debian
    $cmd = &deb_form_command("build");
    if (&pkgvar_instructions()) {
        $cmd .= " -ba " . &pkgvar_instructions();
    } elsif (&pkgvar_filename()) {
        # Paranoia
        $cmd .= " --rebuild " . &pkgvar_filename();
    } else {
        &show_backtrace();
        &fatal_error("Bad call to build_rpms_from_topdir()!\n");
    }
    return &deb_build($cmd);
}

# build_topdir() is called once the RPM/DEB directories have been propogated with all
# the right stuff.  It, in turn, calls the target-specific function above.
sub
build_topdir
{
    dprint &print_args(@_);

    if (&pkgvar_target() eq "rpms") {
        return &build_rpms_from_topdir();
    } elsif (&pkgvar_target() eq "debs") {
        return &build_debs_from_topdir();
    } else {
        my ($err, $msg, $outfiles);

        &pkgvar_target("rpms");
        ($err, $msg, $outfiles) = &build_rpms_from_topdir();
        if ($err) {
            return ($err, $msg, $outfiles);
        }
        &pkgvar_target("debs");
        return &build_debs_from_topdir();
    }
}

# This function knows how to build packages from Source Package Modules (SPM's).  It
# is usually called by build_package() but can be called directly as long as the
# chdir() has been done already and we're 100% certain that it's an SPM.
sub
build_spm
{
    my ($specfile, $topdir, $instroot);
    my (@tmp, @tmp2);

    dprint &print_args(@_);

    if (! -d "F") {
        &show_backtrace();
        &fatal_error("Call to build_spm() in non-SPM module.\n");
    }
    &prepare_build_tree();
    $topdir = &pkgvar_topdir();
    $instroot = &pkgvar_instroot();

    $specfile = &find_spec_file(&pkgvar_name(), "F");
    if (! $specfile) {
        return (MEZZANINE_MISSING_FILES, "@{[getcwd()]} does not seem to contain build instructions", undef);
    } else {
        &copy_files($specfile, "$topdir/SPECS");
        &copy_files($specfile, "$instroot$topdir/SPECS");
        $specfile = "$topdir/SPECS/" . &basename($specfile);

        &pkgvar_instructions($instroot . $specfile);
        &parse_spec_file();

        if ($specdata) {
            if (!&pkgvar_get("allow_epoch") && exists($specdata->{"HEADER"}{"epoch"})) {
                my $str;

                $str = sprintf("Epoch %s not allowed", $specdata->{"HEADER"}{"epoch"});
                return (MEZZANINE_SPEC_ERRORS, $str, undef);
            }
            if ($specdata->{"BUILD_DEPS"} && scalar(@{$specdata->{"BUILD_DEPS"}})) {
                my $ret;

                $ret = &install_deps(join(' ', @{$specdata->{"BUILD_DEPS"}}));
                if ($ret) {
                    wprint "Build dependency installation failed:  $ret\n";
                }
            }
        }
        &pkgvar_instructions($specfile);
    }

    @tmp = &grepdir(sub {-f $_ && -s _}, "S");
    @tmp2 = &grepdir(sub {-f $_ && -s _}, "P");
    if (!scalar(@tmp)) {
        @tmp = @tmp2;
    } elsif (scalar(@tmp2)) {
        push @tmp, @tmp2;
    }
    if (scalar(@tmp)) {
        &copy_files(@tmp, "$instroot$topdir/SOURCES");
    }

    # Parse the prod file for this SPM if it exists.
    if (&parse_prod_file()) {
        my $pkg = &pkgvar_name();

        if ($pkgs->{$pkg}{SRCS}) {
            &pkgvar_srcs($pkgs->{$pkg}{SRCS});
        }
        if ($pkgs->{$pkg}{ARCH}) {
            &pkgvar_architecture($pkgs->{$pkg}{ARCH});
        }
    }
    return &build_topdir();
}

# This function knows how to build packages from Package Development
# Repositories (PDR's).  It is usually called by build_package() but
# can be called directly as long as the chdir() has been done already
# and we're 100% certain that it's a PDR.
sub
build_pdr
{
    my ($specfile, $topdir, $instroot);
    my (@tmp, @tmp2);

    dprint &print_args(@_);

    &prepare_build_tree();
    $topdir = &pkgvar_topdir();
    $instroot = &pkgvar_instroot();

    $specfile = &find_spec_file(&pkgvar_name(), "F");
    if (! $specfile) {
        return (MEZZANINE_MISSING_FILES, "@{[getcwd()]} does not seem to contain build instructions", undef);
    }
    &copy_files($specfile, "$topdir/SPECS");
    &copy_files($specfile, "$instroot$topdir/SPECS");
    $specfile = "$topdir/SPECS/" . &basename($specfile);

    &pkgvar_instructions($instroot . $specfile);
    if (! $specdata || (&basename($specdata->{"SPECFILE"}) ne &basename($specfile))) {
        &parse_spec_file();
    }

    if ($specdata) {
        if (!&pkgvar_get("allow_epoch") && exists($specdata->{"HEADER"}{"epoch"})) {
            my $str;

            $str = sprintf("Epoch %s not allowed", $specdata->{"HEADER"}{"epoch"});
            return (MEZZANINE_SPEC_ERRORS, $str, undef);
        }

        if ($specdata->{"BUILD_DEPS"} && scalar(@{$specdata->{"BUILD_DEPS"}})) {
            my $ret;

            $ret = &install_deps(join(' ', @{$specdata->{"BUILD_DEPS"}}));
            if ($ret) {
                wprint "Build dependency installation failed:  $ret\n";
            }
        }
    }
    &pkgvar_instructions($specfile);

    @tmp = map { $specdata->{"SOURCE"}{$_} } @{$specdata->{"SOURCES"}};
    push @tmp, map { $specdata->{"PATCH"}{$_} } @{$specdata->{"PATCHES"}};

    if (scalar(@tmp)) {
        &copy_files(@tmp, "$instroot$topdir/SOURCES");
    }

    # Parse the prod file for this PDR if it exists.
    if (&parse_prod_file()) {
        my $pkg = &pkgvar_name();

        if ($pkgs->{$pkg}{SRCS}) {
            &pkgvar_srcs($pkgs->{$pkg}{SRCS});
        }
        if ($pkgs->{$pkg}{ARCH}) {
            &pkgvar_architecture($pkgs->{$pkg}{ARCH});
        }
    }
    return &build_topdir();
}

# This function handles the "special case" FST's which have their very own
# Makefile.mezz.  As with build_spm(), the chdir() must have already been done.
sub
build_cfst
{
    my ($err, $msg, $cmd, $pkgdir, $outfiles, $topdir, $buildroot, $target_format);
    local *MAKE;

    dprint &print_args(@_);

    if (!(-f "Makefile.mezz" && -s _)) {
        &show_backtrace();
        &fatal_error("Call to build_cfst() in non-CFST module.\n");
    }

    &prepare_build_tree();
    $topdir = &pkgvar_topdir();
    $buildroot = &pkgvar_buildroot();
    $target_format = &pkgvar_target();
    $pkgdir = "$topdir/RPMS";

    if (&pkgvar_instroot()) {
        $pkgdir = &pkgvar_instroot() . $pkgdir;
        if (&pkgvar_command()) {
            $cmd = sprintf("chroot %s %s", &pkgvar_instroot(), &pkgvar_command());
        } else {
            $cmd = sprintf("chroot %s make -f Makefile.mezz", &pkgvar_instroot());
        }
    } elsif (&pkgvar_command()) {
        $cmd = &pkgvar_command();
    } else {
        $cmd = "make -f Makefile.mezz";
    }
    $cmd .= " BUILD_DIR=$topdir BUILD_ROOT=$buildroot PKG_DIR=$pkgdir TARGET=$target_format";
    if (&pkgvar_rcfile()) {
        $cmd .= " RCFILE=" . &pkgvar_rcfile();
    }

    dprint "About to run \"$cmd\"\n";
    if (!open(MAKE, "$cmd </dev/null 2>&1 |")) {
        return (MEZZANINE_COMMAND_FAILED, "Execution of \"$cmd\" failed -- $!", undef);
    }
    $err = 0;
    while (<MAKE>) {
        my $line;

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
        $err = MEZZANINE_PACKAGE_FAILED;
        $msg = "make finished successfully, but no packages were found in $pkgdir";
    }
    return ($err, $msg, $outfiles);
}

# All other FST's (those without their own Makefiles) are built here.  Once again, this
# function can be called directly as long as the current directory is the FST to build.
sub
build_fst
{
    my ($specfile, $cmd, $ret, $topdir, $buildroot, $instroot, $target_format, $pkgdir, $pkg);
    my (@srcs, @tmp);

    dprint &print_args(@_);

    &prepare_build_tree();
    $pkg = &pkgvar_name();
    $topdir = &pkgvar_topdir();
    $buildroot = &pkgvar_buildroot();
    $instroot = &pkgvar_instroot();
    $target_format = &pkgvar_target();
    $specfile = &pkgvar_instructions();
    $pkgdir = "$instroot$topdir/RPMS";

    # Look for the build instructions (spec file, debian/ directory, etc.)
    if (! $specfile || ! -f $specfile) {
        if ($target_format eq "rpms") {
            @tmp = &grepdir(sub {/spec(\.in)?$/});
        } elsif ($target_format eq "debs") {
            @tmp = &grepdir(sub {$_ =~ m/debian/ && -d $_});
        } else {
            @tmp = &grepdir(sub {/spec(\.in)?$/ || ($_ =~ m/debian/ && -d $_)});
        }
        dprint @tmp, "\n";
        if (!scalar(@tmp)) {
            return (MEZZANINE_MISSING_FILES, "I'm sorry, but \"$pkg\" doesn't seem to have instructions for building $target_format", undef);
        }
        $specfile = &pkgvar_instructions($tmp[0]);
    }

    if (! &copy($specfile, "$instroot$topdir/SPECS/")) {
        return (MEZZANINE_SYSTEM_ERROR, "Unable to copy $specfile to $instroot$topdir/SPECS/ -- $!\n", undef);
    } else {
        &parse_spec_file();
        if ($specdata) {
            if (!&pkgvar_get("allow_epoch") && exists($specdata->{"HEADER"}{"epoch"})) {
                my $str;

                $str = sprintf("Epoch %s not allowed", $specdata->{"HEADER"}{"epoch"});
                return (MEZZANINE_SPEC_ERRORS, $str, undef);
            }
            if ($specdata->{"BUILD_DEPS"} && scalar(@{$specdata->{"BUILD_DEPS"}})) {
                my $ret;

                $ret = &install_deps(join(' ', @{$specdata->{"BUILD_DEPS"}}));
                if ($ret) {
                    wprint "Build dependency installation failed:  $ret\n";
                }
            }
        }
        &pkgvar_instructions("$topdir/SPECS/" . &basename($specfile));
    }

    # Get ready to build, figure out what sources we need, and create them all.
    if (&parse_prod_file()) {
        my $pkg = &pkgvar_name();

        if ($pkgs->{$pkg}{SRCS}) {
            &pkgvar_srcs($pkgs->{$pkg}{SRCS});
        }
        if ($pkgs->{$pkg}{ARCH}) {
            &pkgvar_architecture($pkgs->{$pkg}{ARCH});
        }
    }

    &get_source_list();
    $ret = &create_source_files("$instroot$topdir/SOURCES");
    if ($ret != MEZZANINE_SUCCESS) {
        return ($ret, "Creation of source files failed", undef);
    }
    return &build_topdir();
}

# Source RPM's can be rebuilt with this function.  build_package() usually handles the
# extraction of the module name, but this function can be called directly as long as
# that isn't an issue or has already been taken care of by the calling function.
sub
build_srpm
{
    my ($pkg, $topdir, $instroot, $err, $sdata);
    my (@tmp, @specs);
    my %preserve_pkg_vars;

    dprint &print_args(@_);

    &prepare_build_tree();
    $topdir = &pkgvar_topdir();
    $pkg = &pkgvar_filename();
    $instroot = &pkgvar_instroot();
    %preserve_pkg_vars = &pkgvar_get_all();

    @tmp = &rpm_show_contents();
    if (($err = shift @tmp) != MEZZANINE_SUCCESS) {
        return (MEZZANINE_NO_SOURCES, "Unable to examine the contents of ${\(&pkgvar_filename())} ($err)", undef);
    }

    foreach my $f (grep(/spec(\.in)?$/, @tmp)) {
        my @fields;

        chomp($f);
        @fields = split(' ', $f);
        push @specs, $fields[$#fields];
    }
    if (scalar(@specs) != 1) {
        wprint "Found ${\(scalar(@specs))} spec files in $pkg?!\n";
    }

    if ($instroot) {
        &pkgvar_instroot("");
        @tmp = &rpm_install();
        &pkgvar_instroot($instroot);
    }
    @tmp = &rpm_install();
    if (($err = shift @tmp) != MEZZANINE_SUCCESS) {
        return (MEZZANINE_PACKAGE_FAILED, "Unable to install $pkg ($err)", undef);
    }
    @specs = grep(-f "$instroot$topdir/SPECS/$_" && -s _, @specs);
    if (scalar(@specs) != 1) {
        return (MEZZANINE_NO_SOURCES, "Found ${\(scalar(@specs))} spec files in $pkg?!", undef);
    }
    &pkgvar_reset(%preserve_pkg_vars);

    &pkgvar_instructions("$instroot$topdir/SPECS/$specs[0]");
    &parse_spec_file();
    if ($specdata) {
        if (!&pkgvar_get("allow_epoch") && exists($specdata->{"HEADER"}{"epoch"})) {
            my $str;

            $str = sprintf("Epoch %s not allowed", $specdata->{"HEADER"}{"epoch"});
            return (MEZZANINE_SPEC_ERRORS, $str, undef);
        }

        if ($specdata->{"BUILD_DEPS"} && scalar(@{$specdata->{"BUILD_DEPS"}})) {
            my $ret;

            $ret = &install_deps(join(' ', @{$specdata->{"BUILD_DEPS"}}));
            if ($ret) {
                wprint "Build dependency installation failed:  $ret\n";
            }
        } else {
            dprint "No build deps?\n";
        }
    }

    &pkgvar_instructions("$topdir/SPECS/$specs[0]");
    return &build_topdir();
}

# Plain old tarballs can be rebuilt into packages using this function, as long as they
# contain the necessary file(s) inside them (spec file and/or debian/ directory).
sub
build_tarball
{
    my ($target_format, $cmd);
    my $pkg = &pkgvar_name();

    dprint &print_args(@_);

    $target_format = &pkgvar_target();
    &prepare_build_tree();
    if ($target_format eq "rpms") {
        return &build_rpms_from_tarball($pkg);
    } elsif ($target_format eq "debs") {
        return &build_debs_from_tarball($pkg);
    }
}

# This is the main routine for building stuff.  Its job is to figure out what type of
# stuff it is that you're trying to build, and then call the right function to build it.
sub
build_package
{
    my ($pwd, $pkg, $pkgtype);
    my @ret = ();

    dprint &print_args(@_);

    $pwd = &getcwd();
    $pkg = &pkgvar_filename();
    $pkgtype = &pkgvar_type() || "";

    if (($pkgtype eq "FST") || ($pkgtype eq "CFST") || ($pkgtype eq "SPM")
        || ($pkgtype eq "PDR") || (-d $pkg)) {
        # It's a directory.  That means it's some type of module.
        if (!chdir($pkg)) {
            @ret = (MEZZANINE_SYSTEM_ERROR, "Unable to chdir into \"$pkg\" -- $!", undef);
        }
        if (($pkgtype eq "SPM") || (-d "F")) {
            # Okay, there's an F/ directory.  I bet it's an SPM.
            @ret = &build_spm();
        } elsif (($pkgtype eq "CFST") || (-f "Makefile.mezz" && -s _)) {
            # There's a custom Makefile.  It's a Custom Full Source Tree (FST).
            @ret = &build_cfst();
        } else {
            my $spec = &find_spec_file(&pkgvar_name(), ".");

            if ($spec) {
                # There's a spec file.  Make sure we have all sources.
                &pkgvar_instructions(&basename($spec));
                &parse_spec_file();

                if ($specdata && $specdata->{"SOURCES"} && scalar(@{$specdata->{"SOURCES"}})) {
                    my @tmp;

                    @tmp = map { $specdata->{"SOURCE"}{$_} } @{$specdata->{"SOURCES"}};
                    if ($specdata->{"PATCHES"}) {
                        push @tmp, map { $specdata->{"PATCH"}{$_} } @{$specdata->{"PATCHES"}};
                    }
                    dprint "Searching . for:  ", join(", ", @tmp), "\n";
                    @tmp = grep(! -f &basename($_), @tmp);
                    dprint "Missing:  ", join(", ", @tmp), "\n";
                    if (!scalar(@tmp)) {
                        # All sources and patches are here.  It's a PDR.
                        @ret = &build_pdr();
                    } else {
                        dprint "Not PDR:  Some sources missing.\n";
                    }
                } else {
                    dprint "Not PDR:  No sources found in spec.\n";
                }
            } else {
                dprint "Not PDR:  No spec file found.\n";
            }

            if (!scalar(@ret)) {
                # If it's not any of the above, it better be a standard Full Source Tree (FST),
                # and it better conform to the proper assumptions or provide other instructions.
                @ret = &build_fst();
            }
        }
    } elsif (-f _ && -s _) {
        # It's a file.  Must be a package file of some type.
        # Split the actual package name from any path information.
        if ($pkg =~ /\//) {
            my $module;

            $module = &dirname($pkg);
            $pkg = &basename($pkg);
            if (!chdir($module)) {
                @ret = (MEZZANINE_SYSTEM_ERROR, "Unable to chdir into \"$module\" -- $!", undef);
            }
            &pkgvar_filename($pkg);
        }
        if ($pkg =~ /src\.rpm$/) {
            @ret = &build_srpm();
        } elsif ($pkg =~ /\.(tar\.|t)(gz|Z|bz2)$/) {
            @ret = &build_tarball();
        } elsif ($pkg =~ /\.rpm$/) {
            @ret = (MEZZANINE_NO_SOURCES, "Alright...  Who's the wiseguy that told me to recompile \"$pkg,\" a binary RPM? :-P", undef);
        } else {
            @ret = (MEZZANINE_NO_SOURCES, "I'm sorry, but I don't know how to build \"$pkg.\"", undef);
        }
    } else {
        # Okay, it's neither a file nor a directory.  What the hell is it?
        @ret = (MEZZANINE_NO_SOURCES, "I'm sorry, but I can't figure out what to do with \"$pkg.\"", undef);
    }
    chdir($pwd);
    return @ret;
}

### Private functions


1;
