# Mezzanine CVS SCM Perl Module
# 
# Copyright (C) 2004, Michael Jennings
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
# $Id: CVS.pm,v 1.3 2004/06/22 23:10:07 mej Exp $
#

package Mezzanine::SCM::CVS;
use Exporter;
use POSIX;
use Cwd 'abs_path';
use Mezzanine::Util;
use Mezzanine::SCM::Global;
use strict;

use vars ('$VERSION', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');
$VERSION     = 0.1;

# Stuff that's always exported.
@EXPORT      = ();

# Stuff that's exported upon request.
@EXPORT_OK   = ('$VERSION');

%EXPORT_TAGS = ( "FIELDS" => [ @EXPORT_OK, @EXPORT ] );



### Initialize exported package variables

# Constants
my %DEFAULT_VALUES = (
                      "command" => "cvs",
                      "repository" => "",
                      "operation" => "",

                      # Options
                      "recursion" => 1,
                      "file_type" => "auto",
                      "keyword_expansion" => "auto",
                      "update_changelog" => 1,
                      "args_only" => 0,
                      "use_standard_ignore" => 1,
                      "prune_tree" => 1,
                      "reset" => 0,
                      "handle_output" => 1,

                      # Branching/tagging
                      "source_branch" => "",
                      "target_branch" => "",
                      "source_tag" => "",
                      "target_tag" => "",
                      "source_date" => "",
                      "target_date" => "",

                      # Internal data
                      "saved_output" => []
                     );
my %KEYWORD_EXPANSION = (
                         "binary" => "-kb",
                         "source" => "-kkv",
                         "none" => "-ko",
                         "default" => "-ko"
                        );

sub
new($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $type = shift;
    my $self;

    %{$self} = %DEFAULT_VALUES;
    bless($self, $class);
    return $self;
}

sub
can_handle($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $path = shift;

    dprint "CVS::can_handle():  $proto $class $path\n";

    if (! $path) {
        dprint "$path is false.\n";
        return MZSCM_CANNOT_HANDLE;
    } elsif (! -d $path) {
        dprint "$path is not a directory.\n";
        return MZSCM_CANNOT_HANDLE;
    } elsif ((-d "$path/CVS") && (-f "$path/CVS/Repository") && (-f "$path/CVS/Root")) {
        dprint "$path has CVS subdirectories.\n";
        return MZSCM_CAN_HANDLE;
    } elsif (&Cwd::abs_path($path) =~ /cvs/i) {
        dprint "Absolute path contains \"cvs\".\n";
        return MZSCM_WILL_HANDLE;
    } else {
        dprint "CVS is the default, so we'll handle anything.\n";
        return MZSCM_WILL_HANDLE;
    }
    dprint "Yikes.\n";
}

sub
propget($)
{
    my ($self, @keys) = @_;
    my @values;

    dprint &print_args(@_);
    foreach my $key (@keys) {
        if (($key !~ /^\w+$/) || (!exists($self->{$key}))) {
            push @values, undef;
        } else {
            push @values, $self->{$key};
        }
    }
    dprintf("Returning %s.\n", join(", ", @values));
    if (wantarray()) {
        return @values;
    } else {
        return $values[0];
    }
}

sub
propset($$)
{
    my ($self, %pairs) = @_;
    my $final;

    dprint &print_args(@_);
    foreach my $key (keys(%pairs)) {
        if (($key !~ /^\w+$/) || (!exists($self->{$key}))) {
            $final = undef;
        } elsif (defined($pairs{$key})) {
            $final = $self->{$key} = $pairs{$key};
        }
    }
    dprintf("Returning %s.\n", ((defined($final)) ? ($final) : ("<undef>")));
    return $final;
}

sub
login()
{
    my $self = shift;
    my ($login, $cmd, $line, $err, $found, $repository);
    local *CVSPASS;

    dprint &print_args(@_);

    $repository = $self->{"repository"};
    if (! $repository || ($repository !~ /^:pserver:/)) {
        dprint "Login not required.\n";
        return 1;
    }

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
        $cmd = "/bin/sh -c \"cvs $repository login\"";
        $err = $self->talk_to_server("login", $cmd);
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

sub
compose_repository_path($$$$)
{
    my ($self, $proto, $user, $pass, $host, $port, $path) = @_;
    my $repository;

    dprint &print_args(@_);

    if (scalar(@_) == 1) {
        $repository = $proto;
    } else {
        $repository = sprintf("%s%s%s%s%s",
                              (($proto) ? (":$proto:") : ("")),
                              (($user) ? ($user) : ("anonymous")),
                              (($host) ? ("\@$host:") : ("\@localhost:")),
                              (($port) ? ($port) : ("")),
                              (($path) ? ($path) : ("/cvs")));
    }
    return $self->set("repository", $repository);
}

sub
detect_repository()
{
    my ($self, $path) = @_;

    dprint &print_args(@_);
    if (! $path) {
        $path = '.';
    }

    if (-r "$path/CVS/Root") {
        my $tmp = &cat_file("$path/CVS/Root");
        chomp($tmp);
        $self->propset("repository", $tmp);
    } elsif ($ENV{"MEZZANINE_CVSROOT"}) {
        $self->propset("repository", $ENV{"MEZZANINE_CVSROOT"});
    } elsif ($ENV{"CVSROOT"}) {
        $self->propset("repository", $ENV{"CVSROOT"});
    } else {
        $self->propset("repository", "/cvs");
    }
    dprintf("Auto-detected repository as:  %s\n", $self->propget("repository"));
}

sub
relative_path($)
{
    my ($self, $path) = @_;
    my $rel_dir;
    my $save_repo;

    # FIXME:  I'm not sure how this should work with a path given,
    #         so at present it may not work at all that way.
    dprint &print_args(@_);
    $save_repo = $self->propget("repository");
    $self->detect_repository($path);
    if ($save_repo && ($save_repo ne $self->propget("repository"))) {
        # We can't use the current directory for CVS info because the repository
        # we were asked to use and the repository used by the directory we're in
        # do not match.  Just return what we were given and hope for the best.
        $self->propset("repository", $save_repo);
        dprintf("The current directory is unusable for repository information.  Using path %s\n",
                ((defined($path)) ? ($path) : ("<undef>")));
        return $path;
    }

    if ($path) {
        $rel_dir = &cat_file("$path/CVS/Repository");
    } else {
        $rel_dir = &cat_file("CVS/Repository");
    }
    chomp($rel_dir);

    if ($rel_dir) {
        if ($path) {
            $rel_dir .= $path;
        }
    } else {
        $rel_dir = undef;
    }
    dprintf("Returning %s\n", ((defined($rel_dir)) ? ($rel_dir) : ("<undef>")));
    return $rel_dir;
}

sub
get(@)
{
    my ($self, @files) = @_;
    my @checkout;
    my @update;
    my @params;
    my $err;

    dprint &print_args(@_);

    if (!scalar(@files)) {
        push @files, '.';
    }

    # Figure out which files/modules exist and update those.  Checkout the rest.
    foreach my $file (@files) {
        if (-e $file) {
            push @update, $file;
        } else {
            push @checkout, $file;
        }
    }

    if ($self->{"reset"}) {
        push @params, "-A";
    }
    if ($self->{"source_tag"}) {
        push @params, "-r", $self->{"source_tag"};
    }
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));

    if (scalar(@checkout)) {
        $err = $self->talk_to_server("get", "checkout", @params, @files);
    }
    if (scalar(@update)) {
        push @params, "-d";
        if ($self->{"prune_tree"}) {
            push @params, "-P";
        }
        $err = $self->talk_to_server("get", "update", @params, @files);
    }

    # Note:  The following exists solely because CVS is too lame to handle symlinks.
    foreach my $dirname (grep(-d $_, @files)) {
        my $linkfile = "$dirname/.mezz.symlinks";
        local *SL;

        next if (!(-f $linkfile && -s _ && open(SL, $linkfile)));
        while (<SL>) {
            my ($link_from, $link_to, $line);

            chomp($line = $_);
            next if ($line !~ / -> /);
            ($link_from, $link_to) = split(" -> ", $line);
            dprint "Creating symlink:  $link_from -> $link_to\n";
            if (-e "$dirname/$link_from") {
                if (-l "$dirname/$link_from") {
                    unlink("$dirname/$link_from");
                } else {
                    eprint "Non-link file $link_from exists; can't create symlink to $link_to!\n";
                    next;
                }
            }
            if (!symlink($link_to, "$dirname/$link_from")) {
                eprint "Unable to symlink $link_from to $link_to -- $!\n";
            }
        }
    }
    close(SL);
    return $err;
}

sub
put($@)
{
    my ($self, $log, @files) = @_;
    my ($author, $entry);
    my @params = ("commit");

    dprint &print_args(@_);

    if ($log && -e $log) {
        local *LOGFILE;

        # If it exists on the filesystem, it's a file.  Extract message.
        if (open(LOGFILE, $log)) {
            $log = join("", <LOGFILE>);
            close(LOGFILE);
        }
    }

    $author = &create_changelog_author("");
    $entry = &create_changelog_entry($log, $author, "");
    if ($self->{"update_changelog"}) {
        my $rel_dir = &find_module_changelog();

        # The ChangeLog file, if it exists, will be in $PWD.
        &append_changelog("ChangeLog", $entry);
        if (! $rel_dir) {
            # We couldn't find the ChangeLog, so we created it.
            $self->add("ChangeLog");
        } elsif ($rel_dir ne ".") {
            if (scalar(@files)) {
                @files = &rewrite_relative_paths($rel_dir, @files);
            } else {
                push @files, $rel_dir;
            }
        }
        if (scalar(@files) && $self->{"args_only"}) {
            push @files, "ChangeLog";
        }
    }
    push @params, "-m", $entry;

    if ($self->{"source_tag"}) {
        push @params, "-r", $self->{"source_tag"};
    }
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("put", @params, @files);
}

sub
add(@)
{
    my ($self, @files) = @_;
    my @params = ("add");

    if (!scalar(@files)) {
        return MEZZANINE_BAD_ADDITION;
    }

    if ($self->{"keyword_expansion"} eq "auto") {
        push @params, $KEYWORD_EXPANSION{&get_file_type($files[0])};
    } elsif ($self->{"keyword_expansion"}) {
        push @params, $KEYWORD_EXPANSION{$self->{"keyword_expansion"}};
    } else {
        push @params, $KEYWORD_EXPANSION{"default"};
    }
    return $self->talk_to_server("add", @params, @files);
}

sub
remove()
{
    my ($self, @files) = @_;
    my @params = ("remove", "-f");

    if (!scalar(@files)) {
        return MEZZANINE_BAD_REMOVAL;
    }

    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("remove", @params, @files);
}

sub
diff(@)
{
    my ($self, @files) = @_;
    my @params = ("diff", "-NRu");

    dprint &print_args(@_);

    if ($self->{"source_tag"}) {
        # FIXME:  Need to support tags/revisions/dates
    }
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("diff", @params, @files);
}

sub
annotate(@)
{
    my ($self, @files) = @_;
    my @params = ("annotate");

    dprint &print_args(@_);

    if ($self->{"source_tag"}) {
        push @params, "-r", $self->{"source_tag"}, "-f";
    }
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("annotate", @params, @files);
}

sub
info(@)
{
    my ($self, @files) = @_;
    my @params = ("status", "-v");

    dprint &print_args(@_);
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("info", @params, @files);
}

sub
status(@)
{
    my ($self, @files) = @_;
    my @params = ("");

    dprint &print_args(@_);
    eprint "This command is not supported by CVS.\n";
    return MEZZANINE_UNSUPPORTED;
}

sub
log(@)
{
    my ($self, @files) = @_;
    my @params = ("log");

    dprint &print_args(@_);

    if ($self->{"source_tag"}) {
        # FIXME:  Need to support tags/revisions/dates
    }
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("log", @params, @files);
}

sub
tag()
{
    my ($self, @files) = @_;
    my @params = ("tag");

    dprint &print_args(@_);

    if (! $self->{"source_tag"}) {
        return MEZZANINE_INVALID_TAG;
    }
    push @params, "-F", $self->{"source_tag"}, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("tag", @params, @files);
}

sub
branch()
{
    my ($self, @files) = @_;
    return $self->tag("-b", @files);
}

sub
merge()
{

}

sub
imprt()
{
    my ($self, @files) = @_;
    my @params = ("import");
    my $err;

    dprint &print_args(@_);

    if (!scalar(@files)) {
        push @files, '.';
    }

    foreach my $module (@files) {
        my $cwd = &getcwd();
        my ($vendor_tag, $release_tag) = @{$self}{("source_tag", "target_tag")};

        dprint "Importing from $cwd:  $module\n";
        if ($module eq '.') {
            $module = $self->relative_path(&basename($cwd));
            if ((-r "CVS/Root") && ((! $self->{"repository"}) || ($self->{"repository"} eq $ENV{"CVSROOT"}))) {
                my $tmp;

                $tmp = &cat_file("CVS/Root");
                chomp($tmp);
                $self->{"repository"} = $tmp;
            }
        } elsif (-d $module) {
            chdir($module);
        }

        if (! $vendor_tag) {
            if ($release_tag && ($release_tag =~ /^([A-Z]+)/)) {
                $vendor_tag = $1;
            } else {
                $vendor_tag = &basename($cwd);
            }
        }
        $vendor_tag =~ tr/[a-z]/[A-Z]/;
        $vendor_tag =~ s/[^-_A-Z0-9]/_/g;
        if (! $release_tag) {
            $release_tag = $vendor_tag;
        }
        $release_tag =~ tr/[a-z]/[A-Z]/;
        $release_tag =~ s/[^-_A-Z0-9]/_/g;

        #return MEZZANINE_INVALID_TAG if (! &check_tags($module));

        if ($self->{"keyword_expansion"} && ($self->{"keyword_expansion"} ne "auto")) {
            push @params, $KEYWORD_EXPANSION{$self->{"keyword_expansion"}};
        } else {
            push @params, $KEYWORD_EXPANSION{"default"};
        }
        if (! $self->{"use_standard_ignore"}) {
            push @params, '-I!';
        }
        push @params, "-m", sprintf("Import of %s", &basename($module));
        push @params, $module, $vendor_tag, $release_tag;
        $err = $self->talk_to_server("import", @params);
        chdir($cwd);
    }
    return $err;
}


### Private functions

# Create symlink file since CVS is too stupid to handle symlinks.
sub
create_symlink_file(@)
{

}

# Parse the symlink file and create needed symlinks.
sub
parse_symlink_file(@)
{
    my ($self, @files) = @_;

    foreach my $dirname (grep(-d $_, @files)) {
        my $linkfile = "$dirname/.mezz.symlinks";
        local *SL;

        next if (!(-f $linkfile && -s _ && open(SL, $linkfile)));
        while (<SL>) {
            my ($link_from, $link_to, $line);

            chomp($line = $_);
            next if ($line !~ / -> /);
            ($link_from, $link_to) = split(" -> ", $line);
            dprint "Creating symlink:  $link_from -> $link_to\n";
            if (-e "$dirname/$link_from") {
                if (-l "$dirname/$link_from") {
                    unlink("$dirname/$link_from");
                } else {
                    eprint "Non-link file $link_from exists; can't create symlink to $link_to!\n";
                    next;
                }
            }
            if (!symlink($link_to, "$dirname/$link_from")) {
                eprint "Unable to symlink $link_from to $link_to -- $!\n";
            }
        }
    }
    close(SL);
}

# Figure out where the ChangeLog file is (or should be).
sub
find_module_changelog()
{
    my ($cwd, $rel_dir, $repo);

    $cwd = &getcwd();
    $rel_dir = &basename($cwd) . '/';

    for ($repo = &cat_file("CVS/Repository");
         (! -e "ChangeLog") && $repo && ($repo =~ /\//);
         $repo = &cat_file("CVS/Repository")) {
        chdir("..");
        $rel_dir = &basename(&getcwd()) . "/$rel_dir";
    }
    if (-e "ChangeLog") {
        $rel_dir =~ s!^[^/]*/!!;
        $rel_dir =~ s!/$!!;
        $rel_dir = "." if (! $rel_dir);
        return $rel_dir;
    } else {
        chdir($cwd);
        return "";
    }
}

# Rewrite arguments relative to a new directory.
sub
rewrite_relative_paths()
{
    my ($rel_dir, @args) = @_;
    my @new_args;

    if ((! $rel_dir) || ($rel_dir eq ".")) {
        return @args;
    } elsif (!scalar(@args)) {
        return $rel_dir;
    }

    foreach my $arg (@args) {
        dprint "Updating argument path:  $arg -> $rel_dir/$arg\n";
        push @new_args, "$rel_dir/$arg";
    }
    return @new_args;
}

# Print or store errors.
sub
my_print
{
    my ($self, @msgs) = @_;

    #dprint &print_args(@_);
    if ($self->propget("handle_output")) {
        print @msgs;
    } else {
        push @{$self->propget("saved_output")}, @msgs;
    }
}

# Print or store errors.
sub
my_eprint
{
    my ($self, @msgs) = @_;

    #dprint &print_args(@_);
    if ($self->propget("handle_output")) {
        eprint @msgs;
    } else {
        push @{$self->propget("saved_output")}, "Error:  ", @msgs;
    }
}

# This routine handles interaction with the master CVS server
sub
talk_to_server($@)
{
    my ($self, $type, @params) = @_;
    my ($err, $tries, $line, $cmd, $output);
    my (@tags, @links, @ignores, @not_found, @removed, @conflicts);

    dprint &print_args(@_);
    if ($self->{"repository"}) {
        unshift @params, "-d", $self->{"repository"};
    }
    unshift @params, $self->{"command"};
    $cmd = join(' ', @params);

    # Allow for preserving of output for client.
    $output = $self->propget("handle_output");
    if (! $output) {
        my $aref;

        $aref = $self->propget("saved_output");
        if ((! $aref) || (!ref($aref)) || (ref($aref) ne "ARRAY")) {
            $self->propset("saved_output", []);
        }
    }

    for ($tries = 0; (($tries == 0) || ($err == -1)); $tries++) {
        my $pid;
        local *CMD;

        $err = 0;
        $pid = open(CMD, '-|');
        if (!defined($pid)) {
            my_print($self, "Execution of \"$cmd\" failed -- $!\n");
            return MEZZANINE_COMMAND_FAILED;
        } elsif (! $pid) {
            close(STDERR);
            open(STDERR, ">&STDOUT");
            select STDOUT; $| = 1;
            exec(@params);
        }

        while (<CMD>) {
            chomp($line = $_);
            #dprint "Got line $line\n";
            if ($line =~ /^cvs \w+: Diffing/) {
                dprint "$line\n";
            } elsif ($line =~ /^cvs \w+: Updating/) {
                dprint "$line\n";
            } else {
                my_print($self, "$line\n");
            }

            # The following routines do output checking for fatal errors,
            # non-fatal (retryable) errors, and expected command output

            # First, fatal errors
            if ($line =~ /^cvs \w+: cannot find password/) {
                my_print($self, "You must login to the repository first.\n");
                $err = MEZZANINE_BAD_LOGIN;
                last;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: authorization failed: server \S+ rejected access/) {
                my_print($self, "Your userid or password was not valid\n");
                $err = MEZZANINE_BAD_LOGIN;
                last;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: \S+ requires write access to the repository/) {
                my_print($self, "You do not have write access to the master repository.\n");
                $err = MEZZANINE_ACCESS_DENIED;
                last;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: no repository/) {
                my_print($self, "There is no CVS repository here.\n");
                $err = MEZZANINE_NO_SOURCES;
            } elsif ($line =~ /^cvs server: cannot find module .(\S+). /) {
                push @not_found, $1;
                $err = MEZZANINE_FILE_NOT_FOUND;
            } elsif ($line =~ /^cvs server: warning: (.+) is not \(any longer\) pertinent/
                     || $line =~ /^cvs server: warning: newborn (\S+) has disappeared/) {
                push @removed, $1;
                if ($cmd =~ /\Q$1\E/) {
                    # It's only an error if the removed file was specifically requested in the get
                    $err = MEZZANINE_FILE_REMOVED;
                }
            } elsif ($line =~ /^C (.+)$/) {
                push @conflicts, $1;
                $err = MEZZANINE_CONFLICT_FOUND;
            } elsif ($line =~ /^cvs \[\w+ aborted\]: no such tag/
                     || $line =~ /^cvs \S+: warning: new-born \S+ has disappeared$/) {
                my_print($self, "$self->{source_tag} is not a valid tag for this file/module\n");
                $err = MEZZANINE_INVALID_TAG;
            } elsif ($line =~ /^cvs server: (.+) already exists/ || $line =~ /^cvs server: (.+) has already been entered/) {
                my_print($self, "$1 already exists.  No need to add it.\n");
                $err = MEZZANINE_DUPLICATE;
            } elsif ($line =~ /^cvs server: nothing known about/) {
                $line =~ s/^cvs server: nothing known about//;
                if ($type eq "add") {
                    my_print($self, "You tried to add a file which does not exist locally ($line).\n");
                    $err = MEZZANINE_BAD_ADDITION;
                } else {
                    my_print($self, "You tried to remove a file which does not exist in the repository ($line).\n");
                    $err = MEZZANINE_BAD_REMOVAL;
                }

            # Retryable errors
            } elsif ($line =~ /^cvs \[\w+ aborted\]: connect to \S+ failed: Connection refused/) {
                if ($tries < 10) {
                    $err = -1;
                    my_print($self, "The CVS server seems to be down.  I'll wait a bit and try again.\n");
                    sleep 3;
                } else {
                    my_print($self, "The CVS server was unreachable.\n");
                    $err = MEZZANINE_NO_SERVER;
                    last;
                }
            } elsif ($line =~ /^Unknown host (\S+)\.$/) {
                if ($tries < 10) {
                    $err = -1;
                    my_print($self, "I can't seem to resolve $1.  I'll wait a bit and try again.\n");
                    sleep 3;
                } else {
                    my_print($self, "The CVS server name ($1) does not resolve.\n");
                    $err = MEZZANINE_NO_SERVER;
                    last;
                }
            } elsif ($line =~ /^cvs \[\w+ aborted\]: received .* signal/
                     || $line =~ /^cvs \[\w+ aborted\]: end of file from server/) {
                if ($tries < 10) {
                    $err = -1;
                    my_print($self, "The CVS server crashed.  I'll wait a bit and try again.\n");
                    sleep 3;
                } else {
                    my_print($self, "The CVS server kept crashing.\n");
                    $err = MEZZANINE_SERVER_CRASH;
                    last;
                }

            # Expected output
            } elsif ($line =~ /^I (.+)$/) {
                push @ignores, $1;
            } elsif ($line =~ /^L (.+)$/) {
                push @links, $1;
            }
        }
        close(CMD);
        dprint "\"$cmd\" returned $?\n" if ($?);
    }
    if ($err == 0 && $? != 0 && $type ne "diff") {
        my_print($self, "An unknown error must have occured, because the command returned $?\n");
        $err = MEZZANINE_UNSPECIFIED_ERROR;
    }
    if ($err) {
        if ($#conflicts != -1) {
            my_print($self, "The following files had conflicts:  ", join(" ", @conflicts), "\n");
        }
        if ($#not_found != -1) {
            my_print($self, "The following files/modules were not found in the repository:  ", join(" ", @not_found), "\n");
        }
    } else {
        if ($type eq "query_tags") {
            if ($#tags >= 0) {
                my_print($self, @tags);
            } else {
                my_print($self, "No tags found.\n");
            }
        }
    }
    if ($#removed != -1) {
        my_print($self, "The following files/modules were removed from the repository:  ", join(" ", @removed), "\n");
    }
    if ($#links >= 0) {
        my_print($self, "The following symbolic links were ignored (not imported):  ", join(" ", @links), "\n");
    }
    if ($#ignores >= 0) {
        my_print($self, "The following files were ignored (not imported):  ", join(" ", @ignores), "\n");
    }
    return ($err);
}

1;
