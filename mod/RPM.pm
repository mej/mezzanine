# Mezzanine RPM Perl Module
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
# $Id: RPM.pm,v 1.10 2001/10/10 15:12:25 mej Exp $
#

package Mezzanine::RPM;

BEGIN {
    use Exporter   ();
    use Mezzanine::Util;
    use Mezzanine::PkgVars;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('$specdata', '&rpm_form_command', '&parse_spec_file', '&rpm_install', '&rpm_show_contents', '&rpm_query', '&rpm_build');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$specdata = 0;

# Constants

### Initialize private global variables

### Function prototypes
sub rpm_form_command($);
sub parse_spec_file();
sub rpm_install();
sub rpm_show_contents();
sub rpm_query($);
sub rpm_build($);

# Private functions
sub add_define($$);
sub replace_defines($);

### Module cleanup
END {
}

### Function definitions

sub
rpm_form_command
{
    my $type = shift;

    $type = "" if (!defined($type));

    if (! &pkgvar_command()) {
        &pkgvar_command("/bin/rpm");
    }
    $cmd = &pkgvar_command();
    if (&pkgvar_rcfile()) {
        $cmd .= " --rcfile=\"/usr/lib/rpm/rpmrc:" . &pkgvar_rcfile() . "\"";
    }
    if (&pkgvar_topdir()) {
        $cmd .= " --define '_topdir " . &pkgvar_topdir() . "'";
    }
    if ($type eq "build") {
        $cmd .= " --define 'optflags $ENV{CFLAGS}'";
        if (&pkgvar_buildroot()) {
            $cmd .= " --buildroot=\"" . &pkgvar_buildroot() . "\"";
        }
        if (&pkgvar_architecture()) {
            $cmd .= " --target=\"" . &pkgvar_architecture() . "\"";
        }
    } elsif ($type eq "install") {
        if (&pkgvar_instroot()) {
            $cmd .= " --root=\"" . &pkgvar_instroot() . "\"";
        }
    }
    if (&pkgvar_parameters()) {
        $cmd .= " " . &pkgvar_parameters();
    }
    dprint "Command:  $cmd\n";
    return $cmd;
}

# Parse spec file
sub
parse_spec_file
{
    my $specfile = &pkgvar_instructions();
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

    if ($debug) {
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

sub
rpm_install
{
    my ($cmd, $err, $msg, $line);
    my (@failed_deps);
    local *RPM;

    if (! &pkgvar_filename()) {
        return (MEZZANINE_SYNTAX_ERROR, "No package specified for install");
    }
    $cmd = &rpm_form_command("install") . " -U " . &pkgvar_filename();
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    $err = MEZZANINE_SUCCESS;
    while (<RPM>) {
        chomp($line = $_);
        print "$line\n";
        if ($line =~ /^error: failed .*dependencies:/) {
            $err = MEZZANINE_DEPENDENCIES;
            while (<RPM>) {
                chomp($line = $_);
                last if ($line !~ /is needed by/);
                $line =~ s/^\s+(\S+)\s+is needed by .*$/$1/;
                push @failed_deps, $line;
            }
            $msg = "Installing this package requires the following:  " . join(" ", @failed_deps);
            last;
        } elsif ($line =~ /^Architecture is not included:/) {
            $err = MEZZANINE_ARCH_MISMATCH;
            $line =~ s/^Architecture is not included:\s+//;
            $msg = "This package does not install on the $line architecture";
        }
    }
    close(RPM);
    dprint "\"$cmd\" returned $?\n" if ($?);
    if ($? != 0 && $err == MEZZANINE_SUCCESS) {
        return MEZZANINE_UNSPECIFIED_ERROR;
    }
    if ($err == MEZZANINE_SUCCESS) {
        $msg = &pkgvar_filename() . " successfully installed";
    }
    return ($err, $msg);
}

sub
rpm_show_contents
{
    my $cmd;
    my @results;
    local *RPM;

    $cmd = &rpm_form_command("contents") . " -qlv -p " . &pkgvar_filename();
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    @results = <RPM>;
    close(RPM);
    dprint "\"$cmd\" returned $?\n" if ($?);
    return ($? >> 8, @results);
}

sub
rpm_query
{
    my $query_type = $_[0];
    my $cmd;
    my (@results);
    local *RPM;

    $cmd = &rpm_form_command("query");
    if ($query_type eq "d") {
        $cmd .= " -q --qf '[Contains:  %{FILENAMES}\n][Provides:  %{PROVIDES}\n]"
            . "[Requires:  %{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION}\n]'";
    } elsif ($query_type eq "s") {
        $cmd .= " -q --qf 'Source:  %{SOURCERPM}\n'";
    } else {
        return (MEZZANINE_SYNTAX_ERROR, "Unrecognized query type \"$query_type\"\n");
    }
    if (&pkgvar_filename()) {
        $cmd .= " -p " . &pkgvar_filename();
    } else {
        $cmd .= " -a";
    }
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    @results = <RPM>;
    close(RPM);
    dprint "\"$cmd\" returned $?\n" if ($?);
    return ($? >> 8, @results);
}

sub
rpm_build
{
    my $cmd = $_[0];
    my ($line, $err, $msg);
    my (@failed_deps, @not_found, @spec_errors, @out_files);
    local *CMD;

    $err = $msg = 0;
    if (!open(CMD, "$cmd </dev/null 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
        return MEZZANINE_COMMAND_FAILED;
    }
    $err = MEZZANINE_SUCCESS;
    while (<CMD>) {
        chomp($line = $_);
        print "$line\n";
        if ($line =~ /^Wrote:\s+(\S+\.\w+\.rpm)$/) {
            push @out_files, $1;
        } elsif ($line =~ /^rpm:\s*no spec files given for build/) {
            $err = MEZZANINE_NO_SOURCES;
            $msg = "Attempted build with no spec file";
        } elsif ($line =~ /^(error: )?line \d+: [^:]+: /
                 || $line =~ /^(error: )?Failed to find \w+:/
                 || $line =~ /^(error: )?Symlink points to BuildRoot: /) {
            $err = MEZZANINE_SPEC_ERRORS;
            push @spec_errors, $line;
        } elsif ($line =~ /^Bad exit status from/) {
            $err = MEZZANINE_BUILD_FAILURE;
            $line =~ s/^Bad exit status from \S+ \((%\w+)\)/$1/;
            $msg = "The RPM $line stage exited abnormally";
        } elsif ($line =~ /^error: failed build dependencies:/) {
            $err = MEZZANINE_DEPENDENCIES;
            while (<CMD>) {
                chomp($line = $_);
                last if ($line !~ /is needed by/);
                $line =~ s/^\s+(\S+)\s+is needed by .*$/$1/;
                push @failed_deps, $line;
            }
            $msg = "Building this package requires the following:  " . join(" ", @failed_deps);
            last;
        } elsif ($line =~ /^(error: )?Architecture is not included:/) {
            $err = MEZZANINE_ARCH_MISMATCH;
            $line =~ s/^(error: )?Architecture is not included:\s+//;
            $msg = "This package does not build on the $line architecture";
        } elsif ($line =~ /^(error: )?File (.*): No such file or directory$/
                 || $line =~ /^(error: )?Bad file: (.*): No such file or directory$/
                 || $line =~ /^(error: )?File is not a regular file: (.*)$/
                 || $line =~ /^(error: )?Unable to open icon (\S+):$/
                 || $line =~ /^(error: )?No (patch number \d+)$/
                 || $line =~ /^(error: )?Could not open \%files file (\S+): No such file or directory$/
                 || $line =~ /^(error: )?File not found(?: by glob)?: (.*)$/) {
            $err = MEZZANINE_MISSING_FILES;
            push @not_found, $2;
        }
    }
    close(CMD);
    dprint "\"$cmd\" returned $?\n" if ($?);
    if ($? != 0 && $err == MEZZANINE_SUCCESS) {
        $err = MEZZANINE_UNSPECIFIED_ERROR;
        $msg = "Unhandled package build error";
    } elsif ($#not_found != -1) {
        $msg = "The following were expected by the build, but no matching files were found:  " . join(", ", @not_found);
    } elsif ($#spec_errors != -1) {
        $msg = "The spec file contains the following errors:  " . join(", ", @spec_errors);
    }

    return ($err, $msg, join(' ', @out_files));
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
