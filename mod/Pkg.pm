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
# $Id: Pkg.pm,v 1.14 2001/08/14 19:32:33 mej Exp $
#

package Avalon::Pkg;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use Avalon::RevCtl;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('$specdata', '&get_package_path', '&parse_spec_file', '&fetch_package', '&identify_package');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$specdata = 0;

### Initialize private global variables

### Function prototypes
sub get_package_path($$);
sub parse_spec_file($$);
sub fetch_package($$$$$);
sub identify_package($);

# Private functions
sub add_define($$);
sub replace_defines($);

### Module cleanup
END {
}

### Function definitions

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

# Parse spec file
sub
parse_spec_file($$)
{
    my ($specfile, $catalog) = @_;
    my ($line, $oldline, $stage, $pkg);
    local *SPECFILE;

    if (! $specfile) {
        return 0;
    }

    open(SPECFILE, $specfile) || return 0;
    $stage = 0;
    $specdata->{SPECFILE} = $specfile;
    while (<SPECFILE>) {
        chomp($line = $_);
        next if ($line =~ /^\s*\#/ || $line =~ /^\s*$/);
        $oldline = $line;
        $line = &replace_defines($oldline);
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        push @{$specdata->{FILE}}, $line;
        if ($oldline ne $line) {
            dprint "Parsing from $specfile, line $.: \"$oldline\" -> \"$line\"\n";
        } else {
            dprint "Parsing from $specfile, line $.: \"$line\"\n";
        }
        if ($line =~ /^\%(prep|build|install|clean|changelog|trigger|triggerpostun|triggerun|triggerin|verifyscript)\s*$/
            || $line =~ /^\%(package|preun|pre|postun|post|files|description)(\s+\w+)?$/) {
            my $param = $2;

            $stage = $1;
            dprint "Switching to stage \"$stage\"\n";
            if ($stage eq "package" && $param) {
                $pkg = $specdata->{PKGS}[0] . "-$param";
                push @{$specdata->{PKGS}}, $pkg;
            }
        } elsif ((! $stage) && $line =~ /^\s*(\w+)\s*:\s*(.*)\s*$/) {
            my ($var, $value) = ($1, $2);

            $var =~ tr/[A-Z]/[a-z]/;
            if ($var eq "name") {
                $pkg = $value;
                @{$specdata->{PKGS}} = ($pkg);
                &add_define("PACKAGE_NAME", $value);
                &add_define("name", $value) if (! $specdata->{DEFINES}{"name"});
            } elsif ($var =~ /^source(\d*)$/) {
                my $key = ($1 ? $1 : "0");

                $value =~ s/^.*\/([^\/]+)$/$1/;
                $specdata->{SOURCE}{$key} = $value;
                &add_define("SOURCE$key", $value);
            } elsif ($var =~ /^patch(\d*)$/) {
                my $key = ($1 ? $1 : "0");

                $value =~ s/^.*\/([^\/]+)$/$1/;
                $specdata->{PATCH}{$key} = $value;
                &add_define("PATCH$key", $value);
            } else {
                $specdata->{HEADER}{$var} = $value;
                if ($var eq "version") {
                    &add_define("PACKAGE_VERSION", $value);
                    &add_define("version", $value) if (! $specdata->{DEFINES}{"version"});
                } elsif ($var eq "release") {
                    &add_define("PACKAGE_RELEASE", $value);
                    &add_define("release", $value) if (! $specdata->{DEFINES}{"release"});
                }
            }
        } elsif ($line =~ /^%\s*define\s*(\w+)\s*(.*)$/) {
            &add_define($1, $2);
        }
    }
    close(SPECFILE);

    @{$specdata->{SOURCES}} = sort {$a <=> $b} keys %{$specdata->{SOURCE}};
    @{$specdata->{PATCHES}} = sort {$a <=> $b} keys %{$specdata->{PATCH}};
    @{$specdata->{HEADERS}} = sort {uc($a) cmp uc($b)} keys %{$specdata->{HEADER}};

    if ($catalog) {
        foreach $src (@{$specdata->{SOURCES}}) {
            print "S:$src:$specdata->{SOURCE}{$src}\n";
        }
        foreach $p (@{$specdata->{PATCHES}}) {
            print "P:$p:$specdata->{PATCH}{$p}\n";
        }
        foreach $h (@{$specdata->{HEADERS}}) {
            print "H:$h:$specdata->{HEADER}{$h}\n";
        }
    } elsif ($debug) {
        dprint "Got the following sources:\n";
        foreach $src (@{$specdata->{SOURCES}}) {
            dprint "    Source $src -> $specdata->{SOURCE}{$src}\n";
        }
        dprint "Got the following patches:\n";
        foreach $p (@{$specdata->{PATCHES}}) {
            dprint "    Patch $p -> $specdata->{PATCH}{$p}\n";
        }
        dprint "Got the following header info:\n";
        foreach $h (@{$specdata->{HEADERS}}) {
            dprint "    $h -> $specdata->{HEADER}{$h}\n";
        }
    }
    return $specdata;
}

# Use revtool to download a package from the master repository
sub
fetch_package
{
    my ($module, $filename, $tag, $repository, $opts) = @_;
    my ($err, $msg, $line) = undef;
    my $missing = 0;
    local *REVTOOL;

    $filename = "" if (!defined($filename));
    $tag = "" if (!defined($tag));
    $repository = "" if (!defined($repository));
    $opts = "" if (!defined($opts));
    dprint "Getting $filename", ($module ? " (in $module) " : ""), ($repository ? " from $repository" : ""),
           ($tag ? " using $tag" : ""), ($opts ? " and extra options $opts" : ""), ".\n";
    if (! ($filename = &get_package_path($module, $filename))) {
        return (AVALON_BAD_PACKAGE, "Could not determine what package(s)/module(s) to retrieve.");
    }
    &set_repository($repository);
    &set_tag(($tag eq head ? "" : $tag));
    foreach my $f (split(' ', $filename)) {
        if (!(-d $f) && !(-f $f && -s _)) {
            $missing = 1;
        }
    }
    if (! $missing) {
        dprint "No need to retrieve:  $filename\n";
        return (AVALON_DUPLICATE, undef);
    }

    if (&login_to_master()) {
        $err = &update_from_master($filename);
        return ($err, "");
    }
    return (AVALON_BAD_LOGIN, "Login failure");
}

# Figure out the type of a particular package file
sub
identify_package
{
    my $pkg_file = shift;
    my $type = "";

    if (substr($pkg_file, -4, 4) eq ".rpm") {
        $type = "rpm";
    } elsif (substr($pkg_file, -4, 4) eq ".deb") {
        $type = "deb";
    } elsif ($pkg_file =~ /\.(tar\.|t)?(gz|bz|bz2|Z)$/) {
        $type = "tar";
    }
    dprint "Identified $pkg_file as $type\n";
    return $type;
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
