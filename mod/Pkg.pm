# Avalon Pkgtool Perl Module
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
# $Id: Pkg.pm,v 1.1 2001/03/26 09:48:54 mej Exp $
#

package Avalon::Pkgtool;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    # set the version for version checking
    $VERSION     = 2.0;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&parse_spec_file');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
our @EXPORT_OK;

### Private global variables

### Initialize exported package variables

### Initialize private global variables

### Function prototypes
sub parse_spec_file($$);

# Private functions
sub add_define($$);
sub replace_defines($);

### Module cleanup
END {
}

### Function definitions

# Parse spec file
sub
parse_spec_file($$)
{
    my ($specfile, $catalog) = @_;
    my ($line, $oldline, $stage, $pkg);
    local *SPECFILE;

    if (! $specfile) {
        # Look in the specified module
    }

    open(SPECFILE, $specfile) || &fatal_error("Unable to open $specfile -- $!\n");
    $stage = 0;
    while (<SPECFILE>) {
        chomp($line = $_);
        next if ($line =~ /^\s*\#/ || $line =~ /^\s*$/);
        $oldline = $line;
        $line = &replace_defines($oldline);
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
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
                $pkg = "$packages[0]-$param";
                push @packages, $pkg;
            }
        } elsif ((! $stage) && $line =~ /^\s*(\w+)\s*:\s*(.*)\s*$/) {
            my ($var, $value) = ($1, $2);

            $var =~ tr/[A-Z]/[a-z]/;
            if ($var eq "name") {
                $pkg = $value;
                @packages = ($pkg);
                &add_define("PACKAGE_NAME", $value);
                &add_define("name", $value) if (! $define{"name"});
            } elsif ($var =~ /^source(\d*)$/) {
                my $key = ($1 ? $1 : "0");

                $value =~ s/^.*\/([^\/]+)$/$1/;
                $source{$key} = $value;
                &add_define("SOURCE$key", $value);
            } elsif ($var =~ /^patch(\d*)$/) {
                my $key = ($1 ? $1 : "0");

                $value =~ s/^.*\/([^\/]+)$/$1/;
                $patch{$key} = $value;
                &add_define("PATCH$key", $value);
            } else {
                $header{$var} = $value;
                if ($var eq "version") {
                    &add_define("PACKAGE_VERSION", $value);
                    &add_define("version", $value) if (! $define{"version"});
                } elsif ($var eq "release") {
                    &add_define("PACKAGE_RELEASE", $value);
                    &add_define("release", $value) if (! $define{"release"});
                }
            }
        } elsif ($line =~ /^%\s*define\s*(\w+)\s*(.*)$/) {
            &add_define($1, $2);
        }
    }
    close(SPECFILE);

    @sources = sort {$a <=> $b} keys %source;
    @patches = sort {$a <=> $b} keys %patch;
    @headers = sort {uc($a) cmp uc($b)} keys %header;

    if ($catalog) {
        foreach $src (@sources) {
            print "S:$src:$source{$src}\n";
        }
        foreach $p (@patches) {
            print "P:$p:$patch{$p}\n";
        }
        foreach $h (@headers) {
            print "H:$h:$header{$h}\n";
        }
    } elsif ($debug) {
        dprint "Got the following sources:\n";
        foreach $src (@sources) {
            dprint "    Source $src -> $source{$src}\n";
        }
        dprint "Got the following patches:\n";
        foreach $p (@patches) {
            dprint "    Patch $p -> $patch{$p}\n";
        }
        dprint "Got the following header info:\n";
        foreach $h (@headers) {
            dprint "    $h -> $header{$h}\n";
        }
    }
}

### Private functions

# Add a %define
sub
add_define($$)
{
    my ($var, $value) = @_;

    $define{$var} = $value;
    dprint "Added \%define:  $var -> $define{$var}\n";
}

# Replace %define's in a spec file line with their values
sub
replace_defines($)
{
    my $line = $_[0];

    while ($line =~ /\%(\w+)/g) {
        my $var = $1;

        dprint "Found macro:  $var\n";
        if (defined $define{$var}) {
            dprint "Replacing with:  $define{$var}\n";
            $line =~ s/\%$var/$define{$var}/g;
            reset;
        } else {
            dprint "Definition not found.\n";
        }
    }
    while ($line =~ /\%\{([^\}]+)\}/g) {
        my $var = $1;

        dprint "Found macro:  $var\n";
        if (defined $define{$var}) {
            dprint "Replacing with:  $define{$var}\n";
            $line =~ s/\%\{$var\}/$define{$var}/g;
            reset;
        } else {
            dprint "Definition not found.\n";
        }
    }
    return $line;
}

1;
