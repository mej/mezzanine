# Mezzanine Utilities Perl Module
# 
# Copyright (C) 2001-2004, Michael Jennings
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
# $Id: Util.pm,v 1.45 2004/10/04 01:19:07 mej Exp $
#

package Mezzanine::Util;
use Exporter;
use POSIX;
use English;
use Getopt::Long;
use File::Find;
use File::Copy;
use File::stat;
use vars '$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS',
    '$debug', '$PROGNAME', '$VERSION', '$mz_uid', '$mz_gid', '%OPTION';

BEGIN {
    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('$debug', '$PROGNAME', '$VERSION', '$mz_uid',
               '$mz_gid', '%OPTION', '&mezz_init', '&debug_get',
               '&debug_set', '&print_version', '&file_user',
               '&file_group', '&file_owner', '&get_timestamp',
               '&fatal_error', '&dprintf', '&dprint', '&eprintf',
               '&eprint', '&wprintf', '&wprint', '&handle_signal',
               '&handle_fatal_signal', '&install_signal_handlers',
               '&handle_warning', '&show_backtrace', '&print_args',
               '&mkdirhier', '&nuke_tree', '&move_files',
               '&copy_files', '&copy_tree', '&get_temp_dir',
               '&create_temp_space', '&clean_temp_space', '&basename',
               '&dirname', '&grepdir', '&limit_files', '&xpush',
               '&cat_file', '&parse_rpm_name', '&should_ignore',
               '&touch_file', '&newest_file', '&run_cmd',
               '&run_mz_cmd', '&MEZZANINE_SUCCESS',
               '&MEZZANINE_FATAL_ERROR', '&MEZZANINE_SYNTAX_ERROR',
               '&MEZZANINE_SYSTEM_ERROR', '&MEZZANINE_COMMAND_FAILED',
               '&MEZZANINE_DUPLICATE', '&MEZZANINE_FILE_NOT_FOUND',
               '&MEZZANINE_FILE_OP_FAILED', '&MEZZANINE_UNSUPPORTED',
               '&MEZZANINE_ACCESS_DENIED', '&MEZZANINE_BAD_ADDITION',
               '&MEZZANINE_BAD_LOG_ENTRY', '&MEZZANINE_BAD_LOGIN',
               '&MEZZANINE_BAD_REMOVAL', '&MEZZANINE_CONFLICT_FOUND',
               '&MEZZANINE_FILE_REMOVED', '&MEZZANINE_INVALID_TAG',
               '&MEZZANINE_NEED_UPDATE', '&MEZZANINE_NO_SERVER',
               '&MEZZANINE_NO_SOURCES', '&MEZZANINE_SERVER_CRASH',
               '&MEZZANINE_BAD_PRODUCT', '&MEZZANINE_SPAWN_FAILED',
               '&MEZZANINE_PACKAGE_FAILED',
               '&MEZZANINE_BUILD_UNNEEDED',
               '&MEZZANINE_ARCH_MISMATCH', '&MEZZANINE_BAD_MODULE',
               '&MEZZANINE_BUILD_FAILURE', '&MEZZANINE_DEPENDENCIES',
               '&MEZZANINE_MISSING_FILES', '&MEZZANINE_EXTRA_FILES',
               '&MEZZANINE_SPEC_ERRORS', '&MEZZANINE_MISSING_PKGS',
               '&MEZZANINE_INVALID_PACKAGE', '&MEZZANINE_TERMINATED',
               '&MEZZANINE_CRASHED', '&MEZZANINE_UNSPECIFIED_ERROR');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$debug = 0;
$PROGNAME = "Mezzanine";
$VERSION = "0.0";
$mz_uid = $UID;
($mz_gid = $GID) =~ s/\s+.*$//;
%OPTION = ();

### Initialize private global variables
my $CMD_TIMEOUT = 0;

### Function prototypes
sub mezz_init($$@);
sub debug_get();
sub debug_set($);
sub print_version($$$$);
sub file_user($);
sub file_group($);
sub file_owner($$$);
sub get_timestamp();
sub fatal_error(@);
sub dprintf(@);
sub dprint(@);
sub eprintf(@);
sub eprint(@);
sub wprintf(@);
sub wprint(@);
sub handle_signal(@);
sub handle_fatal_signal(@);
sub install_signal_handlers();
sub handle_warning(@);
sub show_backtrace();
sub print_args(@);
sub mkdirhier($$);
sub nuke_tree($);
sub move_files(@);
sub copy_files(@);
sub copy_tree($$);
sub get_temp_dir();
sub create_temp_space($$$);
sub clean_temp_space($);
sub basename($);
sub dirname($);
sub grepdir(& $);
sub xpush(\@; @);
sub limit_files(@ $);
sub cat_file($);
sub parse_rpm_name($);
sub should_ignore($);
sub touch_file($);
sub newest_file($);
sub handle_alarm_for_subcommand(@);

### Module cleanup
END {
}

### Return value constants
# No error
sub MEZZANINE_SUCCESS()             {0;}

# General errors
sub MEZZANINE_FATAL_ERROR()         {1;}
sub MEZZANINE_SYNTAX_ERROR()        {2;}
sub MEZZANINE_SYSTEM_ERROR()        {3;}
sub MEZZANINE_COMMAND_FAILED()      {4;}
sub MEZZANINE_FILE_NOT_FOUND()      {5;}
sub MEZZANINE_FILE_OP_FAILED()      {6;}
sub MEZZANINE_UNSUPPORTED()         {7;}

# revtool-related errors
sub MEZZANINE_ACCESS_DENIED()      {21;}
sub MEZZANINE_BAD_ADDITION()       {22;}
sub MEZZANINE_BAD_LOG_ENTRY()      {23;}
sub MEZZANINE_BAD_LOGIN()          {24;}
sub MEZZANINE_BAD_REMOVAL()        {25;}
sub MEZZANINE_CONFLICT_FOUND()     {26;}
sub MEZZANINE_FILE_REMOVED()       {27;}
sub MEZZANINE_INVALID_TAG()        {28;}
sub MEZZANINE_NEED_UPDATE()        {29;}
sub MEZZANINE_NO_SERVER()          {30;}
sub MEZZANINE_NO_SOURCES()         {31;}
sub MEZZANINE_SERVER_CRASH()       {32;}
sub MEZZANINE_DUPLICATE()          {33;}

# buildtool-related errors
sub MEZZANINE_BAD_PRODUCT()        {51;}
sub MEZZANINE_SPAWN_FAILED()       {52;}
sub MEZZANINE_PACKAGE_FAILED()     {53;}
sub MEZZANINE_BUILD_UNNEEDED()     {54;}

# pkgtool-related errors
sub MEZZANINE_ARCH_MISMATCH()      {61;}
sub MEZZANINE_BAD_MODULE()         {62;}
sub MEZZANINE_BUILD_FAILURE()      {63;}
sub MEZZANINE_DEPENDENCIES()       {64;}
sub MEZZANINE_MISSING_FILES()      {65;}
sub MEZZANINE_EXTRA_FILES()        {66;}
sub MEZZANINE_SPEC_ERRORS()        {67;}

# compstool-related errors
sub MEZZANINE_MISSING_PKGS()       {81;}

# srctool-related errors
sub MEZZANINE_INVALID_PACKAGE()    {100;}

# Abnormal errors
sub MEZZANINE_TERMINATED()        {120;}
sub MEZZANINE_CRASHED()           {121;}
sub MEZZANINE_UNSPECIFIED_ERROR() {127;}


### Function definitions

# Perform common startup tasks, including option parsing.
sub
mezz_init($$@)
{
    my @valid_opts;

    $PROGNAME = shift;
    $VERSION = shift;
    @valid_opts = @_;

    $ENV{"LANG"} = "C" if (! $ENV{"LANG"});
    umask 022;
    &install_signal_handlers();
    select STDERR; $| = 1;
    select STDOUT; $| = 1;

    Getopt::Long::Configure("no_getopt_compat", "bundling", "no_ignore_case");
    Getopt::Long::GetOptions(\%OPTION, @valid_opts);
    return %OPTION;
}

# Get debugging state
sub
debug_get()
{
    return $debug;
}

sub
debug_set($)
{
    $debug = $_[0];
}

sub
print_version($$$$)
{
    my ($progname, $version, $author, $rcs_info) = @_;

    $rcs_info =~ s/\$\s*Revision: (\S+) \$/$1/;
    $rcs_info =~ s/\$\s*Date: (\S+) (\S+) \$/$1 at $2/;
    $rcs_info =~ s/\$\s*Author: (\S+) \$ /$1/;
    print "\n";
    print "$progname $version by $author\n";
    print "Copyright (c) 2000-2004, $author\n";
    print "  ($rcs_info)\n";
    print "\n";
    exit MEZZANINE_SUCCESS;
}

sub
file_user($)
{
    if (defined($_[0])) {
        $mz_uid = $_[0];
    }
    dprint "UID:  $mz_uid\n";
    return $mz_uid;
}

sub
file_group($)
{
    if (defined($_[0])) {
        $mz_gid = $_[0];
    }
    dprint "GID:  $mz_gid\n";
    return $mz_gid;
}

sub
file_owner($$$)
{
    my ($user, $group, $root) = @_;
    local *PASSWD;
    local *GROUP;

    if ($user) {
        if (! $group) {
            $group = $user;
        }
        if (! $root) {
            $root = "";
        }

        open(PASSWD, "$root/etc/passwd") || return undef;
        while (<PASSWD>) {
            my $line;
            my @inp;

            chomp($line = $_);
            next if (substr($line, 0, length($user)) ne $user);
            @inp = split(':', $line);
            ($mz_uid, $mz_gid) = ($inp[2], $inp[3]);
            last;
        }
        close(PASSWD);

        open(GROUP, "$root/etc/group") || return ($mz_uid, $mz_gid);
        while (<GROUP>) {
            my $line;
            my @inp;

            chomp($line = $_);
            next if (substr($line, 0, length($group)) ne $group);
            @inp = split(':', $line);
            $mz_gid = $inp[2];
            last;
        }
        close(GROUP);
    }
    #dprint "UID:  $mz_uid     GID:  $mz_gid\n";
    return ($mz_uid, $mz_gid);
}

# Generate timestamp for debugging/log file
sub
get_timestamp()
{
    return POSIX::strftime("%A, %d %B %Y %H:%M:%S %Z", localtime);
}

# Report a fatal error
sub
fatal_error(@)
{
    print STDERR "$PROGNAME:  FATAL:  ", @_;
    exit(MEZZANINE_FATAL_ERROR);
}

# Debugging output
sub
dprintf(@)
{
    my ($f, $l, $s, $format);

    return if (! $debug);
    $format = shift;
    if (!scalar(@_)) {
        return dprint($format);
    }
    (undef, undef, undef, $s) = caller(1);
    if (!defined($s)) {
        $s = "MAIN";
    }
    (undef, $f, $l) = caller(0);
    $f =~ s/^.*\/([^\/]+)$/$1/;
    $s =~ s/^\w+:://g;
    $s .= "()" if ($s =~ /^\w+$/);
    $f = "" if (!defined($f));
    $l = "" if (!defined($l));
    $format = "" if (!defined($format));
    for (my $i = 0; $i < scalar(@_); $i++) {
        if (!defined($_[$i])) {
            wprint "Undefined value passed to dprintf() parameter $i from $f line $l.\n";
            $_[$i] = "0";
        }
    }
    printf("[$f/$l/$s] $format", @_);
}

sub
dprint(@)
{
    my ($f, $l, $s);

    return if (! $debug);
    (undef, undef, undef, $s) = caller(1);
    if (!defined($s)) {
        $s = "MAIN";
    }
    (undef, $f, $l) = caller(0);
    $f =~ s/^.*\/([^\/]+)$/$1/;
    $s =~ s/\w+:://g;
    $s .= "()" if ($s =~ /^\w+$/);
    $f = "" if (!defined($f));
    $l = "" if (!defined($l));
    $s = "" if (!defined($s));
    print "[$f/$l/$s] ", @_;
}

# Print an error
sub
eprintf(@)
{
    print "$PROGNAME:  Error:  ";
    printf @_;
}
sub
eprint(@)
{
    print "$PROGNAME:  Error:  ", @_;
}

# Print a warning
sub
wprintf(@)
{
    print "$PROGNAME:  Warning:  ";
    printf @_;
}
sub
wprint(@)
{
    print "$PROGNAME:  Warning:  ", @_;
}

# Handle a terminate signal
sub
handle_signal(@)
{
    my $sig = $_[0];

    eprint "Someone sent me a SIG$sig asking me to exit, so I shall.\n";
    if (&debug_get()) {
        &show_backtrace();
    }
    exit MEZZANINE_TERMINATED;
}

# Handle a fatal signal
sub
handle_fatal_signal(@)
{
    my $sig = $_[0];

    eprint "Caught fatal signal SIG$sig.  Cleaning up and aborting...\n";
    exit MEZZANINE_CRASHED;
}

# Install standard signal handlers.
sub
install_signal_handlers()
{
    # Signal handling
    $SIG{"__WARN__"} = \&handle_warning;
    $SIG{"HUP"} = "IGNORE";
    $SIG{"INT"} = \&handle_signal;
    $SIG{"TERM"} = \&handle_signal;
    $SIG{"QUIT"} = \&handle_fatal_signal;
    $SIG{"ILL"} = \&handle_fatal_signal;
    $SIG{"ABRT"} = \&handle_fatal_signal;
    $SIG{"FPE"} = \&handle_fatal_signal;
    $SIG{"SEGV"} = \&handle_fatal_signal;
    $SIG{"BUS"} = \&handle_fatal_signal;
    #$SIG{"TSTP"} = \&handle_fatal_signal;
    #$SIG{"TTIN"} = \&handle_fatal_signal;
    #$SIG{"TTOU"} = \&handle_fatal_signal;
}

# Handle a perl warning
sub
handle_warning(@)
{
    if ($_[0] !~ /^Name \"\S+::opt_\w+\" used only once/) {
        dprint @_;
    }
}
BEGIN {
    # Take care of this ASAP at load time....
    $SIG{__WARN__} = \&handle_warning;
}

# Print a stack trace
sub
show_backtrace()
{
    my ($file, $line, $subroutine, $i);
    my @tmp;

    print "\n\nSTACK TRACE:\n";
    print "------------\n";
    for ($i = 1; @tmp = caller($i); $i++) {
        $subroutine = $tmp[3];
        (undef, $file, $line) = caller($i - 1);
        $file =~ s/^.*\/([^\/]+)$/$1/;
        print ' ' x $i, "$subroutine() at $file:$line\n";
    }
}

# Print function arguments
sub
print_args(@)
{
    my @args;

    foreach my $arg (@_) {
        if (defined($arg)) {
            push @args, $arg;
        } else {
            push @args, "<undef>";
        }
    }
    return "Args:  \"" . join("\", \"", @args) . "\"\n";
}

# Make a directory hierarchy
sub
mkdirhier($$)
{
    my ($dir, $mask) = @_;
    my @dirs = split("/", $dir);
    my $path = "";

    if (-d $dir) {
        return 1;
    }
    if (!defined($mask)) {
        $mask = 0755;
    }
    #dprint "mkdirhier($dir) called.\n";
    foreach my $dir (@dirs) {
        $path .= "$dir/";
        if (! -d $path) {
            #dprint "Creating \"$path\"\n";
            mkdir($path, $mask) || eprint("Unable to create $path -- $!\n");
            #dprint "chown $mz_uid:$mz_gid $path\n";
            chown($mz_uid, $mz_gid, $path);
        }
    }
    if (! -d $_[0]) {
        dprint "Something went wrong in mkdirhier()!\n";
        return 0;
    } else {
        #dprint "Created $_[0] for $mz_uid:$mz_gid.\n";
        return 1;
    }
}

# Emulate rm -rf
sub
nuke_tree($)
{
    my $path = $_[0];
    my @files;
    local *DIR;

    if ((-d $path) && !(-l $path)) {
        opendir(DIR, $path) || return 0;
        @files = readdir(DIR);
        closedir(DIR);
        foreach my $f (@files) {
            if ($f ne "." && $f ne "..") {
                &nuke_tree("$path/$f");
            }
        }
        #dprint "Removing directory $path\n";
        rmdir $path || return 0;
    } else {
        #dprint "Unlinking $path\n";
        unlink($path) || return 0;
    }
    return 1;
}

# Move files, a la "mv"
sub
move_files(@)
{
    # Last arg is destination
    my $dest = pop;
    my @flist = @_;
    my $fcnt = 0;
    my $addname = 0;

    if (!scalar(@flist)) {
        return 0;
    }
    if (-d $dest) {
        # We'll need to add the filename to the dest each time
        $dest .= '/' if ($dest !~ /\/$/);
        $addname = 1;
    } elsif (! -l $dest) {
        unlink($dest);
    }
    #dprint "Moving ", join(' ', @flist), " to $dest.\n";
    foreach my $f (@flist) {
        my ($target, $mode, $statobj);

        if ($addname) {
            ($target = $f) =~ s/^(.*\/)?([^\/]+)$/$dest$2/;
        } else {
            $target = $dest;
        }

        # Save permissions of the source file.
        $statobj = stat($f);
        if ($statobj) {
            $mode = ($statobj->mode() & 0775) || 0600;
        } else {
            $mode = 0600;
        }

        if (! -l $target) {
            unlink($target);
        }
        &mkdirhier(&dirname($target));
        if (!&File::Copy::move($f, $target)) {
            eprint "Unable to move $f to $target -- $!\n";
            return $fcnt;
        }

        # Set permissions on the target file appropriately.
        #dprint "chown $mz_uid:$mz_gid $target\n";
        chown($mz_uid, $mz_gid, $target) || dprint "chown($mz_uid, $mz_gid, $target) failed -- $!\n";
        chmod($mode, $target) || dprintf("chmod(%05o, $target) failed -- $!\n", $mode);
        $fcnt++;
    }
    return $fcnt;
}

# Copy files, a la "cp"
sub
copy_files(@)
{
    # Last arg is destination
    my $dest = pop;
    my @flist = @_;
    my $fcnt = 0;
    my $addname = 0;

    if (!scalar(@flist)) {
        return 0;
    }
    if (-d $dest) {
        # We'll need to add the filename to the dest each time
        $dest .= '/' if ($dest !~ /\/$/);
        $addname = 1;
    } elsif (! -l $dest) {
        unlink($dest);
    }
    dprint "Copying ", join(' ', @flist), " to $dest.\n";
    foreach my $f (grep(-f $_, @flist)) {
        my ($target, $mode);

        if ($addname) {
            $target = $dest . &basename($f);
        } else {
            $target = $dest;
        }

        # Save permissions of the source file.
        $mode = ((stat($f))->mode() & 0775) || 0600;

        if (! -l $target) {
            unlink($target);
        }
        &mkdirhier(&dirname($target));
        if (!&File::Copy::copy($f, $target)) {
            eprint "Unable to copy $f to $target -- $!.  Copied $fcnt files.\n";
            return $fcnt;
        }

        # Set permissions on the target file appropriately.
        #dprint "chown $mz_uid:$mz_gid $target\n";
        chown($mz_uid, $mz_gid, $target) || dprint "chown($mz_uid, $mz_gid, $target) failed -- $!\n";
        chmod($mode, $target) || dprintf("chmod(%05o, $target) failed -- $!\n", $mode);
        $fcnt++;
    }
    return $fcnt;
}

# Copy an entire directory tree
sub
copy_tree($$)
{
    my ($old_path, $new_path) = @_;
    my @files;
    local *DIR;

    if (-d $new_path) {
        # The destination is a directory that already exists.
        if (substr($new_path, -1, 1) ne '/') {
            $new_path .= '/';
        }
        $new_path .= &basename($old_path);
    }

    if (-d $old_path && !(-l $old_path)) {
        my $file_stats;
        my $fcnt = 0;

        # The source is a directory.
        $file_stats = stat($old_path);

        # Create the destination directory.
        dprint "Creating target directory $new_path for $old_path.\n";
        if (! mkdir($new_path, $file_stats->mode & 07775)) {
            eprint "Unable to create directory $new_path -- $!\n";
            return 0;
        }
        chown($mz_uid, $mz_gid, $new_path);

        $fcnt += &copy_files(&grepdir(sub {! -d $_}, $old_path), $new_path);
        @files = &grepdir(sub {-d $_}, $old_path);
        foreach my $srcdir (@files) {
            my $dir = &basename($srcdir);

            next if ($dir eq "." || $dir eq "..");
            $fcnt += &copy_tree($srcdir, "$new_path/$dir");
        }
        return $fcnt;
    } else {
        # The source is a file.
        dprint "Direct copying $old_path to $new_path.\n";
        return &copy_files($old_path, $new_path);
    }
}

# Use proper TEMP directory.
sub
get_temp_dir()
{
    foreach my $var ("MEZZANINE_TMP", "MEZZANINE_TEMP", "MEZZANINE_TEMPDIR", "MEZZANINE_TMPDIR", "TEMP", "TMP", "TMPPATH") {
        if ($ENV{$var} && -d $ENV{$var} && -w _) {
            return $ENV{$var};
        }
    }
    return "/var/tmp";
}

# Create temporary working space in /var/tmp
sub
create_temp_space($$$)
{
    my ($pkg, $type, $tmpdir) = @_;
    my ($dir, $d);
    my @dirlist;

    if (! $tmpdir) {
        $tmpdir = &get_temp_dir() . sprintf("/mezzanine.temp.%s.%d.%04x",
                                            (($type) ? ($type) : ("misc")),
                                            $$, rand(32767));
    }
    if ($pkg) {
        $dir = "$tmpdir/$pkg";
    } else {
        $dir = $tmpdir;
    }
    dprint "Creating $type temp space in $dir.\n";
    &nuke_tree($dir);
    &mkdirhier($dir) || return "";
    if ($type eq "SPM") {
	@dirlist = ("S", "P", "F");
    } elsif ($type eq "dironly" || $type eq "PDR") {
	@dirlist = ();
    } elsif ($type eq "build") {
	@dirlist = ("BUILD", "SOURCES", "SRPMS", "RPMS", "SPECS");
    }
    foreach my $d (@dirlist) {
	if (!&mkdirhier("$dir/$d")) {
	    eprint "Creation of $dir/$d failed -- $!\n";
	    return "";
	}
    }
    return $dir;
}

# Clean up temp space
sub
clean_temp_space($)
{
    my $tmpdir = $_[0];

    if (! $tmpdir) {
        return;
    }
    dprint "Cleaning temp space in $tmpdir.\n";
    return &nuke_tree($tmpdir);
}

# Strip the leading path off a directory/file name
sub
basename($)
{
    my $path = $_[0];

    $path =~ s/^.*\/([^\/]+)$/$1/;
    return $path;
}

# Return the leading path of a directory/file name
sub
dirname($)
{
    my $path = $_[0];

    $path =~ s/^(.*)\/[^\/]+$/$1/;
    return $path;
}

# Grep a directory for files matching a particular expression
sub
grepdir(& $)
{
    my ($func, $dir) = @_;
    my ($i, $cnt);
    my @files;
    local *DIR;

    if ($dir) {
        opendir(DIR, $dir) || return 0;
        $dir .= '/' if (substr($dir, -1, 1) ne '/');
    } else {
        opendir(DIR, ".") || return 0;
        $dir = "";
    }
    @files = grep(&$func($_ = ($dir . $_)), readdir(DIR));
    closedir(DIR);
    return @files;
}

# Remove files in a directory which are not in the list
sub
limit_files(@ $)
{
    my $dir = pop;
    my @files = @_;
    my @contents;
    local *DIR;

    @contents = &grepdir(sub {! -d $_}, $dir);
    foreach my $f (@contents) {
        if (!grep($_ eq &basename($f), @files)) {
            dprint "Removing $f\n";
            unlink($f) || eprint "Unable to remove $f -- $!\n";
        }
    }
    return 1;
}

# Exclusive push.  Only push if the item(s) aren't already in the list
sub
xpush(\@; @)
{
    my $parray = shift;
    my @items = @_;

    foreach my $item (@items) {
        push @{$parray}, $item if (!grep($_ eq $item, @{$parray}));
    }
}

# Return the contents of a file as a string
sub
cat_file($)
{
    my $filename = $_[0];
    my $contents = "";

    open(FF, "$filename") || return undef;
    $contents = join("", <FF>);
    close(FF);
    return $contents;
}

# Parse an RPM name into its components
sub
parse_rpm_name($)
{
    my $rpm = &basename($_[0]);

    $rpm =~ m/^(\S+)-([^-]+)-([^-]+)\.([^\.]+)\.rpm$/;
    return ($1, $2, $3, $4);
}

sub
should_ignore($)
{
    my $fname = $_[0];

    # Ignore revision control goop
    return 1 if ($fname =~ /^(CVS|SCCS|RCS|BitKeeper)$/);
    # Ignore the revtool-generated ChangeLog
    return 1 if ($fname =~ /^[Cc]hanges?\.?[Ll]og$/);
    # Ignore dotfiles
    return 1 if ($fname =~ /^\./);
    # Ignore backup files
    return 1 if ($fname =~ /\~$/);
    # Ignore spec files
    return 1 if ($fname =~ /\.spec(\.in)?$/);
    # Ignore the debian/ directory
    return 1 if ($fname =~ /^debian$/ && -d $fname);

    return 0;
}

sub
touch_file($)
{
    my $file = $_[0];
    local *TMP;

    open(TMP, ">$file") && close(TMP);
    chown($mz_uid, $mz_gid, $file);
}

sub
newest_file(@)
{
    my @dirs = @_;
    my ($newest_name, $newest_time) = ("", 0);
    my $stat_info;

    dprint &print_args(@_);
    foreach my $dir (@dirs) {
        if (-d $dir) {
            find({ "wanted" => sub {
                                   #dprint "Checking $_\n";
                                   $stat_info = stat($_);
                                   #dprintf("Got mtime is %s\n", ($stat_info->mtime || "<undef>"));
                                   if (defined($stat_info->mtime) && ($stat_info->mtime > $newest_time)) {
                                       $newest_name = $_;
                                       $newest_time = $stat_info->mtime;
                                   }
                               }, "no_chdir" => 1
                 }, $dir);
        } else {
            dprint "Checking $dir\n";
            $stat_info = stat($dir);
            if ($stat_info->mtime > $newest_time) {
                $newest_name = $dir;
                $newest_time = $stat_info->mtime;
            }
        }
    }
    dprintf("\"$newest_name\" is newest with mtime of %s.\n",
            POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($newest_time)));
    return $newest_name;
}

# Generic wrapper to grab command output
sub
run_cmd($$$)
{
    my ($prog, $params, $show_output, $timeout) = @_;
    my ($err, $msg, $line, $cmd) = undef;
    my @output;
    local *CMD;

    if (!defined($timeout)) {
        # Wait 15 minutes by default.
        $timeout = 900;
    }
    if (ref($params)) {
        my $tmp = "";

        foreach my $param (@{$params}) {
            if ($param =~ /\'/) {
                $param =~ s,\',\'\"\'\"\',g;
            }
            $tmp .= "\'$param\' ";
        }
        $cmd = "$prog $tmp";
    } else {
        $cmd = "$prog $params";
    }

    dprint "About to run $cmd\n";
    if (!open(CMD, "$cmd 2>&1 |")) {
        return (-1, "Execution of \"$cmd\" failed -- $!");
    }

    # Allow only $timeout seconds between lines of output.
    if ($timeout) {
        $SIG{"ALRM"} = \&handle_alarm_for_subcommand;
        alarm($timeout);
    }

    while (<CMD>) {
        if ($CMD_TIMEOUT) {
            eprint "Command TIMED OUT after $timeout seconds.\n";
            $CMD_TIMEOUT = 0;
            $SIG{"ALRM"} = "IGNORE";
            last;
        }
        chomp($line = $_);
        push @output, $line;
        $line =~ s/^.*\r//g;
        if ($show_output) {
            print "$show_output$line\n";
        } else {
            dprint "From $prog -> $line\n";
        }
        if ($timeout) {
            alarm($timeout);
        }
    }
    close(CMD);

    # It won't hurt to always reset.
    alarm(0);
    $SIG{"ALRM"} = "IGNORE";

    $err = $? >> 8;
    dprint "\"$cmd\" returned $err\n";
    if (wantarray()) {
        return ($err, @output);
    } else {
        return $err;
    }
}

# Wrapper for Mezzanine commands specifically
sub
run_mz_cmd($$$)
{
    my ($prog, $params, $show_output) = @_;
    my ($err, $msg, $line, $cmd) = undef;
    my (@output, @tmp);

    $params = "--debug $params" if ($debug);
    @output = &run_cmd($prog, $params, $show_output);
    $err = shift @output;
    if ($err) {
        my @tmp;

        @tmp = grep(/^\w+:\s*error:\s*(\S.*)$/i, @output);
        if (scalar(@tmp)) {
            $msg = $tmp[$#tmp];
        }
    }
    if (wantarray()) {
        return ($err, ($show_output ? $msg : @output));
    } else {
        return $err;
    }
}

### Private functions

sub
handle_alarm_for_subcommand(@)
{
    $CMD_TIMEOUT = 1;
}

1;
