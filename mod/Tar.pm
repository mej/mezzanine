# Mezzanine Tar Perl Module
# 
# Copyright (C) 2001-2007, Michael Jennings
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
# $Id: Tar.pm,v 1.6 2011/06/25 19:41:34 mej Exp $
#

package Mezzanine::Tar;

BEGIN {
    use strict;
    use Exporter   ();
    use Mezzanine::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ();
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION', '&tar_show_contents', '&tar_list_files');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

# Constants

### Initialize private global variables

### Function prototypes

# Private functions

### Module cleanup
END {
}

### Function definitions

sub
tar_install
{
    my $pkg_file = $_[0];
    my ($tar, $dir, $cmd, $err, $msg);
    my (@failed_deps);
    local *TAR;

    $dir = ($rootdir ? $rootdir : "/");
    $tar = ($pkg_prog ? $pkg_prog : "tar -C $dir");
    if ($pkg_file =~ /\.(t?gz|Z)$/) {
        $tar .= " --use-compress-program=gzip";
    } elsif ($pkg_file =~ /\.bz2$/) {
        $tar .= " --use-compress-program=bzip2";
    }
    $cmd = "$tar -xvf $pkg_file";
    dprint "About to run \"$cmd\"\n";
    if (!open(TAR, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    $err = MEZZANINE_SUCCESS;
    while (<TAR>) {
        chomp($line = $_);
        if ($line =~ /^tar: /) {
            eprint "$line\n";
        } else {
            dprint "   $line\n";
        }
    }
    close(TAR);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0 && $err == MEZZANINE_SUCCESS) {
        return MEZZANINE_UNSPECIFIED_ERROR;
    }
    if ($err == MEZZANINE_SUCCESS) {
        print "$pkg_file successfully installed.\n";
    } else {
        eprint "$pkg_file installation failed.\n";
    }
    return $err;
}

sub
tar_show_contents
{
    my $pkg_file = $_[0];
    my ($tar, $cmd);
    my @results;
    local *TAR;

    $tar = ($pkg_prog ? $pkg_prog : "tar");
    if ($pkg_file =~ /\.(t?gz|Z)$/) {
        $tar .= " --use-compress-program=gzip";
    } elsif ($pkg_file =~ /\.bz2$/) {
        $tar .= " --use-compress-program=bzip2";
    }
    if ($pkg_file =~ /\.zip$/) {
        $cmd = "unzip -l $pkg_file | awk '{$1=\"\";$2=\"\";$3=\"\";print $0}' "
            . "| sed 's/^[[:space:]]*//' | egrep -v '^(Name|----)$'";
    } else {
        $cmd = "$tar -tvf $pkg_file";
    }
    dprint "About to run \"$cmd\"\n";
    if (!open(TAR, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    @results = <TAR>;
    close(TAR);
    dprint "\"$cmd\" returned $?\n";
    return ($? >> 8, @results);
}

sub
tar_list_files
{
    my $pkg_file = $_[0];
    my ($tar, $cmd);
    my @results;
    local *TAR;

    $tar = ($pkg_prog ? $pkg_prog : "tar");
    if ($pkg_file =~ /\.(t?gz|Z)$/) {
        $tar .= " --use-compress-program=gzip";
    } elsif ($pkg_file =~ /\.bz2$/) {
        $tar .= " --use-compress-program=bzip2";
    }
    if ($pkg_file =~ /\.zip$/) {
        $cmd = "unzip -l $pkg_file | awk '{$1=\"\";$2=\"\";$3=\"\";print $0}' "
            . "| sed 's/^[[:space:]]*//' | egrep -v '^(Name|----)$'";
    } else {
        $cmd = "$tar -tf $pkg_file";
    }
    dprint "About to run \"$cmd\"\n";
    if (!open(TAR, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    @results = <TAR>;
    close(TAR);
    dprint "\"$cmd\" returned $?\n";
    return ($? >> 8, @results);
}

sub
tar_query
{
    eprint "Tar packages cannot be queried.\n";
    return MEZZANINE_COMMAND_INVALID;
}


### Private functions

1;
