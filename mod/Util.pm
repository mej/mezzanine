# Avalon Utilities Perl Module
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
# $Id: Util.pm,v 1.13 2001/08/01 03:28:22 mej Exp $
#

package Avalon::Util;

BEGIN {
    use Exporter   ();
    use File::Copy;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('$debug', '$progname',

                    '&debug_get', '&debug_set',
		    '&get_timestamp', '&fatal_error', '&dprintf', '&dprint', '&eprintf', '&eprint', '&wprintf', '&wprint',
		    '&handle_signal', '&handle_fatal_signal', '&handle_warning', '&show_backtrace',
		    '&mkdirhier', '&nuke_tree', '&move_files', '&copy_files', '&basename', '&dirname', '&grepdir',
		    '&xpush',
		    '&cat_file',
                    '&parse_rpm_name', '&should_ignore', '&touch_file',

		    '&AVALON_SUCCESS', '&AVALON_FATAL_ERROR', '&AVALON_SYNTAX_ERROR', '&AVALON_SYSTEM_ERROR',
		    '&AVALON_COMMAND_FAILED', '&AVALON_DUPLICATE', '&AVALON_FILE_NOT_FOUND', '&AVALON_FILE_OP_FAILED',
		    '&AVALON_ACCESS_DENIED', '&AVALON_BAD_ADDITION', '&AVALON_BAD_LOG_ENTRY', '&AVALON_BAD_LOGIN', 
		    '&AVALON_BAD_REMOVAL', '&AVALON_CONFLICT_FOUND', '&AVALON_FILE_REMOVED', '&AVALON_INVALID_TAG', 
		    '&AVALON_NEED_UPDATE', '&AVALON_NO_SERVER', '&AVALON_NO_SOURCES', '&AVALON_SERVER_CRASH', 
		    '&AVALON_BAD_PRODUCT', '&AVALON_SPAWN_FAILED', '&AVALON_PACKAGE_FAILED', '&AVALON_ARCH_MISMATCH', 
		    '&AVALON_BAD_MODULE', '&AVALON_BUILD_FAILURE', '&AVALON_DEPENDENCIES', '&AVALON_MISSING_FILES', 
		    '&AVALON_SPEC_ERRORS', '&AVALON_MISSING_PKGS', '&AVALON_TERMINATED', '&AVALON_CRASHED', 
		    '&AVALON_UNSPECIFIED_ERROR');
    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$debug = 0;
$progname = "Avalon";

### Initialize private global variables

### Function prototypes
sub debug_get();
sub debug_set($);
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
sub mkdirhier($);
sub nuke_tree($);
sub move_files(@);
sub copy_files(@);
sub basename($);
sub dirname($);
sub grepdir(& $);
sub xpush(\@; @);
sub cat_file($);
sub parse_rpm_name($);
sub should_ignore($);
sub touch_file($);

### Module cleanup
END {
}

### Return value constants
# No error
sub AVALON_SUCCESS()             {0;}

# General errors
sub AVALON_FATAL_ERROR()         {1;}
sub AVALON_SYNTAX_ERROR()        {2;}
sub AVALON_SYSTEM_ERROR()        {3;}
sub AVALON_COMMAND_FAILED()      {4;}
sub AVALON_FILE_NOT_FOUND()      {5;}
sub AVALON_FILE_OP_FAILED()      {6;}

# revtool-related errors
sub AVALON_ACCESS_DENIED()      {21;}
sub AVALON_BAD_ADDITION()       {22;}
sub AVALON_BAD_LOG_ENTRY()      {23;}
sub AVALON_BAD_LOGIN()          {24;}
sub AVALON_BAD_REMOVAL()        {25;}
sub AVALON_CONFLICT_FOUND()     {26;}
sub AVALON_FILE_REMOVED()       {27;}
sub AVALON_INVALID_TAG()        {28;}
sub AVALON_NEED_UPDATE()        {29;}
sub AVALON_NO_SERVER()          {30;}
sub AVALON_NO_SOURCES()         {31;}
sub AVALON_SERVER_CRASH()       {32;}
sub AVALON_DUPLICATE()          {33;}

# buildtool-related errors
sub AVALON_BAD_PRODUCT()        {51;}
sub AVALON_SPAWN_FAILED()       {52;}
sub AVALON_PACKAGE_FAILED()     {53;}

# pkgtool-related errors
sub AVALON_ARCH_MISMATCH()      {61;}
sub AVALON_BAD_MODULE()         {62;}
sub AVALON_BUILD_FAILURE()      {63;}
sub AVALON_DEPENDENCIES()       {64;}
sub AVALON_MISSING_FILES()      {65;}
sub AVALON_SPEC_ERRORS()        {66;}

# compstool-related errors
sub AVALON_MISSING_PKGS()       {81;}

# Abnormal errors
sub AVALON_TERMINATED()        {120;}
sub AVALON_CRASHED()           {121;}
sub AVALON_UNSPECIFIED_ERROR() {127;}

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
    exit(AVALON_FATAL_ERROR);
}

# Debugging output
sub
dprintf(@)
{
    my ($f, $l, $s, $format);

    return if (! $debug);
    $format = shift;
    (undef, undef, undef, $s) = caller(1);
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
    exit AVALON_TERMINATED;
}

# Handle a fatal signal
sub
handle_fatal_signal(@)
{
    my $sig = $_[0];

    eprint "Caught fatal signal SIG$sig.  Cleaning up and aborting...\n";
    exit AVALON_CRASHED;
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

# Make a directory hierarchy
sub
mkdirhier($)
{
    my $dir = $_[0];
    my @dirs = split("/", $dir);
    my $path = "";

    dprint "mkdirhier($dir) called.\n";
    foreach $dir (@dirs) {
        $path .= "$dir/";
        if (! -d $path) {
            dprint "mkdirhier() creating \"$path\"\n";
            mkdir($path, 0755) || eprint("Unable to create $path -- $!\n");
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
        foreach $f (@files) {
            if ($f ne "." && $f ne "..") {
                &nuke_tree("$path/$f");
            }
        }
        dprint "Removing directory $path\n";
        rmdir $path || return 0;
    } else {
        dprint "Unlinking $path\n";
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

    if (-d $dest) {
        # We'll need to add the filename to the dest each time
        $dest .= '/' if ($dest !~ /\/$/);
        $addname = 1;
    }
    foreach my $f (@flist) {
        my $target;

        if ($addname) {
            ($target = $f) =~ s/^(.*\/)?([^\/]+)$/$dest$2/;
        } else {
            $target = $dest;
        }
        if (!&File::Copy::move($f, $target)) {
            eprint "Unable to move $f to $target -- $!\n";
            return $fcnt;
        }
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

    if (-d $dest) {
        # We'll need to add the filename to the dest each time
        $dest .= '/' if ($dest !~ /\/$/);
        $addname = 1;
    }
    foreach my $f (grep(sub {print "$_\n"; -f $_}, @flist)) {
        my $target;

        if ($addname) {
            $target = $dest . &basename($f);
        } else {
            $target = $dest;
        }
        if (!&File::Copy::copy($f, $target)) {
            eprint "Unable to copy $f to $target -- $!.  Copied $fcnt files.\n";
            return $fcnt;
        }
        $fcnt++;
    }
    dprint "Copied all $fcnt files to $dest.\n";
    return $fcnt;
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

# Exclusive push.  Only push if the item(s) aren't already in the list
sub
xpush(\@; @)
{
    my $parray = shift;
    my @items = @_;

    foreach $item (@items) {
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
    my $rpm = $_[0];

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
}

1;
