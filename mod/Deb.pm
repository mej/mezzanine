# Avalon DEB Perl Module
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
# $Id: Deb.pm,v 1.1 2001/07/27 01:45:37 mej Exp $
#

package Avalon::Deb;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
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
deb_install
{
    my $pkg_file = $_[0];
    my ($dpkg, $cmd);
    my @inp;
    local *DPKG;

    $dpkg = ($pkg_prog ? $pkg_prog : "dpkg");
    $cmd = "$dpkg -x $pkg_file";
    dprint "About to run \"$cmd\"\n";
    if (!open(DPKG, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    while (<DPKG>) {
        print;
    }
    close(DPKG);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0) {
        return AVALON_UNSPECIFIED_ERROR;
    }
    print "$pkg_file successfully installed.\n";
    return AVALON_SUCCESS;
}

sub
deb_show_contents
{
    my $pkg_file = $_[0];
    my ($dpkg, $cmd, $line);
    local *DPKG;

    $dpkg = ($pkg_prog ? $pkg_prog : "dpkg");
    $cmd = "$dpkg -c " . ($pkg_file ? "$pkg_file" : "");
    dprint "About to run \"$cmd\"\n";
    if (!open(DPKG, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    while (<DPKG>) {
        chomp;
        ($line = $_) =~ s/^.* \.(\/.*)$/$1/;
        print "$line\n";
    }
    close(DPKG);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0) {
        return AVALON_UNSPECIFIED_ERROR;
    }
    return AVALON_SUCCESS;
}

sub
deb_query
{
    my ($pkg_file, $query_type) = @_;
    my ($dpkg, $cmd, $line);
    my (@prov, @deps);
    local *DPKG;

    if ($query_type eq "d") {
    } else {
        eprint "Unrecognized query type \"$query_type\"\n";
        return AVALON_SYNTAX_ERROR;
    }
    $dpkg = ($pkg_prog ? $pkg_prog : "dpkg");
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
        return AVALON_UNSPECIFIED_ERROR;
    }
    foreach $prov (@prov) {
        print "Capability:  $prov\n";
    }
    foreach $dep (@deps) {
        print "Dependency:  $dep\n";
    }   
    return AVALON_SUCCESS;
}

sub
deb_build
{

}


### Private functions

1;
