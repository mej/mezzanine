# Mezzanine Pkg Perl Module
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
# $Id: Pkg.pm,v 1.26 2011/06/25 19:41:34 mej Exp $
#

package Mezzanine::Pkg;
use strict;
use Exporter;
use Mezzanine::Util;
use Mezzanine::PkgVars;
use Mezzanine::RPM;
use Mezzanine::Deb;
use Mezzanine::Tar;
use Mezzanine::SCM;

use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

BEGIN {
    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&fetch_package', '&package_install',
                    '&package_show_contents', '&package_list_files',
                    '&package_query', '&package_compare_versions');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

### Initialize private global variables

### Function prototypes
sub fetch_package($);
sub package_install();
sub package_show_contents();
sub package_list_files();
sub package_query($);
sub package_compare_versions($$);

# Private functions

### Module cleanup
END {
}

### Function definitions

# Use revtool to download a package from the master repository
sub
fetch_package($)
{
    my $scm = shift;
    my $pkg_file = &pkgvar_filename();
    my ($err, $msg, $line) = undef;
    my $missing = 0;

    if (! $pkg_file) {
        return (MEZZANINE_MISSING_PKGS, "Nothing to fetch?");
    }
    foreach my $f (split(' ', $pkg_file)) {
        if (!(-d $f) && !(-f $f && -s _)) {
            $missing = 1;
        }
    }
    if (! $missing) {
        dprint "No need to retrieve:  $pkg_file\n";
        return (MEZZANINE_DUPLICATE, undef);
    }

    if ($scm->login()) {
        $err = $scm->get($pkg_file);
        return ($err, "");
    } else {
        return (MEZZANINE_BAD_LOGIN, "Login failure");
    }
}

sub
package_install
{
    my ($pkg_file, $pkg_type);

    $pkg_file = &pkgvar_filename();
    $pkg_type = &pkgvar_type();

    if (! $pkg_file) {
        return (MEZZANINE_SYNTAX_ERROR, "You cannot install without specifying a package.\n");
    }
    if ($pkg_type eq "rpm") {
        return &rpm_install();
    } elsif ($pkg_type eq "deb") {
        return &deb_install();
    } elsif ($pkg_type eq "tar") {
        return &tar_install();
    }
    return (MEZZANINE_INVALID_PACKAGE, "Unable to identify package $pkg_file.\n");
}

sub
package_show_contents
{
    my ($pkg_file, $pkg_type);

    $pkg_file = &pkgvar_filename();
    $pkg_type = &pkgvar_type();

    if (! $pkg_file) {
        return (MEZZANINE_SYNTAX_ERROR, "You cannot display contents without specifying a package.\n");
    }
    if ($pkg_type eq "rpm") {
        return &rpm_show_contents($pkg_file);
    } elsif ($pkg_type eq "deb") {
        return &deb_show_contents($pkg_file);
    } elsif ($pkg_type eq "tar") {
        return &tar_show_contents($pkg_file);
    }
    return (MEZZANINE_INVALID_PACKAGE, "Unable to identify package $pkg_file.\n");
}

sub
package_list_files
{
    my ($pkg_file, $pkg_type);

    $pkg_file = &pkgvar_filename();
    $pkg_type = &pkgvar_type();

    if (! $pkg_file) {
        return (MEZZANINE_SYNTAX_ERROR, "You cannot display contents without specifying a package.\n");
    }
    if ($pkg_type eq "rpm") {
        return &rpm_list_files($pkg_file);
    } elsif ($pkg_type eq "deb") {
        return &deb_list_files($pkg_file);
    } elsif ($pkg_type eq "tar") {
        return &tar_list_files($pkg_file);
    }
    return (MEZZANINE_INVALID_PACKAGE, "Unable to identify package $pkg_file.\n");
}

sub
package_query
{
    my $query_type = $_[0];
    my ($pkg_file, $pkg_type);

    $pkg_file = &pkgvar_filename();
    $pkg_type = &pkgvar_type();

    if (! $pkg_file) {
        return (MEZZANINE_SYNTAX_ERROR, "You cannot query without specifying a package.\n");
    }
    if ($pkg_type eq "rpm") {
        return &rpm_query($query_type);
    } elsif ($pkg_type eq "deb") {
        return &deb_query($query_type);
    } elsif ($pkg_type eq "tar") {
        return &tar_query($query_type);
    }
    return (MEZZANINE_INVALID_PACKAGE, "Unable to identify package $pkg_file.\n");
}

sub
package_compare_versions
{
    my ($v1, $v2) = @_;
    my ($pkg_file, $pkg_type);

    $pkg_file = &pkgvar_filename();
    $pkg_type = &pkgvar_type();

    if (! $pkg_file) {
        return (MEZZANINE_SYNTAX_ERROR, "You cannot compare versions without specifying a package.\n");
    }
    if ($pkg_type eq "rpm") {
        return &rpm_compare_versions($v1, $v2);
    } elsif ($pkg_type eq "deb") {
        return &deb_compare_versions($v1, $v2);
    } elsif ($pkg_type eq "tar") {
        return &tar_compare_versions($v1, $v2);
    }
    return (MEZZANINE_INVALID_PACKAGE, "Unable to identify package $pkg_file.\n");
}

### Private functions

1;
