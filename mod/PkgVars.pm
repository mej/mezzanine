# Avalon Package Variables Perl Module
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

package Avalon::PkgVars;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&pkgvar_reset', '&pkgvar_name', '&pkgvar_type', '&pkgvar_filename', '&pkgvar_target', '&pkgvar_srcs', '&pkgvar_instructions', '&pkgvar_topdir', '&pkgvar_instroot', '&pkgvar_buildroot', '&pkgvar_architecture', '&pkgvar_parameters', '&pkgvar_command', '&pkgvar_rcfile', '&pkgvar_tar', '&pkgvar_zip', '&pkgvar_cleanup', '&get_package_path', '&identify_package');
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
$pkg_tar = "";
$pkg_zip = "";
$pkg_cleanup = "none";
%pkg_type = ();

### Function prototypes
sub pkgvar_reset();
sub pkgvar_name($);
sub pkgvar_type($);
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
sub identify_package($);

# Private functions

### Module cleanup
END {
}

### Function definitions

sub
pkgvar_reset
{
    &pkgvar_name("");
    &pkgvar_type("");
    &pkgvar_filename("");
    &pkgvar_target("");
    &pkgvar_srcs("");
    &pkgvar_instructions("");
    &pkgvar_topdir("");
    &pkgvar_instroot("");
    &pkgvar_buildroot("");
    &pkgvar_architecture("");
    &pkgvar_parameters("");
    &pkgvar_command("");
    &pkgvar_rcfile("");
    &pkgvar_tar("");
    &pkgvar_zip("");
    &pkgvar_cleanup("");
}

sub
pkgvar_name
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_name = ($param ?  $param : "");
    }
    dprint "$pkg_name\n";
    return $pkg_name;
}

sub
pkgvar_type
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_type{$pkg_file} = ($param ?  $param : &identify_package());
    }
    dprint "$pkg_type{$pkg_file}\n";
    return $pkg_type{$pkg_file};
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
    &identify_package() if ($pkg_file && !$pkg_type{$pkg_file});
    dprint "$pkg_file\n";
    return $pkg_file;
}

sub
pkgvar_target
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_target = ($param ? $param : "rpms");
    }
    dprint "$pkg_target\n";
    return $pkg_target;
}

sub
pkgvar_srcs
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_srcs = ($param ? $param : "");
    }
    dprint "$pkg_srcs\n";
    return $pkg_srcs;
}

sub
pkgvar_instructions
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_inst = ($param ?  $param : "");
    }
    dprint "$pkg_inst\n";
    return $pkg_inst;
}

sub
pkgvar_topdir
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_topdir = ($param ? $param : "");
    }
    dprint "$pkg_topdir\n";
    return $pkg_topdir;
}

sub
pkgvar_instroot
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_instroot = ($param ? $param : "");
    }
    dprint "$pkg_instroot\n";
    return $pkg_instroot;
}

sub
pkgvar_buildroot
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_buildroot = ($param ? $param : "");
    }
    dprint "$pkg_buildroot\n";
    return $pkg_buildroot;
}

sub
pkgvar_architecture
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_arch = ($param ? $param : "i386");
    }
    dprint "$pkg_arch\n";
    return $pkg_arch;
}

sub
pkgvar_parameters
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_params = ($param ? $param : "");
    }
    dprint "$pkg_params\n";
    return $pkg_params;
}

sub
pkgvar_command
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_cmd = ($param ? $param : "");
    }
    dprint "$pkg_cmd\n";
    return $pkg_cmd;
}

sub
pkgvar_rcfile
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_rcfile = ($param ? $param : "");
    }
    dprint "$pkg_rcfile\n";
    return $pkg_rcfile;
}

sub
pkgvar_tar
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_tar = ($param ? $param : "");
    }
    dprint "$pkg_tar\n";
    return $pkg_tar;
}

sub
pkgvar_zip
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_zip = ($param ? $param : "");
    }
    dprint "$pkg_zip\n";
    return $pkg_zip;
}

sub
pkgvar_cleanup
{
    my $param = $_[0];

    if (defined($param)) {
        $pkg_cleanup = ($param ? $param : "none");
    }
    dprint "$pkg_cleanup\n";
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
    } else {
        $pkg_type{$pkg_file} = "";
    }
    dprint "Identified $pkg_file as $pkg_type{$pkg_file}\n";
}

### Private functions

1;
