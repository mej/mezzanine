# Mezzanine DEB Perl Module
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
# $Id: Deb.pm,v 1.5 2003/12/30 23:02:55 mej Exp $
#

package Mezzanine::Deb;

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
    @EXPORT_OK   = ('$VERSION');
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
deb_form_command
{
    my $type = shift;
    my $cmd;

    $type = "" if (!defined($type));

    if (&pkgvar_topdir()) {
        $cmd = "cd " . &pkgvar_topdir() . " && ";
    } else {
        $cmd = "";
    }
    if ($type eq "build") {
        if (! &pkgvar_command()) {
            &pkgvar_command("dpkg-buildpackage");
        }
        $cmd .= &pkgvar_command();
        if (&pkgvar_buildroot()) {
            $cmd .= " --buildroot=\"" . &pkgvar_buildroot() . "\"";
        }
    } elsif ($type eq "install") {
        if (! &pkgvar_command()) {
            &pkgvar_command("dpkg");
        }
        $cmd .= &pkgvar_command();
        if (&pkgvar_instroot()) {
            $cmd .= " --root=\"" . &pkgvar_instroot() . "\"";
        }
    } elsif ($type eq "contents") {
    } elsif ($type eq "query") {
    }
    if (&pkgvar_parameters()) {
        $cmd .= " " . &pkgvar_parameters();
    }
    dprint "Command:  $cmd\n";
    return $cmd;
}

sub
deb_install
{
    my $cmd;
    local *DPKG;

    if (! &pkgvar_filename()) {
        return (MEZZANINE_SYNTAX_ERROR, "No package specified for install");
    }
    if (&pkgvar_subtype() eq "sdeb") {
        $cmd = &deb_form_command("install") . " -x " . &pkgvar_filename();
    } else {
        $cmd = &deb_form_command("install") . " -i " . &pkgvar_filename();
    }
    if (!open(DPKG, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    while (<DPKG>) {
        print;
    }
    close(DPKG);
    if ($? != 0) {
        return (MEZZANINE_UNSPECIFIED_ERROR, &pkgvar_command() . " returned " . ($? >> 8));
    }
    return (MEZZANINE_SUCCESS, &pkgvar_filename() . " successfully installed.");
}

sub
deb_show_contents
{
    my ($cmd, $line);
    my @results;
    local *DPKG;

    if (! &pkgvar_filename()) {
        return (MEZZANINE_SYNTAX_ERROR, "No package specified for query");
    }
    $cmd = &deb_form_command("contents") . " -c " . &pkgvar_filename();
    if (!open(DPKG, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    @results = <DPKG>;
    close(DPKG);
    return ($? >> 8, @results);
}

sub
deb_query
{
    my $query_type = $_[0];
    my ($cmd, $line);
    my (@prov, @deps);
    local *DPKG;

    $cmd = &deb_form_command("query") . " -I";
    if ($query_type eq "d") {
    $cmd = "$dpkg -I " . ($pkg_file ? "$pkg_file" : "");
    dprint "About to run \"$cmd\"\n";
    if (!open(DPKG, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    while (<DPKG>) {
        chomp($line = $_);
        if ($query_type eq "d") {
            if ($line =~ /^\s*Provides:\s+(.*)$/) {
                ($line = $1) =~ s/[\(\)]//g;
                push @prov, split(/\s*,\s*/, $line);
            } elsif ($line =~ /^\s*Depends:\s+(.*)$/) {
                ($line = $1) =~ s/[\(\)]//g;
                push @deps, split(/\s*,\s*/, $line);
            }
        }
    }
    close(DPKG);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0) {
        return MEZZANINE_UNSPECIFIED_ERROR;
    }
    foreach $prov (@prov) {
        print "Capability:  $prov\n";
    }
    foreach $dep (@deps) {
        print "Dependency:  $dep\n";
    }   
    } else {
        eprint "Unrecognized query type \"$query_type\"\n";
        return MEZZANINE_SYNTAX_ERROR;
    }
    return MEZZANINE_SUCCESS;
}

sub
deb_build
{

}


### Private functions

1;
