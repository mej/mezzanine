# Avalon Pkg Perl Module
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
# $Id: Pkg.pm,v 1.15 2001/08/15 00:52:02 mej Exp $
#

package Avalon::Pkg;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use Avalon::RevCtl;
    use Avalon::RPM;
    use Avalon::Deb;
    use Avalon::Tar;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&pkgvar_name', '&pkgvar_filename', '&pkgvar_target', '&pkgvar_instructions', '&pkgvar_topdir', '&pkgvar_instroot', '&pkgvar_buildroot', '&pkgvar_architecture', '&pkgvar_parameters', '&pkgvar_command', '&pkgvar_rcfile', '&pkgvar_tar', '&pkgvar_zip', '&pkgvar_cleanup', '&get_package_path', '&fetch_package', '&identify_package', '&package_install', '&package_show_contents', '&package_query');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

### Initialize private global variables
$pkg_name = "";
$pkg_file = "";
$pkg_target = "rpms";
$pkg_srcs = "";
$pkg_inst = "";
$pkg_topdir = "";
$pkg_instroot = "";
$pkg_buildroot = "";
$pkg_arch = "i386";
$pkg_params = "";
$pkg_cmd = "";
$pkg_rcfile = "";
$pkg_tar = "tar";
$pkg_zip = "gzip";
$pkg_cleanup = "none";
%pkg_type = ();

### Function prototypes
sub pkgvar_name($);
sub pkgvar_filename($);
sub pkgvar_target($);
sub pkgvar_srcs(@);
sub pkgvar_instructions($);
sub pkgvar_topdir($);
sub pkgvar_instroot($);
sub pkgvar_buildroot($);
sub pkgvar_architecture($);
sub pkgvar_parameters($);
sub pkgvar_command($);
sub pkgvar_rcfile($);
sub pkgvar_tar($);
sub pkgvar_zip($);
sub pkgvar_cleanup($);
sub get_package_path($$);
sub fetch_package($$$$$);
sub identify_package($);
sub package_install($);
sub package_show_contents($);
sub package_query($$);

# Private functions
sub add_define($$);
sub replace_defines($);

### Module cleanup
END {
}

### Function definitions

sub
pkgvar_name
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_name = ($param ?  $param : "");
    }
    return $pkg_name;
}

sub
pkgvar_filename
{
    my $param = $_[0];

    if (defined($param)) {
        if (defined($_[1])) {
            $param = &get_package_path(@_);
        }
        $pkg_file = ($param ?  $param : "");
    }
    &identify_package() if (!$pkg_type{$pkg_file});
    return $pkg_file;
}

sub
pkgvar_target
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_target = ($param ? $param : "rpms");
    }
    return $pkg_target;
}

sub
pkgvar_srcs
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_srcs = ($param ? $param : "");
    }
    return $pkg_srcs;
}

sub
pkgvar_instructions
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_inst = ($param ?  $param : "");
    }
    return $pkg_inst;
}

sub
pkgvar_topdir
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_topdir = ($param ? $param : "");
    }
    return $pkg_topdir;
}

sub
pkgvar_instroot
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_instroot = ($param ? $param : "");
    }
    return $pkg_instroot;
}

sub
pkgvar_buildroot
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_buildroot = ($param ? $param : "");
    }
    return $pkg_buildroot;
}

sub
pkgvar_architecture
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_arch = ($param ? $param : "i386");
    }
    return $pkg_arch;
}

sub
pkgvar_parameters
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_params = ($param ? $param : "");
    }
    return $pkg_params;
}

sub
pkgvar_command
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_cmd = ($param ? $param : "");
    }
    return $pkg_cmd;
}

sub
pkgvar_rcfile
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_rcfile = ($param ? $param : "");
    }
    return $pkg_rcfile;
}

sub
pkgvar_tar
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_tar = ($param ? $param : "tar");
    }
    return $pkg_tar;
}

sub
pkgvar_zip
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_zip = ($param ? $param : "gzip");
    }
    return $pkg_zip;
}

sub
pkgvar_cleanup
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_cleanup = ($param ? $param : "none");
    }
    return $pkg_cleanup;
}

# Convert a module and a filename to a full path
sub
get_package_path
{
    my ($module, $filename) = @_;

    if ($module && $filename) {
        if ($module ne $filename) {
            return "$module/$filename";
        } else {
            return $filename;
        }
    } elsif ($module) {
        return $module;
    } else {
        return $filename;
    }
}

# Use revtool to download a package from the master repository
sub
fetch_package
{
    my ($err, $msg, $line) = undef;
    my $missing = 0;
    local *REVTOOL;

    foreach my $f (split(' ', $pkg_file)) {
        if (!(-d $f) && !(-f $f && -s _)) {
            $missing = 1;
        }
    }
    if (! $missing) {
        dprint "No need to retrieve:  $pkg_file\n";
        return (AVALON_DUPLICATE, undef);
    }

    if (&login_to_master()) {
        $err = &update_from_master($pkg_file);
        return ($err, "");
    }
    return (AVALON_BAD_LOGIN, "Login failure");
}

# Figure out the type of a particular package file
sub
identify_package
{
    if (substr($pkg_file, -4, 4) eq ".rpm") {
        $pkg_type{$pkg_file} = "rpm";
    } elsif (substr($pkg_file, -4, 4) eq ".deb") {
        $pkg_type{$pkg_file} = "deb";
    } elsif ($pkg_file =~ /\.(tar\.|t)?(gz|bz|bz2|Z)$/) {
        $pkg_type{$pkg_file} = "tar";
    }
    dprint "Identified $pkg_file as $pkg_type{$pkg_file}\n";
}

sub
package_install
{
    my $type;

    if (! $pkg_file) {
        return (AVALON_SYNTAX_ERROR, "You cannot install without specifying a package.\n");
    }
    if ($pkg_type{$pkg_file} eq "rpm") {
        return &rpm_install($pkg_file);
    } elsif ($pkg_type{$pkg_file} eq "deb") {
        return &deb_install($pkg_file);
    } elsif ($pkg_type{$pkg_file} eq "tar") {
        return &tar_install($pkg_file);
    }
    return (AVALON_BAD_PACKAGE, "Unable to identify package $pkg_file.\n");
}

sub
package_show_contents
{
    if (! $pkg_file) {
        return (AVALON_SYNTAX_ERROR, "You cannot display contents without specifying a package.\n");
    }
    if ($pkg_type{$pkg_file} eq "rpm") {
        return &rpm_show_contents($pkg_file);
    } elsif ($pkg_type{$pkg_file} eq "deb") {
        return &deb_show_contents($pkg_file);
    } elsif ($pkg_type{$pkg_file} eq "tar") {
        return &tar_show_contents($pkg_file);
    }
    return (AVALON_BAD_PACKAGE, "Unable to identify package $pkg_file.\n");
}

sub
package_query
{
    my $query_type = $_[0];

    if (! $pkg_file) {
        return (AVALON_SYNTAX_ERROR, "You cannot query without specifying a package.\n");
    }
    if ($pkg_type{$pkg_file} eq "rpm") {
        return &rpm_query($query_type);
    } elsif ($pkg_type{$pkg_file} eq "deb") {
        return &deb_query($query_type);
    } elsif ($pkg_type{$pkg_file} eq "tar") {
        return &tar_query($query_type);
    }
    return (AVALON_BAD_PACKAGE, "Unable to identify package $pkg_file.\n");
}

### Private functions

# Add a %define
sub
add_define($$)
{
    my ($var, $value) = @_;

    $specdata->{DEFINES}{$var} = $value;
    dprint "Added \%define:  $var -> $specdata->{DEFINES}{$var}\n";
}

# Replace %define's in a spec file line with their values
sub
replace_defines($)
{
    my $line = $_[0];

    while ($line =~ /\%(\w+)/g) {
        my $var = $1;

        dprint "Found macro:  $var\n";
        if (defined $specdata->{DEFINES}{$var}) {
            dprint "Replacing with:  $specdata->{DEFINES}{$var}\n";
            $line =~ s/\%$var/$specdata->{DEFINES}{$var}/g;
            reset;
        } else {
            dprint "Definition not found.\n";
        }
    }
    while ($line =~ /\%\{([^\}]+)\}/g) {
        my $var = $1;

        dprint "Found macro:  $var\n";
        if (defined $specdata->{DEFINES}{$var}) {
            dprint "Replacing with:  $specdata->{DEFINES}{$var}\n";
            $line =~ s/\%\{$var\}/$specdata->{DEFINES}{$var}/g;
            reset;
        } else {
            dprint "Definition not found.\n";
        }
    }
    return $line;
}

1;
