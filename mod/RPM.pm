# Avalon RPM Perl Module
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
# $Id: RPM.pm,v 1.2 2001/07/31 03:33:55 mej Exp $
#

package Avalon::RPM;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&rpm_install', '&rpm_show_contents', '&rpm_query', '&rpm_generate_source_files', '&rpm_build');
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
sub rpm_install($);
sub rpm_show_contents($);
sub rpm_query($$);
sub rpm_generate_source_files($$$$$$);
sub rpm_build($);

# Private functions

### Module cleanup
END {
}

### Function definitions

sub
rpm_install
{
    my $pkg_file = $_[0];
    my ($rpm, $cmd, $rc, $err, $msg);
    my (@failed_deps);
    local *RPM;

    $rpm = ($pkg_prog ? $pkg_prog : "rpm");
    $rc = ($rcfile ? "--rcfile '/usr/lib/rpm/rpmrc:$rcfile'" : "");
    $cmd = "$rpm $rc" . ($rootdir ? " --root $rootdir " : " ") . "-U $pkg_file";
    dprint "About to run \"$cmd\"\n";
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    $err = AVALON_SUCCESS;
    while (<RPM>) {
        chomp($line = $_);
        print "$line\n";
        if ($line =~ /^error: failed build dependencies:/) {
            $err = AVALON_DEPENDENCIES;
            while (<RPM>) {
                chomp($line = $_);
                last if ($line !~ /is needed by/);
                $line =~ s/^\s+(\S+)\s+is needed by .*$/$1/;
                push @failed_deps, $line;
            }
            $msg = sprintf("Installing this package requires the following:  %s", join(" ", @failed_deps));
            last;
        } elsif ($line =~ /^Architecture is not included:/) {
            $err = AVALON_ARCH_MISMATCH;
            $line =~ s/^Architecture is not included:\s+//;
            $msg = "This package does not install on the $line architecture";
        }
    }
    close(RPM);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0 && $err == AVALON_SUCCESS) {
        return AVALON_UNSPECIFIED_ERROR;
    }
    if ($err == AVALON_SUCCESS) {
        print "$pkg_file successfully installed.\n";
    } else {
        eprint "$msg\n";
    }
    return $err;
}

sub
rpm_show_contents
{
    my $pkg_file = $_[0];
    my ($rpm, $cmd, $rc);
    local *RPM;

    $rpm = ($pkg_prog ? $pkg_prog : "rpm");
    $rc = ($rcfile ? "--rcfile '/usr/lib/rpm/rpmrc:$rcfile'" : "");
    $cmd = "$rpm $rc -ql " . ($pkg_file ? "-p $pkg_file" : "");
    dprint "About to run \"$cmd\"\n";
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    while (<RPM>) {
        print;
    }
    close(RPM);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0) {
        return AVALON_UNSPECIFIED_ERROR;
    }
    return AVALON_SUCCESS;
}

sub
rpm_query
{
    my ($pkg_file, $query_type) = @_;
    my ($rpm, $rpm_opt, $cmd, $rc, $line);
    my (@prov, @deps);
    local *RPM;

    if ($query_type eq "d") {
        $rpm_opt = "-q --qf '[Contains:  %{FILENAMES}\n][Provides:  %{PROVIDES}\n][Requires:  %{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION}\n]'";
    } elsif ($query_type eq "s") {
        $rpm_opt = "-q --qf 'Source:  %{SOURCERPM}\n'";
    } else {
        eprint "Unrecognized query type \"$query_type\"\n";
        return AVALON_SYNTAX_ERROR;
    }
    $rpm = ($pkg_prog ? $pkg_prog : "rpm");
    $rc = ($rcfile ? "--rcfile '/usr/lib/rpm/rpmrc:$rcfile'" : "");
    $cmd = "$rpm $rc $rpm_opt " . ($pkg_file ? "-p $pkg_file" : "-a");
    dprint "About to run \"$cmd\"\n";
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    while (<RPM>) {
        print;
    }
    close(RPM);
    dprint "\"$cmd\" returned $?\n";
    if ($? != 0) {
        return AVALON_UNSPECIFIED_ERROR;
    }
    return AVALON_SUCCESS;
}

sub
rpm_generate_source_files
{
    my ($specfile, $module, $srcs, $destdir, $tar, $zip) = @_;
    my @srcs;

    @srcs = &get_source_list($specfile, $module, $srcs, $destdir);
    return &create_source_files($destdir, $tar, $zip, @srcs);
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
        return AVALON_COMMAND_FAILED;
    }
    $err = AVALON_SUCCESS;
    while (<CMD>) {
        chomp($line = $_);
        print "$line\n";
        if ($line =~ /^Wrote:\s+(\S+\.\w+\.rpm)$/) {
            push @out_files, $1;
        } elsif ($line =~ /^(error: )?line \d+: [^:]+: /
                 || $line =~ /^(error: )?Failed to find \w+:/
                 || $line =~ /^(error: )?Symlink points to BuildRoot: /) {
            $err = AVALON_SPEC_ERRORS;
            push @spec_errors, $line;
        } elsif ($line =~ /^Bad exit status from/) {
            $err = AVALON_BUILD_FAILURE;
            $line =~ s/^Bad exit status from \S+ \((%\w+)\)/$1/;
            $msg = "The RPM $line stage exited abnormally";
        } elsif ($line =~ /^error: failed build dependencies:/) {
            $err = AVALON_DEPENDENCIES;
            while (<RPM>) {
                chomp($line = $_);
                last if ($line !~ /is needed by/);
                $line =~ s/^\s+(\S+)\s+is needed by .*$/$1/;
                push @failed_deps, $line;
            }
            $msg = "Building this package requires the following:  " . join(" ", @failed_deps);
            last;
        } elsif ($line =~ /^(error: )?Architecture is not included:/) {
            $err = AVALON_ARCH_MISMATCH;
            $line =~ s/^(error: )?Architecture is not included:\s+//;
            $msg = "This package does not build on the $line architecture";
        } elsif ($line =~ /^(error: )?File (.*): No such file or directory$/
                 || $line =~ /^(error: )?Bad file: (.*): No such file or directory$/
                 || $line =~ /^(error: )?File is not a regular file: (.*)$/
                 || $line =~ /^(error: )?Unable to open icon (\S+):$/
                 || $line =~ /^(error: )?No (patch number \d+)$/
                 || $line =~ /^(error: )?Could not open \%files file (\S+): No such file or directory$/
                 || $line =~ /^(error: )?File not found(?: by glob)?: (.*)$/) {
            $err = AVALON_MISSING_FILES;
            push @not_found, $2;
        }
    }
    close(CMD);
    dprint "\"$cmd\" returned $?\n" if ($?);
    if ($? != 0 && $err == AVALON_SUCCESS) {
        $err = AVALON_UNSPECIFIED_ERROR;
        $msg = "Unhandled package build error";
    } elsif ($#not_found != -1) {
        $msg = "The following were expected by the build, but no matching files were found:  " . join(", ", @not_found);
    } elsif ($#spec_errors != -1) {
        $msg = "The spec file contains the following errors:  " . join(", ", @spec_errors);
    }

    return ($err, $msg, join(' ', @out_files));
}

### Private functions

1;
