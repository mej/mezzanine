# Mezzanine Utilities Perl Module
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
# $Id: Util.pm,v 1.24 2004/01/26 20:46:10 mej Exp $
#

package Mezzanine::Util;
use strict;
use English;

BEGIN {
    use strict;
    use Exporter   ();
    use File::Copy;
    use File::stat;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('$debug', '$progname', '$mz_uid', '$mz_gid',
               '&debug_get', '&debug_set', '&file_user',
               '&file_group', '&file_owner', '&get_timestamp',
               '&fatal_error', '&dprintf', '&dprint', '&eprintf',
               '&eprint', '&wprintf', '&wprint', '&handle_signal',
               '&handle_fatal_signal', '&handle_warning',
               '&show_backtrace', '&print_args', '&mkdirhier',
               '&nuke_tree', '&move_files', '&copy_files',
               '&copy_tree', '&basename', '&dirname', '&grepdir',
               '&limit_files', '&xpush', '&cat_file',
               '&parse_rpm_name', '&should_ignore', '&touch_file',
               '&MEZZANINE_SUCCESS', '&MEZZANINE_FATAL_ERROR',
               '&MEZZANINE_SYNTAX_ERROR', '&MEZZANINE_SYSTEM_ERROR',
               '&MEZZANINE_COMMAND_FAILED', '&MEZZANINE_DUPLICATE',
               '&MEZZANINE_FILE_NOT_FOUND',
               '&MEZZANINE_FILE_OP_FAILED',
               '&MEZZANINE_ACCESS_DENIED', '&MEZZANINE_BAD_ADDITION',
               '&MEZZANINE_BAD_LOG_ENTRY', '&MEZZANINE_BAD_LOGIN',
               '&MEZZANINE_BAD_REMOVAL', '&MEZZANINE_CONFLICT_FOUND',
               '&MEZZANINE_FILE_REMOVED', '&MEZZANINE_INVALID_TAG',
               '&MEZZANINE_NEED_UPDATE', '&MEZZANINE_NO_SERVER',
               '&MEZZANINE_NO_SOURCES', '&MEZZANINE_SERVER_CRASH',
               '&MEZZANINE_BAD_PRODUCT', '&MEZZANINE_SPAWN_FAILED',
               '&MEZZANINE_PACKAGE_FAILED',
               '&MEZZANINE_ARCH_MISMATCH', '&MEZZANINE_BAD_MODULE',
               '&MEZZANINE_BUILD_FAILURE', '&MEZZANINE_DEPENDENCIES',
               '&MEZZANINE_MISSING_FILES', '&MEZZANINE_SPEC_ERRORS',
               '&MEZZANINE_MISSING_PKGS', '&MEZZANINE_TERMINATED',
               '&MEZZANINE_CRASHED', '&MEZZANINE_UNSPECIFIED_ERROR');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
my $debug = 0;
my $progname = "Mezzanine";
my $mz_uid = $UID;
my $mz_gid = $GID;

### Initialize private global variables

### Function prototypes
sub debug_get();
sub debug_set($);
sub file_user($);
sub file_group($);
sub file_owner($$$);
sub get_timestamp();
sub fatal_error(@);
sub dprintf(@);
sub dprint(@);
sub eprintf(@);
sub eprint(@);
sub handle_signal(@);
sub handle_fatal_signal(@);
sub handle_warning(@);
sub show_backtrace();
sub print_args(@);
sub mkdirhier($$);
sub nuke_tree($);
sub move_files(@);
sub copy_files(@);
sub copy_tree($$);
sub basename($);
sub dirname($);
sub grepdir(& $);
sub xpush(\@; @);
sub limit_files(@ $);
sub cat_file($);
sub parse_rpm_name($);
sub should_ignore($);
sub touch_file($);

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

# pkgtool-related errors
sub MEZZANINE_ARCH_MISMATCH()      {61;}
sub MEZZANINE_BAD_MODULE()         {62;}
sub MEZZANINE_BUILD_FAILURE()      {63;}
sub MEZZANINE_DEPENDENCIES()       {64;}
sub MEZZANINE_MISSING_FILES()      {65;}
sub MEZZANINE_SPEC_ERRORS()        {66;}

# compstool-related errors
sub MEZZANINE_MISSING_PKGS()       {81;}

# Abnormal errors
sub MEZZANINE_TERMINATED()        {120;}
sub MEZZANINE_CRASHED()           {121;}
sub MEZZANINE_UNSPECIFIED_ERROR() {127;}

### Function definitions

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
file_user($)
{
    if (defined($_[0])) {
        $mz_uid = $_[0];
    }
    return $mz_uid;
}

sub
file_group($)
{
    if (defined($_[0])) {
        $mz_gid = $_[0];
    }
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
    print STDERR "$progname:  FATAL:  ", @_;
    exit(MEZZANINE_FATAL_ERROR);
}

# Debugging output
sub
dprintf(@)
{
    my ($f, $l, $s, $format);

    return if (! $debug);
    $format = shift;
    (undef, undef, undef, $s) = caller(1);
    if (!defined($s)) {
        $s = "MAIN";
    }
    (undef, $f, $l) = caller(0);
    $f =~ s/^.*\/([^\/]+)$/$1/;
    $s =~ s/^\w+:://g;
    $s .= "()" if ($s =~ /^\w+$/);
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
    print "[$f/$l/$s] ", @_;
}

# Print an error
sub
eprintf(@)
{
    print "$progname:  Error:  ";
    printf @_;
}
sub
eprint(@)
{
    print "$progname:  Error:  ", @_;
}

# Print a warning
sub
wprintf(@)
{
    print "$progname:  Warning:  ";
    printf @_;
}
sub
wprint(@)
{
    print "$progname:  Warning:  ", @_;
}

# Handle a terminate signal
sub
handle_signal(@)
{
    my $sig = $_[0];

    eprint "Someone sent me a SIG$sig asking me to exit, so I shall.\n";
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
show_backtrace
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
print_args
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

    if (!defined($mask)) {
        $mask = 0755;
    }
    dprint "mkdirhier($dir) called.\n";
    foreach $dir (@dirs) {
        $path .= "$dir/";
        if (! -d $path) {
            dprint "mkdirhier() creating \"$path\"\n";
            mkdir($path, $mask) || eprint("Unable to create $path -- $!\n");
            chown($mz_uid, $mz_gid, $path);
        }
    }
    if (! -d $_[0]) {
        dprint "Something went wrong in mkdirhier()!\n";
        return 0;
    } else {
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
move_files
{
    # Last arg is destination
    my $dest = pop;
    my @flist = @_;
    my $fcnt = 0;
    my $addname = 0;

    if (!scalar(@flist)) {
        dprint "Errr, no files to move?\n";
        return 0;
    }
    if (-d $dest) {
        # We'll need to add the filename to the dest each time
        $dest .= '/' if ($dest !~ /\/$/);
        $addname = 1;
    }
    dprint "Moving ", join(' ', @flist), " to $dest.\n";
    foreach my $f (@flist) {
        my ($target, $mode);

        if ($addname) {
            ($target = $f) =~ s/^(.*\/)?([^\/]+)$/$dest$2/;
        } else {
            $target = $dest;
        }

        # Save permissions of the source file.
        $mode = ((stat($f))->mode() & 0775) || 0600;

        if (!&File::Copy::move($f, $target)) {
            eprint "Unable to move $f to $target -- $!\n";
            return $fcnt;
        }

        # Set permissions on the target file appropriately.
        chown($mz_uid, $mz_gid, $target) || dprint "chown($mz_uid, $mz_gid, $target) failed -- $!\n";
        chmod($mode, $target) || dprintf("chmod(%05o, $target) failed -- $!\n", $mode);
        $fcnt++;
    }
    return $fcnt;
}

# Copy files, a la "cp"
sub
copy_files
{
    # Last arg is destination
    my $dest = pop;
    my @flist = @_;
    my $fcnt = 0;
    my $addname = 0;

    if (!scalar(@flist)) {
        dprint "Errr, no files to copy?\n";
        return 0;
    }
    if (-d $dest) {
        # We'll need to add the filename to the dest each time
        $dest .= '/' if ($dest !~ /\/$/);
        $addname = 1;
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

        if (!&File::Copy::copy($f, $target)) {
            eprint "Unable to copy $f to $target -- $!.  Copied $fcnt files.\n";
            return $fcnt;
        }

        # Set permissions on the target file appropriately.
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
    while (<FF>) {
        $contents .= $_;
    }
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
should_ignore
{
    my $fname = $_[0];

    # Ignore revision control goop
    return 1 if ($fname =~ /^(CVS|SCCS|RCS|BitKeeper)$/);
    # Ignore the revtool-generated ChangeLog
    return 1 if ($fname =~ /^[Cc]hanges?\.?[Ll]og$/);
    # Ignore dotfiles
    return 1 if ($fname =~ /^\./);
    # Ignore spec files
    return 1 if ($fname =~ /\.spec(\.in)?$/);
    # Ignore the debian/ directory
    return 1 if ($fname =~ /^debian$/ && -d $fname);

    return 0;
}

sub
touch_file
{
    my $file = $_[0];
    local *TMP;

    open(TMP, ">$file") && close(TMP);
    chown($mz_uid, $mz_gid, $file);
}

1;
