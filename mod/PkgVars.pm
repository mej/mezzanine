# Mezzanine Package Variables Perl Module
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
# $Id: Pkg.pm,v 1.15 2001/08/15 00:52:02 mej Exp $
#

package Mezzanine::PkgVars;
use strict;
use Exporter;
use POSIX;
use Mezzanine::Util;
use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

BEGIN {
    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('&pkgvar_get', '&pkgvar_get_all', '&pkgvar_set',
               '&pkgvar_reset', '&pkgvar_name', '&pkgvar_type',
               '&pkgvar_subtype', '&pkgvar_filename',
               '&pkgvar_target', '&pkgvar_srcs', '&pkgvar_hints',
               '&pkgvar_instructions', '&pkgvar_topdir',
               '&pkgvar_instroot', '&pkgvar_buildroot',
               '&pkgvar_architecture', '&pkgvar_parameters',
               '&pkgvar_command', '&pkgvar_rcfile', '&pkgvar_tar',
               '&pkgvar_zip', '&pkgvar_cleanup', '&pkgvar_quickie',
               '&get_package_path', '&identify_package_type');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

### Initialize private global variables
my %orig_pkg_vars = ();
$orig_pkg_vars{"name"} = "";
$orig_pkg_vars{"file"} = "";
$orig_pkg_vars{"target"} = "rpms";
$orig_pkg_vars{"srcs"} = "";
$orig_pkg_vars{"hints"} = "";
$orig_pkg_vars{"hint_installer"} = "";
$orig_pkg_vars{"instructions"} = "";
$orig_pkg_vars{"topdir"} = "";
$orig_pkg_vars{"instroot"} = "";
$orig_pkg_vars{"instroot_init"} = "";
$orig_pkg_vars{"instroot_reset"} = "";
$orig_pkg_vars{"instroot_copy"} = "";
$orig_pkg_vars{"buildroot"} = &get_temp_dir() . "/mezzanine-buildroot.$$";
$orig_pkg_vars{"arch"} = "i386";
$orig_pkg_vars{"parameters"} = "";
$orig_pkg_vars{"cmd"} = "";
$orig_pkg_vars{"rcfile"} = "";
$orig_pkg_vars{"tar"} = "";
$orig_pkg_vars{"zip"} = "";
$orig_pkg_vars{"cleanup"} = "none";
$orig_pkg_vars{"builduser"} = $ENV{"USER"};
$orig_pkg_vars{"buildpkglist_filename"} = "";
$orig_pkg_vars{"allow_epoch"} = 1;
$orig_pkg_vars{"quickie"} = "";
%{$orig_pkg_vars{"type"}} = ();
%{$orig_pkg_vars{"subtype"}} = ();

my %pkg_vars = %orig_pkg_vars;

### Function prototypes
sub pkgvar_get();
sub pkgvar_get_all();
sub pkgvar_set();
sub pkgvar_reset();
sub pkgvar_name();
sub pkgvar_type();
sub pkgvar_subtype();
sub pkgvar_filename();
sub pkgvar_target();
sub pkgvar_srcs(@);
sub pkgvar_hints();
sub pkgvar_instructions();
sub pkgvar_topdir();
sub pkgvar_instroot();
sub pkgvar_buildroot();
sub pkgvar_architecture();
sub pkgvar_parameters();
sub pkgvar_command();
sub pkgvar_rcfile();
sub pkgvar_tar();
sub pkgvar_zip();
sub pkgvar_cleanup();
sub pkgvar_quickie();
sub get_package_path();
sub identify_package_type();

# Private functions

### Module cleanup
END {
}

### Function definitions

sub
pkgvar_get()
{
    dprintf("Package variable \"%s\" -> \"%s\"\n", $_[0],
            ((defined($pkg_vars{$_[0]})) ? ($pkg_vars{$_[0]}) : ("<undef>")));
    return $pkg_vars{$_[0]};
}

sub
pkgvar_get_all()
{
    dprint &print_args(@_);
    return %pkg_vars;
}

sub
pkgvar_set()
{
    my %new_pkg_vars;
    my $ret;

    dprint &print_args(@_);
    if (!scalar(@_) || !defined($_[0])) {
        return undef;
    } elsif (ref($_[0]) eq "HASH") {
        %new_pkg_vars = %{$_[0]};
    } elsif (scalar(@_) % 2 == 0) {
        %new_pkg_vars = @_;
    } elsif (defined($pkg_vars{$_[0]})) {
        return $pkg_vars{$_[0]};
    } else {
        return undef;
    }

    foreach my $var (keys(%new_pkg_vars)) {
        my $param = $new_pkg_vars{$var};

        if (defined($param)) {
            dprint "Setting $var\n";
            $pkg_vars{$var} = $param;
        }
        $ret = $pkg_vars{$var};
        dprintf("Package variable \"%s\" -> \"%s\"\n", $var,
                ((defined($ret)) ? ($ret) : ("<undef>")));
    }
    return $ret;
}

sub
pkgvar_reset()
{
    dprint &print_args(@_);
    if (ref($_[0]) eq "HASH") {
        %pkg_vars = %{$_[0]};
    } elsif (scalar(@_)) {
        %pkg_vars = @_;
    } else {
        %pkg_vars = %orig_pkg_vars;
    }
}

# Default set routines for backward compatability.
sub pkgvar_name() {return &pkgvar_set("name", @_);}
sub pkgvar_target() {return &pkgvar_set("target", @_);}
sub pkgvar_srcs() {return &pkgvar_set("srcs", @_);}
sub pkgvar_hints() {return &pkgvar_set("hints", @_);}
sub pkgvar_hint_installer() {return &pkgvar_set("hint_installer", @_);}
sub pkgvar_instructions() {return &pkgvar_set("instructions", @_);}
sub pkgvar_topdir() {return &pkgvar_set("topdir", @_);}
sub pkgvar_instroot() {return &pkgvar_set("instroot", @_);}
sub pkgvar_buildroot() {return &pkgvar_set("buildroot", @_);}
sub pkgvar_architecture() {return &pkgvar_set("architecture", @_);}
sub pkgvar_parameters() {return &pkgvar_set("parameters", @_);}
sub pkgvar_command() {return &pkgvar_set("command", @_);}
sub pkgvar_rcfile() {return &pkgvar_set("rcfile", @_);}
sub pkgvar_tar() {return &pkgvar_set("tar", @_);}
sub pkgvar_zip() {return &pkgvar_set("zip", @_);}
sub pkgvar_cleanup() {return &pkgvar_set("cleanup", @_);}
sub pkgvar_quickie() {return &pkgvar_set("quickie", @_);}

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

sub
pkgvar_type
{
    my $param = $_[0];
    my $filename = $pkg_vars{"file"};

    if (defined($param)) {
        if ($param) {
            $pkg_vars{"type"}{$filename} = $param;
        } else {
            &identify_package_type();
        }
    }
    dprint "$pkg_vars{type}{$filename}\n";
    return $pkg_vars{"type"}{$filename};
}

sub
pkgvar_subtype
{
    my $param = $_[0];
    my $filename = $pkg_vars{"file"};

    if (defined($param)) {
        if ($param) {
            $pkg_vars{"subtype"}{$filename} = $param;
        } else {
            &identify_package_type();
        }
    }
    dprint "$pkg_vars{subtype}{$filename}\n";
    return $pkg_vars{"subtype"}{$filename};
}

sub
pkgvar_filename
{
    my $param = $_[0];

    if (defined($param)) {
        if (defined($_[1])) {
            $param = &get_package_path(@_);
        }
        $pkg_vars{"file"} = ($param ?  $param : "");
    }
    &identify_package_type() if ($pkg_vars{"file"} && !$pkg_vars{"type"}{$pkg_vars{"file"}});
    dprint "$pkg_vars{file}\n";
    return $pkg_vars{"file"};
}

# Figure out the type of a particular package file
sub
identify_package_type
{
    my $filename = $pkg_vars{"file"};
    my $orig_cwd = &getcwd();

    $pkg_vars{"type"}{$filename} = $pkg_vars{"subtype"}{$filename} = "";

    if (substr($filename, -4, 4) eq ".rpm") {
        $pkg_vars{"type"}{$filename} = "rpm";
        if (substr($filename, -7, 7) eq "src.rpm") {
            $pkg_vars{"subtype"}{$filename} = "srpm";
        } else {
            $pkg_vars{"subtype"}{$filename} = "rpm";
        }
    } elsif (substr($filename, -4, 4) eq ".deb") {
        $pkg_vars{"type"}{$filename} = "deb";
        if (substr($filename, -7, 7) eq "src.deb") {
            $pkg_vars{"subtype"}{$filename} = "sdeb";
        } else {
            $pkg_vars{"subtype"}{$filename} = "deb";
        }
    } elsif ($filename =~ /\.(tar\.|t)?(gz|bz|bz2|Z)$/) {
        $pkg_vars{"type"}{$filename} = $pkg_vars{"subtype"}{$filename} = "tar";
    } elsif ((-d $filename) || ($filename eq &basename(&getcwd()))) {
        dprint "$filename is a directory.\n";
        if (($filename ne &basename(&getcwd)) && (-d $filename)) {
            chdir($filename);
        }
        if (-s "Makefile.mezz") {
            $pkg_vars{"type"}{$filename} = "CFST";
        } else {
            my $spec = $pkg_vars{"instructions"};

            if (! $spec) {
                $spec = &find_spec_file(&pkgvar_name(), ".");
            }
            if ($spec && ($spec !~ m|^\./F/|)) {
                $pkg_vars{"type"}{$filename} = "PDR";
                $pkg_vars{"instructions"} = $spec;
            } elsif (-d "F") {
                if (! $spec) {
                    $spec = &find_spec_file(&pkgvar_name(), "F");
                }
                if ($spec) {
                    $pkg_vars{"type"}{$filename} = "SPM";
                    $pkg_vars{"instructions"} = $spec;
                }
            }
        }
        if (! $pkg_vars{"type"}{$filename}) {
            $pkg_vars{"type"}{$filename} = "FST";
        }
    }
    chdir($orig_cwd);
    dprintf("Identified $filename as $pkg_vars{type}{$filename}%s.\n",
            (($pkg_vars{"subtype"}{$filename})
             ? (" ($pkg_vars{subtype}{$filename})")
             : ("")
            ));
    if (wantarray()) {
        return ($pkg_vars{"type"}{$filename}, $pkg_vars{"subtype"}{$filename});
    } else {
        return $pkg_vars{"type"}{$filename};
    }
}

### Private functions

1;
