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
# $Id: Src.pm,v 1.2 2001/04/02 07:53:39 mej Exp $
#

package Avalon::Srctool;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.0;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('$WORK_DIR', '$TMP_DIR', '&install_spm_files');
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
sub install_spm_files($);

# Private functions

### Module cleanup
END {
}

### Function definitions

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

    # Copy all the files into their proper places for RPM's use
    foreach my $f (@srcs, @patches) {
        my $fname;

        ($fname = $f) =~ s/^.\///;
	if (!link($f, "$dir/SOURCES/$fname")) {
	    eprint "Unable to copy $f into $dir/SOURCES -- $!\n";
	    return 0;
	}
    }
    ($tmp = $spec) =~ s/^.\///;
    if (!link($spec, "$dir/SPECS/$tmp")) {
	eprint "Unable to copy $spec into $dir/SPECS -- $!\n";
	return 0;
    }
    return $spec;
}

### Private functions

1;
