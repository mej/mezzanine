# Mezzanine CVS SCM Perl Module
# 
# Copyright (C) 2004-2007, Michael Jennings
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
# $Id: CVS.pm,v 1.20 2010/03/02 19:58:54 mej Exp $
#

package Mezzanine::SCM::CVS;
use Exporter;
use POSIX;
use File::Find;
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
                      "type" => "CVS",
                      "command" => "cvs",
                      "repository" => "",
                      "operation" => "",
                      "private" => {
                                    "files" => [ '' ],
                                    "dirs" => [ '^CVS$' ]
                                   },

                      # Options
                      "local_mode" => 0,
                      "recursion" => 1,
                      "file_type" => "auto",
                      "keyword_expansion" => "auto",
                      "update_changelog" => 1,
                      "changelog_message" => "",
                      "args_only" => 0,
                      "use_standard_ignore" => 1,
                      "prune_tree" => 1,
                      "reset" => 0,
                      "handle_output" => 1,

                      # Branching/tagging
                      "source_branch" => "",
                      "target_branch" => "",
                      "source_revision" => "",
                      "target_revision" => "",
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

    if (($path eq "Mezzanine::SCM") || ($path eq $class)) {
        $path = ".";
    }
    if (! $path) {
        dprint "$path is false.\n";
        return MZSCM_CANNOT_HANDLE;
    } elsif ($path =~ /^(:pserver:|:ext:)?(\w+)\@([^:]+)(:\d+)?:(\/.*)$/i) {
        dprint "$path is a CVS repository ($1|$2|$3|$4|$5).\n";
        return MZSCM_CAN_HANDLE;
    } elsif ($path =~ m!^cvs(pserver|ssh)://!i) {
        dprint "$path is a CVS repository URL.\n";
        return MZSCM_CAN_HANDLE;
    } elsif (! -d $path) {
        my $tmp = &dirname($path);

        dprint "$path is not a directory.\n";
        if ($tmp && ($tmp ne $path)) {
            return can_handle($proto, $tmp);
        }
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
scmobj_propget($)
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
    dprintf("Returning \"%s\".\n", join(", ", @values));
    if (wantarray()) {
        return @values;
    } else {
        return $values[0];
    }
}

sub
scmobj_propset($$)
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
    my @params = ("login");
    local *CVSPASS;

    dprint &print_args(@_);
    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not logging in.\n";
        return 1;
    }

    $repository = $self->{"repository"};
    if (! $repository || ($repository !~ /^:pserver:/)) {
        dprint "Login not required -- non-pserver repository.\n";
        return 1;
    }

    $repository =~ s!:\d+/!:/!;
    if (open(CVSPASS, "$ENV{HOME}/.cvspass")) {
        $found = 0;
        while (<CVSPASS>) {
            chomp($line = $_);
            $line =~ s!:\d+/!:/!;
            if ($line =~ /$repository/) {
                $found = 1;
                last;
            }
        }
        close(CVSPASS);
        if ($found) {
            dprint "Login not required -- correct login found.\n";
            return 1;
        }
    }
    if (-t STDIN) {
        $err = $self->talk_to_server("login", @params);
        if ($err) {
            return 0;
        }
    } else {
        dprint "Performing automated login with an empty password.\n";
        open(CVSPASS, ">> $ENV{HOME}/.cvspass");
        print CVSPASS "/1 $repository A\n";
        close(CVSPASS);
    }
    return 1;
}

sub
parse_repository_path($)
{
    my ($self, $repository) = @_;
    my ($proto, $user, $pass, $host, $port, $path);

    dprint &print_args(@_);

    if (! $repository) {
        $repository = $self->{"repository"};
    }
    if ($repository =~ /^(:pserver:|:ext:)?(\w+)\@([^:]+):(\d+)?(\/.*)$/i) {
        ($proto, $user, $pass, $host, $port, $path) = ($1 || "", $2, undef, $3, $4 || "", $5);
        $proto =~ s/^:(.*):$/$1/;
        $port =~ s/^://;
    } elsif ($repository =~ m!^cvs(pserver|ssh)://([^:]+)(:[^:]+)?\@([^:/]+)(:\d+)?(/.*)$!i) {
        ($proto, $user, $pass, $host, $port, $path) = ($1, $2, $3 || "", $4, $5 || "", $6);
        $proto =~ s/^ssh$/ext/;
        $pass =~ s/^://;
        $port =~ s/^://;
    } else {
        return undef;
    }
    return ($proto, $user, $pass, $host, $port, $path);
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
                              (($port) ? ("$port") : ("")),
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
        dprint "Found CVS/Root in '$path'.\n";
        $self->scmobj_propset("repository", $tmp);
    } elsif ($ENV{"MEZZANINE_CVSROOT"}) {
        dprint "Using environment variable \$MEZZANINE_CVSROOT.\n";
        $self->scmobj_propset("repository", $ENV{"MEZZANINE_CVSROOT"});
    } elsif ($ENV{"CVSROOT"}) {
        dprint "Using environment variable \$CVSROOT.\n";
        $self->scmobj_propset("repository", $ENV{"CVSROOT"});
    } else {
        dprint "Using fallback of /cvs\n";
        $self->scmobj_propset("repository", "/cvs");
    }
    dprintf("Auto-detected repository as:  %s\n", $self->scmobj_propget("repository"));
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
    $save_repo = $self->scmobj_propget("repository");
    $self->detect_repository($path);
    if ($save_repo && ($save_repo ne $self->scmobj_propget("repository"))) {
        # We can't use the current directory for CVS info because the repository
        # we were asked to use and the repository used by the directory we're in
        # do not match.  Just return what we were given and hope for the best.
        $self->scmobj_propset("repository", $save_repo);
        dprintf("The current directory is unusable for repository information.  Using path %s\n",
                ((defined($path)) ? ($path) : ("<undef>")));
        return $path;
    }

    if ($path && -e "$path/CVS/Repository") {
        $rel_dir = &cat_file("$path/CVS/Repository");
        dprint "Got relative path $rel_dir from $path/CVS/Repository.\n";
    } elsif (-e "CVS/Repository") {
        $rel_dir = &cat_file("CVS/Repository");
        dprint "Got relative path $rel_dir from CVS/Repository.\n";
    } else {
        $rel_dir = "";
        dprint "Could not find relative path.\n";
    }
    chomp($rel_dir);

    if ($rel_dir) {
        if ($path && $path ne "..") {
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
    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not performing get() operation.\n";
        return MEZZANINE_SUCCESS;
    }

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
    push @params, $self->get_standard_tag_params(0);
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
    $self->parse_symlink_file(@files);
    return $err;
}

sub
put($@)
{
    my ($self, @files) = @_;
    my $entry;
    my @params = ("commit");

    dprint &print_args(@_);

    $entry = &get_changelog_entry($self->{"changelog_message"});
    if (!defined($entry)) {
        return MEZZANINE_BAD_LOG_ENTRY;
    }

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

    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not performing put() operation.\n";
        return MEZZANINE_SUCCESS;
    }
    push @params, $self->get_standard_tag_params(0);
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("put", @params, @files);
}

sub
add(@)
{
    my ($self, @files) = @_;
    my $err;
    my @params = ("add");
    my @dirs = ();

    dprint &print_args(@_);
    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not performing add() operation.\n";
        return MEZZANINE_SUCCESS;
    }

    if (!scalar(@files)) {
        return MEZZANINE_BAD_ADDITION;
    }

    # Set up our parameters.
    if ($self->{"keyword_expansion"} eq "auto") {
        push @params, $KEYWORD_EXPANSION{&get_file_type($files[0])};
    } elsif ($self->{"keyword_expansion"}) {
        push @params, $KEYWORD_EXPANSION{$self->{"keyword_expansion"}};
    } else {
        push @params, $KEYWORD_EXPANSION{"default"};
    }

    # Find all the directories so we can add them first.
    for (my $i = 0; $i < scalar(@files); $i++) {
        if (-d $files[$i]) {
            # It's a directory.  Put it in the dirs list.
            push @dirs, $files[$i];
            &find({ "no_chdir" => 1, "wanted" => sub { ($_ ne $files[$i]) && -d $_ && push @dirs, $_ } }, $files[$i]);
            splice(@files, $i, 1);
            $i--;
        }
    }

    dprintf("Adding dirs:  \"%s\"\n", join("\", \"", @dirs));
    if (scalar(@dirs)) {
        $err = $self->talk_to_server("add", @params, @dirs);
        if ($err != MEZZANINE_SUCCESS) {
            return $err;
        }
    }

    foreach my $dir (@dirs) {
        xpush @files, &grepdir(sub { -f $_ && -s _ }, $dir);
    }
    dprintf("Adding files:  \"%s\"\n", join("\", \"", @files));

    if (scalar(@files)) {
        return $self->talk_to_server("add", @params, @files);
    } else {
        return MEZZANINE_SUCCESS;
    }
}

sub
remove()
{
    my ($self, @files) = @_;
    my @params = ("remove", "-f");

    dprint &print_args(@_);
    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not performing remove() operation.\n";
        return MEZZANINE_SUCCESS;
    }

    if (!scalar(@files)) {
        return MEZZANINE_BAD_REMOVAL;
    }

    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("remove", @params, @files);
}

sub
move(@)
{
    my ($self, @flist) = @_;
    my ($target, $err, $done);
    my (@output, @add, @rm);

    $target = pop(@flist);

    if ((scalar(@flist) == 1) && (-d $flist[0])) {
        if (&copy_tree($flist[0], $target) < 1) {
            my_eprint($self, "Error moving files.\n");
            return MEZZANINE_SYSTEM_ERROR;
        }

        # Get rid of any metadata files/directories in the new copy.
        @rm = $self->find_metadata($target);
        foreach my $dir (@rm) {
            dprint "Removing metadata $dir.\n";
            &nuke_tree($dir);
        }
    } else {
        if ((scalar(@flist) > 1) && (! -d $target)) {
            # When moving multiple files, the target must be a directory.
            # It's not there, so create it for the user.
            if (&mkdirhier($target) != MEZZANINE_SUCCESS) {
                my_eprint($self, "Unable to create $target -- $!\n");
                return MEZZANINE_SYSTEM_ERROR;
            }
        }

        if (&copy_files(@flist, $target) < scalar(@flist)) {
            my_eprint($self, "Error moving files.\n");
            return MEZZANINE_SYSTEM_ERROR;
        }
    }

    if ($self->{"local_mode"}) {
        my_print($self, "Files have been moved, but no contact was made with the respository.  Run \"mzsync\" when ready.\n");
        return MEZZANINE_SUCCESS;
    }

    @rm = @flist;
    if (-d $target) {
        if ((scalar(@rm) == 1) && (-d $rm[0])) {
            push @add, $target;
        } else {
            $target .= '/' if ($target !~ /\/$/);
            foreach my $f (@flist) {
                push @add, $target . &basename($f);
            }
        }
    } else {
        push @add, $target;
    }

    $err = $self->remove(@rm);
    if ($err != MEZZANINE_SUCCESS) {
        my_eprint($self, "Unable to remove files from repository.  (See above error(s).)\n");
        return $err;
    }

    $err = $self->add(@add);
    if ($err != MEZZANINE_SUCCESS && $err != MEZZANINE_DUPLICATE) {
        my_eprint($self, "Unable to add files/directories to repository.  (See above error(s).)\n");
        return $err;
    }

    my_print($self, "Removed files:  " . join(" ", @rm) . "\n");
    my_print($self, "Added files:  " . join(" ", @add) . "\n");
    my_print($self, "Move complete.  Your changes will not be finalized until you 'mzput' them.\n");
    return MEZZANINE_SUCCESS;
}

# Sync SCM state with your current working copy.
sub
sync(@)
{
    my ($self, $dir) = @_;
    my ($err, $done, $savecwd, $handle_output, $saved_output);
    my (@output, @new, @old, @add, @rm);

    $savecwd = &getcwd();
    if ($dir && !chdir($dir)) {
        my_eprint($self, "Unable to chdir to $dir -- $!\n");
        return MEZZANINE_SYSTEM_ERROR;
    }

    # Save previous values, then redirect output to @output.
    $handle_output = $self->scmobj_propget("handle_output");
    $saved_output = $self->scmobj_propget("saved_output");
    $self->scmobj_propset("handle_output", 0);
    $self->scmobj_propset("saved_output", \@output);
    $err = $self->get();
    if ($err != MEZZANINE_SUCCESS) {
        $self->scmobj_propset("handle_output", $handle_output);
        $self->scmobj_propset("saved_output", $saved_output);
        my_print($self, @output);
        my_eprint($self, "Unable to sync repository to working copy in $dir.  (See above error(s).)\n");
        return $err;
    }
    foreach my $a (grep(/^\?\s/, @output)) {
        chomp($a);
        $a =~ s/^\?\s+//;
        if (($a ne "build.mezz") && ($a ne "work") && ($a ne "work+patched")
            && ($a !~ /\.rpm$/) && ($a !~ /\.deb$/)) {
            push @add, $a;
        }
    }
    push @new, @add;
    foreach my $r (grep(/^U\s/, @output)) {
        chomp($r);
        $r =~ s/^U\s+//;
        push @rm, $r;
    }
    push @old, @rm;
    if (! $self->{"local_mode"}) {
        for (@output = (); scalar(@add); ) {
            dprint "Adding...  ", join(" ", @add), "\n";
            if ($self->add(@add) != MEZZANINE_SUCCESS) {
                my_print($self, @output);
                my_eprint($self, "Add for ", join(' ', @add), " failed.  (See above error(s).)\n");
                next;
            }
            @add = ();
            foreach my $a (grep(/^\?\s/, @output)) {
                chomp($a);
                $a =~ s/^\?\s+//;
                push @add, $a;
            }
            push @new, @add;
        }
    }
    if (scalar(@rm)) {
        dprint "Removing...  ", join(" ", @rm), "\n";
        if ($self->{"local_mode"}) {
            foreach my $path (@rm) {
                &nuke_tree($path);
            }
        } else {
            if ($self->remove(@rm) != MEZZANINE_SUCCESS) {
                my_eprint($self, "Remove for ", join(' ', @rm), " failed.  (See above error(s).)\n");
                @old = ();
            }
        }
    }

    if (!scalar(@new) && !scalar(@old)) {
        my_print($self, "No additions or removals were needed.\n");
    } else {
        if (scalar(@new)) {
            my_print($self, "Added files/directories:  ", join(" ", sort(@new)), "\n");
        }
        if (scalar(@old)) {
            my_print($self, "Removed files/directories:  ", join(" ", sort(@old)), "\n");
        }
    }
    chdir($savecwd) if ($savecwd);
    return MEZZANINE_SUCCESS;
}

sub
diff(@)
{
    my ($self, @files) = @_;
    my @params = ("diff", "-Nu");

    dprint &print_args(@_);
    push @params, $self->get_standard_tag_params(0);
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("diff", @params, @files);
}

sub
annotate(@)
{
    my ($self, @files) = @_;
    my @params = ("annotate");

    dprint &print_args(@_);

    push @params, "-f", $self->get_standard_tag_params(0);
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
    my_eprint($self, "This command is not supported by CVS.\n");
    return MEZZANINE_UNSUPPORTED;
}

sub
log(@)
{
    my ($self, @files) = @_;
    my @params = ("log");

    dprint &print_args(@_);

    if ($self->{"source_tag"}) {
        my $tag = $self->{"source_tag"};

        if ($self->{"target_tag"}) {
            $tag .= ':' . $self->{"target_tag"};
        }
        push @params, "-r", $tag;
    } elsif ($self->{"source_branch"}) {
        push @params, "-r", $self->{"source_branch"};
    } elsif ($self->{"source_revision"}) {
        my $revision = $self->{"source_revision"};

        if ($self->{"target_revision"}) {
            $revision .= ':' . $self->{"target_revision"};
        }
        push @params, "-r", $revision;
    } elsif ($self->{"source_date"}) {
        my $date = $self->{"source_date"};

        if ($self->{"target_date"}) {
            $date .= '<' . $self->{"target_date"};
        }
        push @params, "-d", $date;
    }

    if (! $self->{"recursion"}) {
        push @params, "-l";
    }
    return $self->talk_to_server("log", @params, @files);
}

sub
tag()
{
    my ($self, @files) = @_;
    my @params = ("tag");

    dprint &print_args(@_);
    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not performing tag() operation.\n";
        return MEZZANINE_SUCCESS;
    }

    push @params, (($self->{"recursion"}) ? ("-R") : ("-l")), "-F";
    if ($self->{"source_branch"}) {
        $self->{"source_branch"} =~ s/^[^a-zA-Z]+//;
        push @params, "-B", "-b", $self->{"source_branch"};
    } elsif ($self->{"source_tag"}) {
        $self->{"source_tag"} =~ s/^[^a-zA-Z]+//;
        push @params, $self->{"source_tag"};
    } else {
        return MEZZANINE_INVALID_TAG;
    }
    return $self->talk_to_server("tag", @params, @files);
}

sub
branch()
{
    my ($self, @files) = @_;
    $self->scmobj_propset("source_branch", $self->{"source_tag"});
    $self->scmobj_propset("source_tag", "");
    return $self->tag(@files);
}

sub
merge()
{
    my ($self, @files) = @_;
    my @params;

    dprint &print_args(@_);
    if ($self->{"local_mode"}) {
        dprint "Local mode active.  Not performing tag() operation.\n";
        return MEZZANINE_SUCCESS;
    }

    if (!scalar(@files)) {
        push @files, '.';
    }

    push @params, $self->get_standard_tag_params(1);
    push @params, (($self->{"recursion"}) ? ("-R") : ("-l"));
    return $self->talk_to_server("get", "update", @params, @files);
}

sub
imprt()
{
    my ($self, @files) = @_;
    my @params = ("import");
    my $err;

    dprint &print_args(@_);

    if (!scalar(@files) || !defined($files[0])) {
        @files = ( '.' );
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
            dprint "Changing directory to $module.\n";
            chdir($module);
        } elsif (-d &basename($module)) {
            dprintf("Changing directory to %s.\n", &basename($module));
            chdir(&basename($module));
        }

        if (! $vendor_tag) {
            if ($release_tag && ($release_tag =~ /^([A-Z]+)/)) {
                $vendor_tag = $1;
            } else {
                $vendor_tag = &basename((($module eq '.') ? ($cwd) : ($module)));
            }
        }
        $vendor_tag =~ tr/[a-z]/[A-Z]/;
        $vendor_tag =~ s/[^-_A-Z0-9]/_/g;
        $vendor_tag =~ s/^[^a-zA-Z]+//;
        if (! $release_tag) {
            $release_tag = $vendor_tag;
        }
        $release_tag =~ tr/[a-z]/[A-Z]/;
        $release_tag =~ s/[^-_A-Z0-9]/_/g;
        $release_tag =~ s/^[^a-zA-Z]+//;

        $self->create_symlink_file();
        #return MEZZANINE_INVALID_TAG if (! &check_tags($module));

        if ($self->{"keyword_expansion"} && ($self->{"keyword_expansion"} ne "auto")) {
            push @params, $KEYWORD_EXPANSION{$self->{"keyword_expansion"}};
        } else {
            push @params, $KEYWORD_EXPANSION{"default"};
        }
        if (! $self->{"use_standard_ignore"}) {
            push @params, '-I!';
        }
        push @params, "-m", (($self->{"changelog_message"}) ? ($self->{"changelog_message"})
                                                            : (sprintf("Import of %s", &basename($module))));
        push @params, $module, $vendor_tag, $release_tag;

        if ($self->{"local_mode"}) {
            dprint "Local mode active.  Not performing imprt() operation.\n";
            return MEZZANINE_SUCCESS;
        }

        $err = $self->talk_to_server("import", @params);
        chdir($cwd);
    }
    return $err;
}

# Find all internal SCM housekeeping files in a tree.

sub
find_metadata(@)
{
    my ($self, $dir) = @_;
    my $save_cwd;
    my @metadata;

    dprint &print_args(@_);
    File::Find::find({ "no_chdir" => 1,
                       "wanted" => sub {
                                       my $name = $File::Find::name;

                                       if (-f $name && grep(&basename($name) =~ $_, @{$self->{"private"}{"files"}})) {
                                           dprint "Found metadata file:  $name.\n";
                                           push @metadata, $name;
                                       } elsif (-d $name && grep(&basename($name) =~ $_, @{$self->{"private"}{"dirs"}})) {
                                           dprint "Found metadata dir:  $name.\n";
                                           push @metadata, $name;
                                       }
                                   }
                     }, $dir);
    return @metadata;
}


### Private functions

# Create symlink file since CVS is too stupid to handle symlinks.
sub
create_symlink_file(@)
{
    my ($self, $path) = @_;
    my $cnt;
    my %links;
    local *SYMLINKS;

    $path = '.' if (! $path);
    &find(sub {-l && ($links{$File::Find::name} = readlink($_));}, $path);
    $cnt = scalar(keys %links);
    if ($cnt) {
        dprint "Found $cnt symlinks.\n";
        if (!open(SYMLINKS, ">$path/.mezz.symlinks")) {
            my_eprint($self, "Unable to open $path/.mezz.symlinks for writing -- $!\n");
            return MEZZANINE_SYSTEM_ERROR;
        }
        foreach my $link (sort keys %links) {
            my $newlink;

            ($newlink = $link) =~ s/^\.\///;
            print SYMLINKS "$newlink -> $links{$link}\n";
            unlink($newlink);
        }
        close(SYMLINKS);
    } else {
        dprint "No symlinks found.\n";
    }
    return MEZZANINE_SUCCESS;
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
                    my_eprint($self, "Non-link file $link_from exists; can't create symlink to $link_to!\n");
                    next;
                }
            }
            if (!symlink($link_to, "$dirname/$link_from")) {
                my_eprint($self, "Unable to symlink $link_from to $link_to -- $!\n");
            }
        }
        close(SL);
    }
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

# Separate tags from revisions and dates.
sub
get_standard_tag_params()
{
    my ($self, $merge) = @_;
    my $option = "-r";
    my @params;

    if ($merge) {
        $option = "-j";
    }

    foreach my $type ("branch", "revision", "tag", "date") {
        if (uc($self->scmobj_propget("source_$type")) eq "HEAD") {
            $self->scmobj_propset("source_$type", "");
        }
        if (uc($self->scmobj_propget("target_$type")) eq "HEAD") {
            $self->scmobj_propset("target_$type", "");
        }
        if (($self->scmobj_propget("target_$type")) && !($self->scmobj_propget("source_$type"))) {
            $self->scmobj_propset(
                           "source_$type" => $self->scmobj_propget("target_$type"),
                           "target_$type" => ""
                          );
        }
    }

    if ($self->{"source_tag"}) {
        push @params, $option, $self->{"source_tag"};
        if ($self->{"target_tag"}) {
            push @params, $option, $self->{"target_tag"};
        }
    } elsif ($self->{"source_branch"}) {
        push @params, $option, $self->{"source_branch"};
        if ($self->{"target_branch"}) {
            push @params, $option, $self->{"target_branch"};
        }
    } elsif ($self->{"source_revision"}) {
        push @params, $option, $self->{"source_revision"};
        if ($self->{"target_revision"}) {
            push @params, $option, $self->{"target_revision"};
        }
    } elsif ($self->{"source_date"}) {
        push @params, "-D", $self->{"source_date"};
        if ($self->{"target_date"}) {
            push @params, "-D", $self->{"target_date"};
        }
    }
    return @params;
}

# Print or store errors.
sub
my_print
{
    my ($self, @msgs) = @_;

    #dprint &print_args(@_);
    if ($self->scmobj_propget("handle_output")) {
        print @msgs;
    } else {
        push @{$self->scmobj_propget("saved_output")}, @msgs;
    }
}

# Print or store errors.
sub
my_eprint
{
    my ($self, @msgs) = @_;

    #dprint &print_args(@_);
    if ($self->scmobj_propget("handle_output")) {
        eprint @msgs;
    } else {
        push @{$self->scmobj_propget("saved_output")}, "Error:  ", @msgs;
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
    $output = $self->scmobj_propget("handle_output");
    if (! $output) {
        my $aref;

        $aref = $self->scmobj_propget("saved_output");
        if ((! $aref) || (!ref($aref)) || (ref($aref) ne "ARRAY")) {
            $self->scmobj_propset("saved_output", []);
        }
    }

    for ($tries = 0; (($tries == 0) || ($err == -1)); $tries++) {
        my $pid;
        local *CMD;

        $err = 0;
        dprintf("Executing:  '%s'\n", join("' '", @params));
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
