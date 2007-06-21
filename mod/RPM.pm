# Mezzanine RPM Perl Module
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
# $Id: RPM.pm,v 1.55 2007/06/21 03:17:42 mej Exp $
#

package Mezzanine::RPM;
use English;

BEGIN {
    use strict;
    use Exporter   ();
    #use POSIX ('&geteuid');
    use File::Find;
    use File::Listing 'parse_dir';
    use IPC::Open3;
    use Mezzanine::Util;
    use Mezzanine::PkgVars;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('$specdata', '&rpm_form_command', '&parse_spec_file',
               '&disable_patch', '&enable_patch', '&rpm_install',
               '&rpm_show_contents', '&rpm_query', '&rpm_build',
               '&rpm_compare_versions', '&rpm_get_installed',
               '&rpm_scan_files', '&rpm_cmp', '&rpm_sort');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$specdata = undef;

# Constants

### Initialize private global variables
my $RPMVERCMP_IN = undef;
my $RPMVERCMP_OUT = undef;

### Function prototypes
sub rpm_form_command($);
sub parse_spec_file();
sub disable_patch($);
sub enable_patch($);
sub rpm_install();
sub rpm_show_contents();
sub rpm_query($);
sub rpm_build();
sub rpm_compare_versions($$);
sub rpm_get_installed();
sub rpm_scan_files(@);
sub rpm_cmp($$);
sub rpm_sort(@);

# Private functions
sub add_define($$);
sub replace_defines($);
sub parse_deps($);

### Module cleanup
END {
    if ($RPMVERCMP_IN) {
        close($RPMVERCMP_IN);
    }
    if ($RPMVERCMP_OUT) {
        close($RPMVERCMP_OUT);
    }
}

### Function definitions

sub
rpm_form_command
{
    my $type = shift;

    $type = "" if (!defined($type));

    if ($type eq "build") {
        if (! &pkgvar_command()) {
            if (&pkgvar_instroot()) {
                &pkgvar_command("chroot " . &pkgvar_instroot()
                                . ((&file_user() == $UID) ? ("") : (sprintf(" /bin/su -s /bin/sh %s -c",
                                                                            &pkgvar_get("builduser"))))
                                . " /bin/sh -c \"/usr/bin/rpmbuild");
            } else {
                &pkgvar_command("/bin/sh -c \"/usr/bin/rpmbuild");
            }
        } elsif (&pkgvar_instroot()) {
            &pkgvar_command("chroot " . &pkgvar_instroot() . " " . &pkgvar_command());
        }
    } elsif ($type eq "query") {
        if (! &pkgvar_command()) {
            &pkgvar_command(((&file_user() == $UID) ? ("") : (sprintf("/bin/su -s /bin/sh %s -c", &pkgvar_get("builduser"))))
                            . " /bin/sh -c \"/usr/bin/rpmquery");
        }
    } else {
        if (! &pkgvar_command()) {
            &pkgvar_command(((&file_user() == $UID) ? ("") : (sprintf("/bin/su -s /bin/sh %s -c", &pkgvar_get("builduser"))))
                            . " /bin/sh -c \"/bin/rpm");
        }
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
            $cmd .= " --buildroot '" . &pkgvar_buildroot() . "'";
        }
        if (&pkgvar_architecture()) {
            $cmd .= " --target='" . &pkgvar_architecture() . "'";
        }
    } elsif ($type eq "install" || $type eq "buildpkglist") {
        if (&pkgvar_instroot()) {
            if (-x (&pkgvar_instroot() . "/bin/rpm")) {
                # The version of RPM in the chroot may not match the system one,
                # so try to use the one in the chroot if it's there.
                $cmd = "chroot " . &pkgvar_instroot() . ' ' . $cmd;

                # Warn if the target file doesn't exist in the chroot.
                if (&pkgvar_filename() && (! -e (&pkgvar_instroot() . '/' . &pkgvar_filename()))) {
                    wprintf("%s does not exist under %s.\n", &pkgvar_filename(), &pkgvar_instroot());
                }
            } else {
                $cmd .= " --root='" . &pkgvar_instroot() . "'";
            }
        }
    }
    if (&pkgvar_parameters()) {
        $cmd .= " " . &pkgvar_parameters();
    }

    # Add final cleanups
    if ($type eq "build") {
        if (&pkgvar_instructions()) {
            $cmd .= " -ba " . &pkgvar_instructions();
        } elsif (&pkgvar_filename()) {
            if (&pkgvar_type() eq "srpm") {
                $cmd .= " --rebuild " . &pkgvar_filename();
            } elsif (&pkgvar_type() eq "tar") {
                $cmd .= " -ta " . &pkgvar_filename();
            } else {
                &show_backtrace();
                &fatal_error("Bad call to rpm_form_command(\"build\")!\n");
            }
        } else {
            &show_backtrace();
            &fatal_error("Bad call to rpm_form_command(\"build\")!\n");
        }
    } elsif ($type eq "contents") {
        $cmd .= " -qlv -p " . &pkgvar_filename();
    } elsif ($type eq "install") {
        if (&pkgvar_command() =~ /^(.*\/)?rpm$/) {
            $cmd .= " -U " . &pkgvar_filename();
        } else {
            $cmd .= ' ' . &pkgvar_filename();
        }
    } elsif ($type eq "query") {
        if (&pkgvar_filename()) {
            $cmd .= " -p " . &pkgvar_filename();
        } elsif (&pkgvar_name()) {
            $cmd .= ' ' . &pkgvar_name();
        } else {
            $cmd .= " -a";
        }
    } elsif ($type eq "buildpkglist") {
        $cmd .= " -qa --qf '%25{NAME} %10{EPOCH} %15{VERSION} %15{RELEASE}\n' | sort -bf";
    }
    $cmd .= "\"";

    dprint "Command:  $cmd\n";
    return &untaint(\$cmd, qr/^(.*)$/s);
}

# Parse spec file
sub
parse_spec_file
{
    my $specfile = &pkgvar_instructions();
    my ($line, $oldline, $stage, $pkg, $contents, $pid);
    my @specfile_lines;
    local *SPECFILE;

    dprint "Parsing spec file $specfile.\n";
    undef $specdata;

    if (! $specfile) {
        wprint "How can I parse a spec file with no name?\n";
        undef $specdata;
        return 0;
    }

    if (!open(SPECFILE, $specfile)) {
        wprint "Unable to open spec file $specfile -- $!\n";
        undef $specdata;
        return 0;
    }
    @specfile_lines = <SPECFILE>;
    close(SPECFILE);

    $contents = join("", @specfile_lines);
    $contents = &untaint(\$contents, qr/^(.*)$/s);  # Anything goes; no risk here.

    dprint "Attempting to launch helper to parse spec file contents.\n";
    $pid = open(SPECFILE, "-|");
    if (!defined($pid)) {
        wprint "Unable to pre-process spec file $specfile -- $!\n";
    } elsif ($pid == 0) {
        exec("rpmeval", $contents);
        wprint "Unable to exec rpmeval -- $!.  Trying /bin/rpm --eval\n";
        exec("/bin/rpm", "--eval", $contents);
        &fatal_error("Unable to exec /bin/rpm -- $!\n");
    } else {
        my @tmp;

        dprint "Child process $pid launched; reading from child's STDOUT.\n";
        #while (<SPECFILE>) {
        #    my $line = $_;

        #    dprint "eval-> $line";
        #    push @tmp, $line;
        #}
        @tmp = <SPECFILE>;
        close(SPECFILE);
        dprintf("Got %d lines back from helper.\n", scalar(@tmp));
        if (scalar(@tmp) > 10) {
            @specfile_lines = @tmp;
        } else {
            wprint "Pre-processing spec file $specfile failed; using internal parser.\n";
        }
    }

    dprint "Internal parser reading spec file.\n";
    $stage = 0;
    $specdata->{"SPECFILE"} = $specfile;
    $specdata->{"DEFINES"}{"nil"} = "";
    foreach my $line (@specfile_lines) {
        chomp($line);
        if ($line =~ /^(\s*\#\s*BuildSuggests:)/) {
            $line =~ s/$1/BuildRequires:/;
        } elsif ($line =~ /(unable to exec \S+ -- .*)$/i) {
            wprint "$1\n";
            next;
        } elsif ($line =~ /^\s*\#/ || $line =~ /^\s*$/) {
            next;
        }
        $oldline = $line;
        $line = &replace_defines($oldline);
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        push @{$specdata->{"FILE"}}, $line;
        if ($oldline ne $line) {
            #dprint "Parsing from $specfile, line $.: \"$oldline\" -> \"$line\"\n";
        } else {
            #dprint "Parsing from $specfile, line $.: \"$line\"\n";
        }
        if ($line =~ /^\%(prep|build|install|clean|changelog|trigger|triggerpostun|triggerun|triggerin|verifyscript)\s+/
            || $line =~ /^\%(package|preun|pre|postun|post|files|description)\s+/) {
            my $param = $2;

            $stage = $1;
            #dprint "Switching to stage \"$stage\"\n";
            push @{$specdata->{"STAGES"}}, $stage;
            if ($stage eq "package" && $param) {
                $pkg = $specdata->{"PKGS"}[0] . "-$param";
                push @{$specdata->{"PKGS"}}, $pkg;
            }
        } elsif (((! $stage) || ($stage eq "package"))
                 && $line =~ /^\s*(\w+)\s*:\s*(.*)\s*$/) {
            my ($var, $value) = ($1, $2);

            $var = lc($var);
            #dprint "Header:  $var -> $value\n";

            # Aliases
            if ($var eq "copyright") {
                $var = "license";
            } elsif ($var eq "serial") {
                $var = "epoch";
            }

            if ($var eq "name") {
                $pkg = $value;
                @{$specdata->{"PKGS"}} = ($pkg);
                &add_define("PACKAGE_NAME", $value);
                &add_define("name", $value) if (! $specdata->{"DEFINES"}{"name"});
            } elsif ($var =~ /^source(\d*)$/) {
                my $key = ($1 ? $1 : "0");

                $value =~ s/^.*\/([^\/]+)$/$1/;
                $specdata->{"SOURCE"}{$key} = $value;
                &add_define("SOURCE$key", $value);
            } elsif ($var =~ /^patch(\d*)$/) {
                my $key = ($1 ? $1 : "0");

                $value =~ s/^.*\/([^\/]+)$/$1/;
                $specdata->{"PATCH"}{$key} = $value;
                &add_define("PATCH$key", $value);
            } else {
                $specdata->{"HEADER"}{$var} = $value;
                if ($var eq "version") {
                    &add_define("PACKAGE_VERSION", $value);
                    &add_define("version", $value) if (! $specdata->{"DEFINES"}{"version"});
                } elsif ($var eq "release") {
                    &add_define("PACKAGE_RELEASE", $value);
                    &add_define("release", $value) if (! $specdata->{"DEFINES"}{"release"});
                } elsif ($var =~ /^(prereq|requires)$/) {
                    dprint "Got dep $value\n";
                    push @{$specdata->{"DEPS"}}, &parse_deps($value);
                } elsif ($var =~ /^build(prereq|requires)$/) {
                    dprint "Got build dep $value\n";
                    push @{$specdata->{"BUILD_DEPS"}}, &parse_deps($value);
                }
            }
        } elsif ($line =~ /^%\s*define\s*(\w+)\s*(.*)$/) {
            &add_define($1, $2);
        } else {
            push @{$specdata->{$stage}}, $line;
        }
    }

    @{$specdata->{"SOURCES"}} = sort {$a <=> $b} keys %{$specdata->{"SOURCE"}};
    @{$specdata->{"PATCHES"}} = sort {$a <=> $b} keys %{$specdata->{"PATCH"}};
    @{$specdata->{"HEADERS"}} = sort {uc($a) cmp uc($b)} keys %{$specdata->{"HEADER"}};

    if ($debug) {
        dprint "Got the following sources:\n";
        foreach my $src (@{$specdata->{"SOURCES"}}) {
            dprint "    Source $src -> $specdata->{SOURCE}{$src}\n";
        }
        dprint "Got the following patches:\n";
        foreach my $p (@{$specdata->{"PATCHES"}}) {
            dprint "    Patch $p -> $specdata->{PATCH}{$p}\n";
        }
        dprint "Got the following header info:\n";
        foreach my $h (@{$specdata->{"HEADERS"}}) {
            dprint "    $h -> $specdata->{HEADER}{$h}\n";
        }
    }
    #dprint "Returning $specdata\n";
    return $specdata;
}

sub
disable_patch($)
{
    my $patch = $_[0];
    my $specfile = &pkgvar_instructions();
    my $line;
    my @contents;
    local *SPECFILE;

    dprint "Patch $patch in $specfile is being commented out.\n";
    if (! $specfile) {
        return 0;
    }

    dprint "Reading original spec file source from $specfile.\n";
    open(SPECFILE, $specfile) || return 0;
    @contents = <SPECFILE>;
    close(SPECFILE);

    dprint "Rewriting spec file.\n";
    open(SPECFILE, ">$specfile") || return 0;
    foreach my $line (@contents) {
        chomp($line);
        if ($line =~ /^\s*\%patch(\d*)\s+/) {
            my $patch_num = $1;

            if ((($patch_num) && ($patch_num eq $patch))
                || (!($patch_num) && !($patch))) {
                dprint "Disabling:  $line\n";
                $line = '#' . $line;
            }
        }
        print SPECFILE "$line\n";
    }
    close(SPECFILE);
    return 1;
}

sub
enable_patch($)
{
    my $patch = $_[0];
    my $specfile = &pkgvar_instructions();
    my $line;
    my @contents;
    local *SPECFILE;

    dprint "Patch $patch in $specfile is being un-commented.\n";
    if (! $specfile) {
        return 0;
    }

    dprint "Reading original spec file source from $specfile.\n";
    open(SPECFILE, $specfile) || return 0;
    @contents = <SPECFILE>;
    close(SPECFILE);

    dprint "Rewriting spec file.\n";
    open(SPECFILE, ">$specfile") || return 0;
    foreach my $line (@contents) {
        chomp($line);
        if ($line =~ /^\s*\#\s*\%patch(\d*)\s+/) {
            my $patch_num = $1;

            if ((($patch_num) && ($patch_num eq $patch))
                || (!($patch_num) && !($patch))) {
                dprint "Enabling:  $line\n";
                $line =~ s/^\s*\#//;
            }
        }
        print SPECFILE "$line\n";
    }
    close(SPECFILE);
    return 1;
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
    $cmd = &rpm_form_command("install");
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

    $cmd = &rpm_form_command("contents");
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

    if (($query_type eq "d") || ($query_type eq "reqprov")) {
        &pkgvar_parameters("-q --qf '[Contains:  %{FILENAMES}\\n][Provides:  %{PROVIDES}\\n]"
                           . "[Requires:  %{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION}\\n]'");
    } elsif ($query_type eq "s") {
        &pkgvar_parameters("-q --qf 'Source:  %{SOURCERPM}\\n'");
    } elsif ($query_type eq "a") {
        &pkgvar_parameters("-q --qf '[%{NAME}\\n]'");
    } elsif ($query_type eq "reqprovall") {
        &pkgvar_parameters("-q --qf '[%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}::CONTAINS::%{FILENAMES}\\n]"
                           . "[%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}::PROVIDES::%{PROVIDENAME}::"
                           . "%{PROVIDEFLAGS:depflags}::%{PROVIDEVERSION}\\n][%{NAME}-%{VERSION}-%{RELEASE}"
                           . ".%{ARCH}::REQUIRES::%{REQUIRENAME}::%{REQUIREFLAGS:depflags}::%{REQUIREVERSION}\\n]'");
    } elsif ($query_type eq "depscan") {
        &pkgvar_parameters("-q --qf '[Contains:  %{FILENAMES}\\n]"
                           . "[Provides:  %{PROVIDENAME} %{PROVIDEFLAGS:depflags} %{PROVIDEVERSION}\\n]"
                           . "[Requires:  %{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION}\\n]"
                           . "[Conflicts:  %{CONFLICTNAME} %{CONFLICTFLAGS:depflags} %{CONFLICTVERSION}\\n]"
                           . "[Obsoletes:  %{OBSOLETENAME} %{OBSOLETEFLAGS:depflags} %{OBSOLETEVERSION}\\n]\\n'");
    } else {
        return (MEZZANINE_SYNTAX_ERROR, "Unrecognized query type \"$query_type\"\n");
    }

    $cmd = &rpm_form_command("query");
    if (!open(RPM, "$cmd 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
    }
    @results = <RPM>;
    close(RPM);
    dprint "\"$cmd\" returned $?\n" if ($?);
    return ($? >> 8, @results);
}

sub
rpm_build()
{
    my ($cmd, $line, $err, $msg);
    my (@failed_deps, @not_found, @spec_errors, @out_files, @extras);
    local *CMD;

    if (&pkgvar_get("buildpkglist_filename")) {
        my $outfile = &pkgvar_get("buildpkglist_filename");
        local *PKGLIST;

        dprint "Saving package list to $outfile.\n";
        if (open(PKGLIST, ">$outfile")) {
            $cmd = &rpm_form_command("buildpkglist");
            if (!open(CMD, "$cmd </dev/null 2>&1 |")) {
                eprint "Execution of \"$cmd\" failed -- $!\n";
                return MEZZANINE_COMMAND_FAILED;
            }
            while (<CMD>) {
                #dprint "Got package list item:  $_";
                print PKGLIST $_;
            }
            close(CMD);
            close(PKGLIST);
            chown($mz_uid, $mz_gid, $outfile);
            &pkgvar_command("");
        } else {
            eprint "Unable to write to \"$outfile\" -- $!\n";
        }
    } else {
        dprint "Not saving package list; no file given.\n";
    }
    $cmd = &rpm_form_command("build");
    $err = MEZZANINE_SUCCESS;
    $msg = 0;
    if (!open(CMD, "$cmd </dev/null 2>&1 |")) {
        eprint "Execution of \"$cmd\" failed -- $!\n";
        return MEZZANINE_COMMAND_FAILED;
    }
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
        } elsif ($line =~ /^\s*Bad exit status from/) {
            $err = MEZZANINE_BUILD_FAILURE;
            $line =~ s/^\s*Bad exit status from \S+ \((%\w+)\).*$/$1/;
            $msg = "The RPM $line stage exited abnormally";
        } elsif ($line =~ /^(error: )?(chroot: )?cannot /) {
            $err = MEZZANINE_BUILD_FAILURE;
            $line =~ s/^(error: )?(chroot: )?cannot //;
            $msg = "chroot:  Unable to $line";
        } elsif ($line =~ /^error:?\s*failed build dependencies:?\s*$/i) {
            $err = MEZZANINE_DEPENDENCIES;
            while (<CMD>) {
                chomp($line = $_);
                last if ($line !~ /is needed by/);
                $line =~ s/^\s+(.+)\s+is needed by .*$/$1/;
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
        } elsif ($line =~ /^(error: )?Installed \(but unpackaged\) file/) {
            $err = MEZZANINE_EXTRA_FILES;
            while (<CMD>) {
                chomp($line = $_);
                last if ($line !~ /^\s+\//);
                $line =~ s/^\s+(.+)$/$1/;
                push @extra_files, $line;
            }
            $msg = "The following files were not included in the built RPM:  " . join(" ", @extra_files);
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

sub
rpm_compare_versions($$)
{
    my ($v1, $v2) = @_;

    # First, see if we have a pipe to rpmcmp or can make one.
    if (!defined($RPMVERCMP_IN)) {
        if (open3($RPMVERCMP_OUT, $RPMVERCMP_IN, 0, "rpmcmp")) {
            $SIG{"PIPE"} = sub { close($RPMVERCMP_IN); close($RPMVERCMP_OUT); $RPMVERCMP_IN = $RPMVERCMP_OUT = 0; };
            select $RPMVERCMP_IN; $| = 1;
            select $RPMVERCMP_OUT; $| = 1;
            select STDOUT;
            dprint "Started rpmcmp process to do version comparisons.\n";
        } else {
            $RPMVERCMP_IN = $RPMVERCMP_OUT = 0;
            dprint "Unable to start rpmcmp process to do version comparisons -- $!.\n";
        }
    }

    if ($RPMVERCMP_OUT) {
        my $line;

        # Write versions to be compared to rpmcmp pipe.  Read back result.
        print $RPMVERCMP_OUT "$v1 $v2\n";
        if ($RPMVERCMP_IN) {
            $line = <$RPMVERCMP_IN>;
            if ($line && $RPMVERCMP_IN) {
                chomp($line);
                if ($line =~ /^$v1 (.) $v2$/) {
                    my $result = $1;

                    return (($result eq '=') ? (0) : (($result eq '<') ? (-1) : (1)));
                } elsif (($line =~ /^open3:/) || ($line =~ /warning/i) || ($line =~ /error/i)) {
                    close($RPMVERCMP_IN); close($RPMVERCMP_OUT);
                    $RPMVERCMP_IN = $RPMVERCMP_OUT = 0;
                    dprint "Detected open3() failure:  $line\n";
                } else {
                    dprint "Unrecognized output from rpmcmp pipe:  $line\n";
                }
            } else {
                dprint "Failed to read from rpmcmp pipe.\n";
            }
        } else {
            dprint "rpmcmp pipe file descriptor closed unexpectedly.  Command failed?\n";
        }
        # If we get here, we failed.  Fall back on the perl-only method below.
        dprint "Version comparison via rpmcmp failed.\n";
    }

    # Downcase everything right off the bat.
    if ($v1) {
        $v1 =~ tr/[A-Z]/[a-z]/;
    }
    if ($v2) {
        $v2 =~ tr/[A-Z]/[a-z]/;
    }

    for (; 1; ) {
        my ($s1, $s2) = ('', '');
        my ($ival1, $ival2) = (0, 0);

        if ((! $v1) || (! $v2) || !length($v1) || !length($v2)) {
            last;
        }
        if (($v1 =~ /^[a-z]+/) && ($v2 =~ /^[a-z]+/)) {

            # Copy the initial alphabetical portion of each version number
            # into $s1 and $s2 for comparison.
            $v1 =~ m/^([a-z]+)/;
            $s1 = $1;
            $v2 =~ m/^([a-z]+)/;
            $s2 = $1;

            if ($s1 ne $s2) {
                # Two arbitrary strings that differ.  Compare those normally.
                return ($s1 cmp $s2);
            }
        } elsif (($v1 =~ /^\d+/) && ($v2 =~ /^\d+/)) {
            # Copy the initial numeric portion of each version number
            # into $s1 and $s2 for comparison.
            $v1 =~ m/^(\d+)/;
            $s1 = $1;
            $v2 =~ m/^(\d+)/;
            $s2 = $1;

            if ($s1 != $s2) {
                return ($s1 <=> $s2);
            }
        } elsif ($v1 =~ /^\d+/) {
            # Numeric > alphabetical
            return 1;
        } elsif ($v2 =~ /^\d+/) {
            # Alphabetical < numeric
            return -1;
        } else {
            # Try a lexical comparison on whatever's there
            $s1 = (($v1 =~ /^([^a-z0-9]+)/) ? ($1) : ($v1));
            $s2 = (($v2 =~ /^([^a-z0-9]+)/) ? ($1) : ($v2));

            if ($s1 ne $s2) {
                return ($s1 cmp $s2);
            }
        }
        if ($s1) {
            $v1 =~ s/^$s1//;
        }
        if ($s2) {
            $v2 =~ s/^$s2//;
        }
    }

    # We've reached the end of one of the strings.
    if ($v1 && length($v1)) {
        return 1;
    } elsif ($v2 && length($v2)) {
        return -1;
    }
    return 0;
}

sub
rpm_get_installed()
{
    my ($err, @output) = &rpm_query("a");

    if ($err) {
        eprint "Unable to list installed packages -- $! (error $err)\n";
        return undef;
    }

    for (my $i = 0; $i < scalar(@output); $i++) {
        chomp($output[$i]);
        if ($output[$i] && ($output[$i] =~ /^([^\0\`\;]+)$/)) {
            $output[$i] = $1;
        } else {
            splice(@output, $i, 1);
        }
    }
    return @output;
}

# Scan one or more directories for RPM files.
sub
rpm_scan_files(@)
{
    my @dirs = @_;
    my $scan;

    foreach my $dir (@dirs) {
        my @rpm_files;

        dprint "Scanning $dir for RPM files.\n";
        if (-d $dir) {
            @rpm_files = &grepdir(sub { /\.(?:\w+)\.rpm$/ }, $dir);
        } elsif ($dir =~ m!^(ht|f)tps?://!) {
            my $contents;

            dprint "Detected URL:  $dir\n";
            if (substr($dir, -1, 1) ne '/') {
                $dir .= '/';
            }
            $contents = &fetch_url($dir, "mem", "Accept" => "text/html", ":no_progress" => 1);
            if ($contents) {
                #dprint "Got listing:  +++$contents+++\n\n";
                if ($contents =~ /<\s*title/i) {
                    # HTML-based listing
                    while ($contents =~ m/<\s*a\s+[^>]*href=[\"\']?([^\"\'>]+\.rpm)/ig) {
                        my $file = $1;

                        # Decode %xx escapes before storing filename.
                        $file =~ s/\%([[:xdigit:]]{2})/chr(hex($1))/eg;
                        dprint "Matched file:  $file\n";
                        push @rpm_files, $dir . &basename($file);
                    }
                } elsif ($contents =~ /^.[-rwx]{3,9}\s+/) {
                    # FTP directory listing; try to parse.  FIXME:  Doesn't work?
                    foreach my $file (map { join(':', @_) } &parse_dir($contents)) {
                        dprint "Matched file:  $file\n";
                        push @rpm_files, $dir . &basename($file);
                    }
                } else {
                    eprint "Unable to parse directory listing returned for $dir.\n";
                    dprint "{{{\n$contents\n}}}\n\n";
                    next;
                }
            } else {
                eprint "Unable to get directory listing for $dir.\n";
                next;
            }
        }
        foreach my $file (sort(@rpm_files)) {  # Sort only for debugging.
            my %pkg;

            # Resultant hash by directory, then file.
            dprint "Looking at $file.\n";
            $pkg{"PATH"} = $file;
            $pkg{"ORIGIN"} = &dirname($file);
            @pkg{("NAME", "VERSION", "RELEASE", "ARCH")} = &parse_rpm_name($file);
            dprint "$pkg{ORIGIN}:  $pkg{NAME}:$pkg{VERSION}-$pkg{RELEASE}.$pkg{ARCH}\n";
            $scan->{$dir}{$file} = \%pkg;
        }
    }
    return $scan;
}

# Compare 2 RPM's
sub
rpm_cmp($$)
{
    my ($a, $b) = @_;
    my ($name_a, $name_b, $version_a, $version_b, $release_a, $release_b, $ret);

    #dprint &examine_object(\$a), "\n---\n", &examine_object(\$b), "\n---\n";
    if (ref($a) && defined($a->{"VERSION"})) {
        $name_a = $a->{"NAME"};
        $version_a = $a->{"VERSION"};
        $release_a = $a->{"RELEASE"};
    } elsif (scalar(@tmp = &parse_rpm_name($a)) == 4) {
        $name_a = $tmp[0];
        $version_a = $tmp[1];
        $release_a = $tmp[2];
    } else {
        $name_a = $a || "";
        $version_a = 0;
        $release_a = 0;
    }
    if (ref($b) && defined($b->{"VERSION"})) {
        $name_b = $b->{"NAME"};
        $version_b = $b->{"VERSION"};
        $release_b = $b->{"RELEASE"};
    } elsif (scalar(@tmp = &parse_rpm_name($b)) == 4) {
        $name_b = $tmp[0];
        $version_b = $tmp[1];
        $release_b = $tmp[2];
    } else {
        $name_b = $b || "";
        $version_b = 0;
        $release_b = 0;
    }

    $ret = $name_a cmp $name_b;
    if (! $ret) {
        $ret = &rpm_compare_versions($version_a, $version_b);
    }
    if (! $ret) {
        $ret = &rpm_compare_versions($release_a, $release_b);
    }
    return $ret;
}

# Sort RPM's in version order
sub
rpm_sort(@)
{
    my @rpm_list = @_;
    my @tmp;

    return sort rpm_cmp @rpm_list;
}

### Private functions

# Add a %define
sub
add_define($$)
{
    my ($var, $value) = @_;

    $specdata->{"DEFINES"}{$var} = $value;
    #dprint "Added \%define:  $var -> $specdata->{DEFINES}{$var}\n";
}

# Replace %define's in a spec file line with their values
sub
replace_defines($)
{
    my $line = $_[0];

    while ($line =~ /\%(\w+)/g) {
        my $var = $1;

        #dprint "Found macro:  $var\n";
        if (defined $specdata->{"DEFINES"}{$var}) {
            #dprint "Replacing with:  $specdata->{DEFINES}{$var}\n";
            $line =~ s/\%\Q$var\E/$specdata->{"DEFINES"}{$var}/g;
            #reset;
        } else {
            #dprint "Definition not found.\n";
        }
    }
    while ($line =~ /\%\{([^\}]+)\}/g) {
        my $var = $1;

        # GMK: Added this to escape the perils of nested defines like the following example:
        # '%{expand: %%define __share %(if [ -d %{__prefix}/share/man ]; then echo /share ; else echo %%{nil} ; fi)}'
        # Yes,... this is real, and it came from: rpm-4.2.2-0.14.src.rpm. I hope there is a more
        # elegant way to fix this, but I will leave that to mej.
        $var =~ s/[\[,\],\(,\)]//g;

        #dprint "Found macro:  $var\n";
        if (defined $specdata->{"DEFINES"}{$var}) {
            #dprint "Replacing with:  $specdata->{DEFINES}{$var}\n";
            $line =~ s/\%\{\Q$var\E\}/$specdata->{"DEFINES"}{$var}/eg;
            #reset;
        } else {
            #dprint "Definition not found.\n";
            $line =~ s/\%\{\Q$var\E\}//g;
        }
    }
    return $line;
}

# Parse out a dependencies statement into packages
sub
parse_deps($)
{
    my $deps = $_[0];
    my @pkgs;
    my @tmp;

    dprint "Dependency string:  $deps\n";
    $deps =~ s/,/ /g;
    $deps =~ s/\s*[<>=]+\s*\S+\s*/ /g;
    @tmp = split(/\s+/, $deps);
    foreach my $pkg (@tmp) {
        my @not_deps = ("or");

        if ($pkg =~ /perl\(([^\)]+)\)/) {
            my $module = $1;

            $module =~ s/::/-/g;
            $pkg = "perl-$module";
        }
        if (!scalar(grep { $_ eq $pkg } @not_deps)) {
            push @pkgs, $pkg;
        }
    }
    dprint "Dep packages:  ", join('|', @pkgs), "\n";
    return @pkgs;
}

1;
