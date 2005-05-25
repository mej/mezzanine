# Mezzanine Srctool Perl Module
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
# $Id: Src.pm,v 1.26 2005/05/25 16:14:56 mej Exp $
#

package Mezzanine::Src;
use Exporter;
use POSIX;
use File::Copy;
use Mezzanine::Util;
use Mezzanine::PkgVars;
use Mezzanine::Pkg;
use Mezzanine::RPM;

BEGIN {
    use strict;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('$WORK_DIR', '&find_files', '&find_subdirs',
               '&install_spm_files', '&create_temp_space',
               '&clean_temp_space', '&convert_srpm_to_spm',
               '&convert_srpm_to_pdr', '&find_keepers');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

# Constants
$WORK_DIR = "work";

### Initialize private global variables

### Function prototypes
sub find_files($);
sub find_subdirs($);
sub install_spm_files($);
sub convert_srpm_to_spm($$);
sub convert_srpm_to_pdr($$);
sub find_keepers(@);

# Private functions

### Module cleanup
END {
}

### Function definitions

# Return the files in a particular directory
sub
find_files($)
{
    my $dir = $_[0];
    my @files;

    return @files if (! -d $dir);
    @files = &grepdir(sub {-f $_ && $_ !~ /\.$/}, $dir);
    return @files;
}

# Return the subdirectories in a particular directory
sub
find_subdirs($)
{
    my $dir = $_[0];
    my @subdirs;

    return @files if (! -d $dir);
    @subdirs = &grepdir(sub {-d "$dir/$_" && $_ !~ /^\./}, $dir);
    if (scalar(@subdirs)) {
        foreach my $f (0..$#subdirs) {
            $subdirs[$f] = "$dir/$subdirs[$f]";
        }
    }
    return @subdirs;
}

# Copy source files into place
sub
install_spm_files($)
{
    my $dir = $_[0];
    my ($spec, $tmp);
    my (@srcs, @patches, @tmp);

    # Find all the sources and patches and the spec file.
    dprint "Installing SPM files to $dir.\n";
    @srcs = &find_files("S");
    @patches = &find_files("P");
    $spec = &find_spec_file(&pkgvar_name(), "F");
    if (! $spec) {
        eprint "No spec file found.\n";
        return 0;
    }
    push @tmp, @srcs if (scalar(@srcs));
    push @tmp, @patches if (scalar(@patches));

    # Copy all the files into their proper places for RPM's use
    foreach my $f (@tmp) {
        my $fname;

        ($fname = $f) =~ s/^.\///;
	if (!copy($f, "$dir/SOURCES/$fname")) {
	    eprint "Unable to copy $f into $dir/SOURCES -- $!\n";
	    return 0;
	}
    }
    ($tmp = $spec) =~ s/^.\///;
    if (!copy($spec, "$dir/SPECS/$tmp")) {
	eprint "Unable to copy $spec into $dir/SPECS -- $!\n";
	return 0;
    }
    return $spec;
}

sub
convert_srpm_to_spm($)
{
    my ($pkgfile, $destdir) = @_;
    my ($err, $msg, $rpmcmd, $spec, $specdata, $tmp);
    my (@srcs, @patches, @tmp, @keepers);

    &pkgvar_filename($pkgfile);
    $destdir = &getcwd() if ($destdir =~ /^\.\/?$/);
    $tmp = &pkgvar_get("keep_files");
    if ($tmp && (ref($tmp) eq "ARRAY")) {
        @keepers = @{$tmp};
    }
    if (scalar(@keepers)) {
        foreach my $dir ("F", "P", "S") {
            foreach my $filename (@keepers) {
                if ((-d $dir) && (-f "$dir/$filename")) {
                    if (&move_files("$dir/$filename", "$dir/$filename.mezz_keep") != 1) {
                        wprint "Unable to backup $filename -- $!\n";
                    }
                }
            }
        }
    }

    # Install the SRPM into the temporary directory
    &pkgvar_parameters("--define '_sourcedir $destdir/S' --define '_specdir $destdir/F'");
    ($err, $msg) = &package_install();
    &pkgvar_parameters("");
    if ($err != MEZZANINE_SUCCESS) {
        eprint "Unable to install $pkgfile\n";
        return MEZZANINE_COMMAND_FAILED;
    }

    # The spec file should be the only file in $destdir/F
    @tmp = grep(/\.spec(\.in)?\s*$/, &package_show_contents());
    dprint "Spec file(s):  ", join(' ', @tmp), "\n";
    if (scalar(@tmp) != 1) {
        my $n = scalar(@tmp);
        &fatal_error("$n spec files in $pkgfile?!\n");
    }
    $spec = "$destdir/F/" . substr($tmp[0], 59);
    chomp($spec);

    # Get a list of all source and patch files
    &pkgvar_instructions($spec);
    $specdata = &parse_spec_file();
    if (!defined($specdata->{SPECFILE})) {
        eprint "Unable to parse spec file.\n";
        return MEZZANINE_SPEC_ERRORS;
    } elsif (exists($specdata->{"HEADER"}{"epoch"})) {
        wprintf("Epoch of %s present!\n", $specdata->{"HEADER"}{"epoch"});
        if (! &pkgvar_get("allow_epoch")) {
            return MEZZANINE_SPEC_ERRORS;
        }
    }

    @srcs = values %{$specdata->{SOURCE}};
    @patches = values %{$specdata->{PATCH}};
    dprint "Specfile $spec, sources ", join(' ', @srcs), ", patches ", join(' ', @patches), "\n";

    # Move the patches to $destdir/P/
    if (scalar(@patches)) {
        chdir("$destdir/S");
        mkdir("$destdir/P", 0777);
        dprint "Moving patches to $destdir/P/\n";
        if (&move_files(@patches, "$destdir/P/") < scalar(@patches)) {
            eprint "One or more patches could not be moved into place.\n";
            return MEZZANINE_FILE_OP_FAILED;
        }
    }

    # Restore kept files from backups.
    if (scalar(@keepers)) {
        my @new_keepers;

        #dprintf("Restoring kept files:  %s\n", join(", ", @keepers));
        foreach my $dir ("$destdir/F", "$destdir/P", "$destdir/S") {
            foreach my $filename (@keepers) {
                if ((-d $dir) && (-f "$dir/$filename.mezz_keep")) {
                    if (-f "$dir/$filename") {
                        if (&checksum_file("$dir/$filename") == &checksum_file("$dir/$filename.mezz_keep")) {
                            dprint "$filename and $filename.mezz_keep are identical.  Removing backup.\n";
                            &nuke_tree("$dir/$filename.mezz_keep");
                        } elsif (&move_files("$dir/$filename", "$dir/$filename.mezz_new") != 1) {
                            wprint "Unable to rename $filename -- $!\n";
                        } else {
                            dprint "Saved new $filename as $filename.mezz_new.\n";
                            push @new_keepers, "$filename.mezz_new";
                        }
                    }
                    if (&move_files("$dir/$filename.mezz_keep", "$dir/$filename") != 1) {
                        wprint "Unable to restore $filename -- $!\n";
                        push @new_keepers, "$filename.mezz_keep";
                    } else {
                        dprint "Moved $dir/$filename.mezz_keep to $dir/$filename\n";
                        push @new_keepers, $filename;
                    }
                }
            }
        }
        @keepers = @new_keepers;
        #dprintf("Now keeping:  %s\n", join(", ", @new_keepers));
    }

    &limit_files(&basename($spec), @keepers, "$destdir/F");
    &limit_files(@srcs, @keepers, "$destdir/S");
    &limit_files(@patches, @keepers, "$destdir/P");
    return MEZZANINE_SUCCESS;
}

sub
convert_srpm_to_pdr($)
{
    my ($pkgfile, $destdir) = @_;
    my ($err, $msg, $rpmcmd, $spec, $specdata);
    my (@srcs, @patches, @tmp);

    # Install the SRPM into the temporary directory
    &pkgvar_filename($pkgfile);
    $destdir = &getcwd() if ($destdir =~ /^\.\/?$/);
    &pkgvar_parameters("--define '_sourcedir $destdir' --define '_specdir $destdir'");
    ($err, $msg) = &package_install();
    &pkgvar_parameters("");
    if ($err != MEZZANINE_SUCCESS) {
        eprint "Unable to install $pkgfile\n";
        return MEZZANINE_COMMAND_FAILED;
    }
    return MEZZANINE_SUCCESS;
}

sub
find_keepers(@)
{
    my @keep_files = @_;
    my ($pkgtype, $specdata);
    my @keepers;

    dprint &print_args(@_);

    # Find spec file.
    if (! &pkgvar_instructions()) {
        my $spec;

        $pkgtype = &identify_package_type();
        if ($pkgtype eq "SPM") {
            $spec = &find_spec_file(&pkgvar_name(), "F");
            &pkgvar_instructions($spec);
        } elsif ($pkgtype eq "PDR") {
            $spec = &find_spec_file(&pkgvar_name(), ".");
            &pkgvar_instructions($spec);
        } else {
            # FIXME:  What to do?
            return @keepers;
        }
    }

    $specdata = &parse_spec_file();
    if (! $specdata) {
        # Couldn't parse the spec. :(
        wprintf("Unable to parse spec file %s.  Not keeping any files.\n", &pkgvar_instructions());
        return @keepers;
    }

    foreach my $filespec (@keep_files) {
        dprint "Handling filespec:  $filespec\n";

        if (substr($filespec, 0, 1) eq 'F') {
            push @keepers, &basename(&pkgvar_instructions());
        } elsif (substr($filespec, 0, 1) eq 'S') {
            if (ref($specdata->{"SOURCES"}) eq "ARRAY") {
                if ($filespec eq 'S') {
                    push @keepers, map { $specdata->{"SOURCE"}{$_} } @{$specdata->{"SOURCES"}};
                } elsif ($filespec =~ /^S(\d+)\+$/) {
                    my $num = $1;

                    push @keepers, map { $specdata->{"SOURCE"}{$_} } grep { $_ >= $num } @{$specdata->{"SOURCES"}};
                } elsif ($filespec =~ /^S(\d+)-(\d+)$/) {
                    my ($low, $high) = ($1, $2);

                    push @keepers, map { $specdata->{"SOURCE"}{$_} }
                                       grep { ($_ >= $low) && ($_ <= $high) } @{$specdata->{"SOURCES"}};
                } elsif ($filespec =~ /^S(\d+)$/) {
                    my $num = $1;

                    if ($specdata->{"SOURCE"}{$num}) {
                        push @keepers, $specdata->{"SOURCE"}{$num};
                    }
                } else {
                    wprint "Unable to parse for keeping:  $filespec\n";
                }
            }
        } elsif (substr($filespec, 0, 1) eq 'P') {
            if (ref($specdata->{"PATCHES"}) eq "ARRAY") {
                if ($filespec eq 'P') {
                    push @keepers, map { $specdata->{"PATCH"}{$_} } @{$specdata->{"PATCHES"}};
                } elsif ($filespec =~ /^P(\d+)\+$/) {
                    my $num = $1;

                    push @keepers, map { $specdata->{"PATCH"}{$_} } grep { $_ >= $num } @{$specdata->{"PATCHES"}};
                } elsif ($filespec =~ /^P(\d+)-(\d+)$/) {
                    my ($low, $high) = ($1, $2);

                    push @keepers, map { $specdata->{"PATCH"}{$_} }
                                       grep { ($_ >= $low) && ($_ <= $high) } @{$specdata->{"PATCHES"}};
                } elsif ($filespec =~ /^P(\d+)$/) {
                    my $num = $1;

                    if ($specdata->{"PATCH"}{$num}) {
                        push @keepers, $specdata->{"PATCH"}{$num};
                    }
                } else {
                    wprint "Unable to parse for keeping:  $filespec\n";
                }
            }
        } else {
            wprint "Unable to parse for keeping:  $filespec\n";
        }
    }
    dprintf("Keeping:  \"%s\"\n", join("\", \"", @keepers));
    return @keepers;
}

### Private functions

1;
