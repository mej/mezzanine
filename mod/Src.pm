# Avalon Srctool Perl Module
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
# $Id: Src.pm,v 1.6 2001/07/18 22:47:49 mej Exp $
#

package Avalon::Src;

BEGIN {
    use Exporter   ();
    use File::Copy;
    use File::Find;
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.0;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('$WORK_DIR', '$TMP_DIR', 
                    '&find_files', '&find_subdirs', '&generate_symlink_file',
                    '&install_spm_files', '&create_temp_space', '&clean_temp_space',
                    '&run_cmd', '&run_av_cmd');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

# Constants
$WORK_DIR = "work";
$TMP_DIR = "/var/tmp/srctool.$$";

### Initialize private global variables

### Function prototypes
sub find_files($);
sub find_subdirs($);
sub generate_symlink_file($);
sub install_spm_files($);
sub create_temp_space($$);
sub clean_temp_space();
sub run_cmd($$$);
sub run_av_cmd($$$);

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
    @files = &grepdir(sub {-f "$dir/$_" && $_ !~ /^\./}, $dir);
    if (scalar(@files)) {
        foreach my $f (0..$#files) {
            $files[$f] = "$dir/$files[$f]";
        }
    }
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

# Generate the .avalon.symlinks file automatically from a tree
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
        if (!open(SYMLINKS, ">$path/.avalon.symlinks")) {
            eprint "Unable to open $path/.avalon.symlinks for writing -- $!\n";
            return AVALON_SYSTEM_ERROR;
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
    return AVALON_SUCCESS;
}

# Copy source files into place
sub
install_spm_files($)
{
    my $dir = $_[0];
    my ($spec, $tmp);
    my (@srcs, @patches, @tmp);

    # Find all the sources and patches and the spec file.
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

# Create temporary working space in /var/tmp
sub
create_temp_space($$)
{
    my ($pkg, $type) = @_;
    my ($dir, $d);
    my @dirlist;

    $dir = "$TMP_DIR/$pkg";
    &nuke_tree($dir);
    &mkdirhier($dir) || return "";
    if ($type eq "SPM") {
	@dirlist = ("S", "P", "F");
    } elsif ($type eq "build") {
	@dirlist = ("BUILD", "SOURCES", "SRPMS", "RPMS", "SPECS");
    }
    foreach $d (@dirlist) {
	if (!&mkdirhier("$dir/$d")) {
	    eprint "Creation of $dir/$d failed -- $!\n";
	    return "";
	}
    }
    return $dir;
}

# Clean up temp space
sub
clean_temp_space()
{
    return &nuke_tree($TMP_DIR);
}

# Generic wrapper to grab command output
sub
run_cmd($$$)
{
    my ($prog, $params, $show_output) = @_;
    my ($err, $msg, $line, $cmd) = undef;
    my @output;
    local *CMD;

    $cmd = "$prog $params";

    dprint "About to run $cmd\n";
    if (!open(CMD, "$cmd 2>&1 |")) {
        return (-1, "Execution of \"$cmd\" failed -- $!");
    }
    while (<CMD>) {
        chomp($line = $_);
        push @output, $line;
        if ($show_output) {
            print "$show_output$line\n";
        } else {
            dprint "From $prog -> $line\n";
        }
    }
    close(CMD);
    $err = $? >> 8;
    dprint "\"$cmd\" returned $err\n";
    return ($err, @output);
}

# Wrapper for Avalon commands specifically
sub
run_av_cmd($$$)
{
    my ($prog, $params, $show_output) = @_;
    my ($err, $msg, $line, $cmd) = undef;
    my (@output, @tmp);

    $params = "--debug $params" if ($debug);
    @output = &run_cmd($prog, $params, $show_output);
    $err = shift @output;
    if ($err) {
        my @tmp;

        @tmp = grep(/^\w+:\s*error:\s*(\S.*)$/i, @output);
        if (scalar(@tmp)) {
            $msg = $tmp[$#tmp];
        }
    }
    return ($err, ($show_output ? $msg : @output));
}

### Private functions

1;
