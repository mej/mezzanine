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
# $Id: Src.pm,v 1.19 2004/05/10 14:47:00 mej Exp $
#

package Mezzanine::Src;

BEGIN {
    use strict;
    use Exporter   ();
    use File::Copy;
    use File::Find;
    use Cwd ('&getcwd');
    use Mezzanine::Util;
    use Mezzanine::PkgVars;
    use Mezzanine::Pkg;
    use Mezzanine::RPM;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('$WORK_DIR', '&find_files', '&find_subdirs',
               '&generate_symlink_file', '&install_spm_files',
               '&create_temp_space', '&clean_temp_space',
               '&convert_srpm_to_spm', '&convert_srpm_to_pdr');

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
sub generate_symlink_file($);
sub install_spm_files($);
sub convert_srpm_to_spm($$);
sub convert_srpm_to_pdr($$);

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

# Generate the .mezz.symlinks file automatically from a tree
sub
generate_symlink_file($)
{
    my $path = $_[0];
    my $cnt;
    my %links;
    local *SYMLINKS;

    $path = '.' if (! $path);
    &find(sub {-l && ($links{$File::Find::name} = readlink($_));}, $path);
    $cnt = scalar(keys %links);
    if ($cnt) {
        dprint "Found $cnt symlinks.\n";
        if (!open(SYMLINKS, ">$path/.mezz.symlinks")) {
            eprint "Unable to open $path/.mezz.symlinks for writing -- $!\n";
            return MEZZANINE_SYSTEM_ERROR;
        }
        foreach my $link (sort keys %links) {
            my $newlink;

            ($newlink = $link) =~ s/^\.\///;
            print SYMLINKS "$newlink -> $links{$link}\n";
            unlink($newlink);
        }
        close(SYMLINKS);
    } else {
        dprint "No symlinks found.\n";
    }
    return MEZZANINE_SUCCESS;
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
    @tmp = &find_files("F");
    if (scalar(@tmp) != 1) {
	my $n = scalar(@tmp);
	&fatal_error("$n spec files?!\n");
    }
    $spec = $tmp[0];
    undef @tmp;
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
    my ($err, $msg, $rpmcmd, $spec, $specdata);
    my (@srcs, @patches, @tmp);

    # Install the SRPM into the temporary directory
    &pkgvar_filename($pkgfile);
    $destdir = &getcwd() if ($destdir =~ /^\.\/?$/);
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
        return MEZZANINE_COMMAND_FAILED;
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
    &limit_files(&basename($spec), "$destdir/F");
    &limit_files(@srcs, "$destdir/S");
    &limit_files(@patches, "$destdir/P");
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

### Private functions

1;
