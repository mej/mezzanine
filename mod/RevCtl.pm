# Avalon Revision Control Perl Module
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
# $Id: RevCtl.pm,v 1.2 2001/08/14 00:00:24 mej Exp $
#

package Avalon::RevCtl;

BEGIN {
    use Exporter   ();
    use Cwd;
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('&set_revctl_system', '&set_repository', '&set_keyword_expansion', '&set_recursion', '&set_branching', '&set_sticky_clear', '&set_exclusive', '&set_strict_tagging', '&set_tag', '&set_rtag', '&check_tag', '&login_to_master', 'do_changelog_entry', '&make_repository_path', '&commit_to_master', '&update_from_master', '&add_new_files', '&delete_old_files', '&query_tags', '&query_status', '&query_logs', '&query_annotation', '&query_diff', '&query_release_diff', '&tag_local_sources', '&tag_repository_sources', '&import_vendor_sources');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

# Constants

### Initialize private global variables
$revctl_system = "cvs";
$repository = "";
$keyword = "-ko";
$recurse = "";
$branch = "";
$reset = "";
$exclusive = "";
$strict = 0;
$tag = "";
$rtag = "";

### Function prototypes
sub set_revctl_system($);
sub set_repository($);
sub set_keyword_expansion($);
sub set_recursion($);
sub set_branching($);
sub set_sticky_clear($);
sub set_exclusive($);
sub set_strict_tagging($);
sub set_tag($);
sub set_rtag($);
sub check_tag($$$);
sub make_repository_path($$$$);
sub login_to_master();
sub do_changelog_entry();
sub commit_to_master(@);
sub update_from_master(@);
sub add_new_files(@);
sub delete_old_files(@);
sub query_tags(@);
sub query_status(@);
sub query_logs(@);
sub query_annotation(@);
sub query_diff(@);
sub query_release_diff(@);
sub tag_local_sources(@);
sub tag_repository_sources(@);
sub import_vendor_sources($);

# Private functions
sub talk_to_server($$);
sub talk_to_cvs_server($$);
sub talk_to_bk_server($$);

### Module cleanup
END {
}

### Function definitions

### These functions set the private globals used by this module.
sub
set_revctl_system
{
    my $param = $_[0];

    if (defined($param)) {
        if ($param eq "cvs") {
            $revctl_system = "cvs";
            $repository = "";
            $keyword = "-ko";
            $recurse = "";
            $branch = "";
            $reset = "";
            $exclusive = "";
            $tag = "";
            $rtag = "";
        } elsif ($param eq "bk") {
            $revctl_system = "bk";
            $repository = "";
            $keyword = "";
            $recurse = "";
            $branch = "";
            $reset = "";
            $exclusive = "";
            $tag = "";
            $rtag = "";
        } else {
            eprint "Unknown revision control system:  $param\n";
        }
    }
    return $revctl_system;
}

sub
set_repository
{
    my $param = $_[0];

    if (defined($param)) {
        $repository = ($param ? "-d $param" : "");
    }
    return $repository;
}

sub
set_keyword_expansion
{
    my $param = $_[0];

    if (defined($param)) {
        $keyword = ($param ? "-k$param" : "-ko");
    }
    return $keyword;
}

sub
set_recursion
{
    my $param = $_[0];

    if (defined($param)) {
        $recurse = ($param ? "-R" : "");
    }
    return $recurse;
}

sub
set_branching
{
    my $param = $_[0];

    if (defined($param)) {
        $branch = ($param ? "-b" : "");
    }
    return $branch;
}

sub
set_sticky_clear
{
    my $param = $_[0];

    if (defined($param)) {
        $reset = ($param ? "-A" : "");
    }
    return $reset;
}

sub
set_exclusive
{
    my $param = $_[0];

    if (defined($param)) {
        $exclusive = ($param ? '-I!' : "");
    }
    return $exclusive;
}

sub
set_strict_tagging
{
    my $param = $_[0];

    if (defined($param)) {
        $strict = ($param ? 1 : 0);
    }
    return $strict;
}

sub
set_tag
{
    my $param = $_[0];

    if (defined($param)) {
        $tag = ($param ? "-r $param" : "");
    }
    return $tag;
}

sub
set_rtag
{
    my $param = $_[0];

    if (defined($param)) {
        $rtag = ($param ? "-r $param" : "");
    }
    return $rtag;
}

# Check tags for validity
sub
check_tags
{
    my $module = $_[0];

    # The regexp's below enforce the following tag rules:
    #   1. Branch tags must begin with a branch key, hypen, the package name, hyphen, e.g. VA-KERNEL-
    #   2. Non-branch tags are the same, but without the branch key at the beginning, e.g. KERNEL-
    #   3. Tags must contain only uppercase characters, underscores, and hyphens.  Note that this
    #      rule is more restrictive than CVS's own rules but is enforced for standards compliance.
    #   4. Product tags are only subject to rule #3.

    dprint &print_args(@_);

    foreach my $t ($tag, $rtag) {
        $t =~ s/^-r //;
        if ($t !~ /^[-_A-Z0-9]+$/) {
            eprint "Tag $t failed character constraint check.  Tags may only contain the following:  A-Z, 0-9, -, and _.\n";
            return 0;
        }
        if ($strict) {
            $module =~ tr/[a-z]/[A-Z]/;
            if ($t !~ /^([A-Z]+-)?$module-/) {
                eprint "Tag $t failed name check.  Tags should be in the form MODULE-VERSION-RELEASE (e.g., FOO-2_0_3-1).\n";
                return 0;
            }
        }
    }
    return 1;
}

sub
make_repository_path
{
    my ($proto, $user, $host, $path) = @_;
    my $login;

    dprint &print_args(@_);

    if (! $user && ! $host && ! $path) {
        $login = $proto;
    } else {
        $login = "";
        $login .= ":$proto:" if ($proto);
        if ($user) {
            $login .= $user;
        } else {
            $login .= "anonymous";
        }
        $login .= '@' . ($host ? $host : "localhost") . ':' . ($path ? $path : "/cvs");
    }
    return $login;
}

# Login to the repository
sub
login_to_master
{
    my ($login, $cmd, $line, $err, $found);
    local *CVSPASS;

    dprint &print_args(@_);

    if (open(CVSPASS, "$ENV{HOME}/.cvspass")) {
        $found = 0;
        while (<CVSPASS>) {
            chomp($line = $_);
            if ($line =~ /^$repository/) {
                $found = 1;
                last;
            }
        }
        close(CVSPASS);
        if ($found) {
            dprint "Login not required.\n";
            return 1;
        }
    }
    if (-t STDIN) {
        $cmd = "/bin/sh -c \"cvs -d $repository login\"";
        $err = &talk_to_server("login", $cmd);
        if ($err) {
            return 0;
        }
    } else {
        dprint "Performing automated login with an empty password.\n";
        open(CVSPASS, ">> $ENV{HOME}/.cvspass");
        print CVSPASS "$repository A\n";
        close(CVSPASS);
    }
    return 1;
}

# Compose a new entry for the ChangeLog
sub
do_changelog_entry
{
    my $log = $_[0];
    my ($pwd, $username, $fullname, $line, $module);
    my @stat_info;
    my $logfile = "/var/tmp/.cvs.commit.$$";
    local *LOGFILE;

    dprint &print_args(@_);

    $pwd = &basename(&getcwd());

    open(LOGFILE, ">$logfile") || die("Cannot write to $logfile -- $!\n");
    dprint("Opened log file $logfile for commit log\n");
    $username = $ENV{"LOGNAME"};
    @pw_info = getpwnam($username);
    if ($pw_info[6] =~ /,/) {
        my @gecos = split(",", $pw_info[6], -1);

        $fullname = $gecos[0];
    } else {
        $fullname = $pw_info[6];
    }
    printf LOGFILE "%-25s%45s\n\n", scalar localtime, ($fullname ? "$fullname ($username)" : "$username");
    close(LOGFILE);

    dprint "Current directory is \"$cwd\", module name is \"$module\"\n";
    print "Please edit your commit message now...\n";
    system($ENV{"EDITOR"} ? $ENV{"EDITOR"} : "vi", $logfile);

    # Abort if the logfile was not modified or is too small.
    @stat_info = stat($logfile);
    if ($stat_info[7] <= 72) {
        print "Commit message was unmodified or is too short.  Aborting commit.\n";
        return "";
    }

    return $logfile if (! $log);

    chomp($module = &cat_file("CVS/Repository"));
    if (($module ne $pwd) && (! -f "ChangeLog")) {
        # We're not in the module directory and there's no ChangeLog here.
        wprint "This commit is not being done from the top of the module, and I see no ChangeLog here.\n";
        wprint "I will proceed without writing a ChangeLog entry.  If you are in the wrong directory,\n";
        wprint "hit Ctrl-C now to abort this commit, and try again from the correct path.  If you want\n";
        wprint "me to write a ChangeLog entry for you here, abort the commit and touch ChangeLog.\n";
        sleep(10);
    } else {
        if (! -f "ChangeLog") {
            if (!open(CL, ">ChangeLog")) {
                print "WARNING:  Unable to create ChangeLog:  $!\n";
                return "";
            }
            &add_new_files("ChangeLog");
        } else {
            chmod(0644, "ChangeLog") if (! -w "ChangeLog");
            if (!open(CL, ">>ChangeLog")) {
                print "WARNING:  Unable to write to ChangeLog:  $!\n";
                return "";
            }
        }
    }
    open(LOGFILE, "<$logfile");
    while (<LOGFILE>) {
        print CL $_;
    }
    print CL "----------------------------------------------------------------------\n";
    close(CL);
    close(LOGFILE);
    return $logfile;
}

# Commit changes to the master repository
sub
commit_to_master
{
    my $logfile = shift;
    my $cmd;

    dprint &print_args(@_);

    $cmd = "/bin/sh -c \"cvs $repository commit $tag -F $logfile " . join(' ', @_) . "\"";
    return &talk_to_server("put", $cmd);
}

# Update from the master repository
sub
update_from_master
{
    my $file_list = join(' ', @_);
    my @file_list = split(' ', $file_list);
    my ($up, $co, $err, $cmd);
    my %cmd;

    dprint &print_args(@_);

    # Figure out which files/modules exist and update those.  Checkout the rest.
    $up = "";
    $co = "";
    foreach my $file (@file_list) {
        if (-e $file) {
            $up .= " $file";
        } else {
            $co .= " $file";
        }
    }
    $cmd{up} = "/bin/sh -c \"cvs $repository update $reset -Pd $tag $up\"" if ($up || ! $co);
    $cmd{co} = "/bin/sh -c \"cvs $repository checkout $reset $tag $co\"" if ($co);

    $err = &talk_to_server("get", $cmd{co}) if ($cmd{co});
    $err = &talk_to_server("get", $cmd{up}) if ($cmd{up} && ! $err);

    # Note:  The following exists solely because CVS is too lame to handle symlinks.
    foreach $dirname (grep(-d $_, (scalar(@file_list) ? @file_list : "."))) {
        my $linkfile = "$dirname/.avalon.symlinks";
        local *SL;

        next if (!(-f $linkfile && -s _ && open(SL, $linkfile)));
        while (<SL>) {
            my ($link_from, $link_to, $line);

            chomp($line = $_);
            next if ($line !~ / -> /);
            ($link_from, $link_to) = split(" -> ", $line);
            dprint "Creating symlink:  $link_from -> $link_to\n";
            if (!symlink($link_to, "$dirname/$link_from")) {
                eprint "Unable to symlink $link_from to $link_to -- $!\n";
            }
        }
    }
    close(SL);
    return $err;
}

# Add new files
sub
add_new_files
{
    my $cmd;

    dprint &print_args(@_);

    if (!scalar(@_)) {
        return AVALON_BAD_ADDITION;
    }
    $cmd = "/bin/sh -c \"cvs $repository add $keyword " . join(' ', @_) . "\"";
    return &talk_to_server("add", $cmd);
}

# Delete old files
sub
delete_old_files
{
    my $cmd;

    dprint &print_args(@_);

    if (!scalar(@_)) {
        return AVALON_BAD_REMOVAL;
    }
    $cmd = "/bin/sh -c \"cvs $repository remove -f $recurse " . join(' ', @_) . "\"";
    return &talk_to_server("remove", $cmd);
}

# List tags
sub
query_tags
{
    my $cmd;

    dprint &print_args(@_);

    $cmd = "/bin/sh -c \"cvs $repository status -v " . join(' ', @_) . "\"";
    return &talk_to_server("query_tags", $cmd);
}

# Query file/directory status
sub
query_status
{
    my $cmd;

    dprint &print_args(@_);

    $cmd = "/bin/sh -c \"cvs $repository status -v " . join(' ', @_) . "\"";
    return &talk_to_server("query_status", $cmd);
}

sub
query_log
{
    my $cmd;

    dprint &print_args(@_);

    $cmd = "/bin/sh -c \"cvs $repository log " . join(' ', @_) . "\"";
    return &talk_to_server("query_log", $cmd);
}

sub
query_annotation
{
    my $cmd;

    dprint &print_args(@_);

    $tag = ($tag ? "-r $tag -f" : "");
    $cmd = "/bin/sh -c \"cvs $repository annotate $tag " . join(' ', @_) . "\"";
    return &talk_to_server("query_annotation", $cmd);
}

sub
query_diff
{
    my ($cmd, $t1, $t2);

    dprint &print_args(@_);

    ($t1, $t2) = split(/\s+/, $tag);
    $tag = "-r $t1" if ($t1);
    $tag .= " -r $t2" if ($t2);
    $cmd = "/bin/sh -c \"cvs $repository diff -N -R -u $tag " . join(' ', @_) . "\"";
    return &talk_to_server("query_diff", $cmd);
}

sub
query_release_diff
{
    my ($cmd, $t1, $t2);

    dprint &print_args(@_);

    ($t1, $t2) = split(/\s+/, $tag);
    $tag = "-r $t1" if ($t1);
    $tag .= " -r $t2" if ($t2);
    $cmd = "/bin/sh -c \"cvs $repository rdiff -N -R -u $tag " . join(' ', @_) . "\"";
    return &talk_to_server("query_rdiff", $cmd);
}

# Tag the sources
sub
tag_local_sources
{
    my $cmd;

    dprint &print_args(@_);

    $cmd = "/bin/sh -c \"cvs $repository tag -F $branch $tag " . join(' ', @_) . "\"";
    return &talk_to_server("tag", $cmd);
}

# Tag the repository
sub
tag_repository_sources
{
    my $cmd;

    dprint &print_args(@_);

    $cmd = "/bin/sh -c \"cvs $repository rtag -F $branch $tag " . join(' ', @_) . "\"";
    return &talk_to_server("rtag", $cmd);
}

# Import a new set of vendor sources for a new module
sub
import_vendor_sources
{
    my $module = $_[0];

    dprint &print_args(@_);

    $module = &basename(&getcwd()) if (! $module);
    if (! $tag) {
        ($tag = $module) =~ tr/[a-z]/[A-Z]/;
    } else {
        $tag =~ s/^-r //;
    }
    $tag =~ s/[^-_A-Z0-9]/_/g;
    if (! $rtag) {
        eprint "No valid release tag was given.  I can't import without it.\n";
        return AVALON_INVALID_TAG;
    } else {
        $rtag =~ s/^-r //;
    }
    $rtag =~ s/[^-_A-Z0-9]/_/g;
    return AVALON_INVALID_TAG if (! &check_tags($module));

    $cmd = "/bin/sh -c \"cvs $repository import $keyword $exact -m 'Import of $module' $module $tag $rtag\"";
    $tag = "-r $tag";
    $rtag = "-r $rtag";
    return &talk_to_server("import", $cmd);
}

### Private functions

# This routine dispatches server requests to the appropriate
# routine based on the selected protocol (cvs or bk).
sub
talk_to_server
{
    if ($revctl_system eq "cvs") {
        return &talk_to_cvs_server(@_);
    } elsif ($revctl_system eq "bk") {
        return &talk_to_bk_server(@_);
    }
}

# This routine handles interaction with the master CVS server
sub
talk_to_cvs_server
{
    my ($type, $cmd) = @_;
    my ($err, $tries, $line);
    my (@tags, @links, @ignores, @not_found, @removed, @conflicts);

    dprint &print_args(@_);

    for ($err = 0; (($err == -1) || ($tries == 0)); $tries++) {
        $err = 0;
        if (!open(CMD, "$cmd 2>&1 |")) {
            eprint "Execution of \"$cmd\" failed -- $!";
            return AVALON_COMMAND_FAILED;
        }
        while (<CMD>) {
            chomp($line = $_);
            if ($line =~ /^cvs \w+: Diffing/) {
                dprint "$line\n";
            } elsif ($type ne "query_tags") {
                print "$line\n";
            }

            # The following routines do output checking for fatal errors,
            # non-fatal (retryable) errors, and expected command output

            # First, fatal errors
            if ($line =~ /^cvs \w+: cannot find password/) {
                eprint "You must login to the repository first.\n";
                $err = AVALON_BAD_LOGIN;
                last;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: authorization failed: server \S+ rejected access/) {
                eprint "Your userid or password was not valid\n";
                $err = AVALON_BAD_LOGIN;
                last;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: \S+ requires write access to the repository/) {
                eprint "You do not have write access to the master repository.\n";
                $err = AVALON_ACCESS_DENIED;
                last;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: no repository/) {
                eprint "There is no CVS repository here.\n";
                $err = AVALON_NO_SOURCES;
            } elsif ($line =~ /^cvs server: cannot find module .(\S+). /) {
                push @not_found, $1;
                $err = AVALON_FILE_NOT_FOUND;
            } elsif ($line =~ /^cvs server: warning: (.+) is not \(any longer\) pertinent/
                     || $line =~ /^cvs server: warning: newborn (\S+) has disappeared/) {
                push @removed, $1;
                if ($cmd =~ /$1/) {
                    # It's only an error if the removed file was specifically requested in the get
                    $err = AVALON_FILE_REMOVED;
                }
            } elsif ($line =~ /^C (.+)$/) {
                push @conflicts, $1;
                $err = AVALON_CONFLICT_FOUND;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: no such tag/
                     || $line =~ /^cvs \S+: warning: new-born \S+ has disappeared$/) {
                eprint "$opt_t is not a valid tag for this file/module\n";
                $err = AVALON_INVALID_TAG;
            } elsif ($line =~ /^cvs server: (.+) already exists/ || $line =~ /^cvs server: (.+) has already been entered/) {
                eprint "$1 already exists.  No need to add it.\n";
                $err = AVALON_DUPLICATE;
            } elsif ($line =~ /^cvs server: nothing known about/) {
                $line =~ s/^cvs server: nothing known about//;
                if ($type eq "add") {
                    eprint "You tried to add a file which does not exist locally ($line).\n";
                    $err = AVALON_BAD_ADDITION;
                } else {
                    eprint "You tried to remove a file which does not exist in the repository ($line).\n";
                    $err = AVALON_BAD_REMOVAL;
                }

            # Retryable errors
            } elsif ($line =~ /^cvs \[\w+ aborted\]: connect to \S+ failed: Connection refused/) {
                if ($tries < 10) {
                    $err = -1;
                    print "The CVS server seems to be down.  I'll wait a bit and try again.\n";
                    sleep 3;
                } else {
                    eprint "The CVS server was unreachable.\n";
                    $err = AVALON_NO_SERVER;
                    last;
                }
            } elsif ($line =~ /^Unknown host (\S+)\.$/) {
                if ($tries < 10) {
                    $err = -1;
                    print "I can't seem to resolve $1.  I'll wait a bit and try again.\n";
                    sleep 3;
                } else {
                    eprint "The CVS server name ($1) does not resolve.\n";
                    $err = AVALON_NO_SERVER;
                    last;
                }
            } elsif ($line =~ /^cvs \[\w+ aborted\]: received .* signal/) {
                if ($tries < 10) {
                    $err = -1;
                    print "The CVS server crashed.  I'll wait a bit and try again.\n";
                    sleep 3;
                } else {
                    eprint "The CVS server kept crashing.\n";
                    $err = AVALON_SERVER_CRASH;
                    last;
                }

            # Expected output
            } elsif ($line =~ /^\s*Existing Tags:\s*$/) {
                if ($type eq "query_tags") {
                    my $tmp;

                    while (($tmp = <CMD>) !~ /^\s*$/) {
                        last if ($tmp =~ /^\s*No Tags Exist\s*$/);
                        $tmp =~ s/^\s*(\S+)\s+\((\w+):\s*([\d.]+)\)$/$1 at $2 $3/;
                        push @tags, $tmp;
                    }
                    last;
                }
            } elsif ($line =~ /^I (.+)$/) {
                push @ignores, $1;
            } elsif ($line =~ /^L (.+)$/) {
                push @links, $1;
            }
        }
        close(CMD);
        dprint "\"$cmd\" returned $?\n" if ($?);
    }
    if ($err == 0 && $? != 0 && $type !~ /^query_r?diff$/) {
        eprint "An unknown error must have occured, because the command returned $?\n";
        $err = AVALON_UNSPECIFIED_ERROR;
    }
    if ($err) {
        if ($#conflicts != -1) {
            eprint "The following files had conflicts:  ", join(" ", @conflicts), "\n";
        }
        if ($#not_found != -1) {
            eprint "The following files/modules were not found in the repository:  ", join(" ", @not_found), "\n";
        }
    } else {
        if ($type eq "query_tags") {
            if ($#tags >= 0) {
                print @tags;
            } else {
                print "No tags found.\n";
            }
        }
    }
    if ($#removed != -1) {
        print "The following files/modules were removed from the repository:  ", join(" ", @removed), "\n";
    }
    if ($#links >= 0) {
        print "The following symbolic links were ignored (not imported):  ", join(" ", @links), "\n";
    }
    if ($#ignores >= 0) {
        print "The following files were ignored (not imported):  ", join(" ", @ignores), "\n";
    }
    return ($err);
}

# This routine handles interaction with the master BK server
sub
talk_to_bk_server
{
    my ($type, $cmd) = @_;

    return AVALON_UNSPECIFIED_ERROR;
}

1;
