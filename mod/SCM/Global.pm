# Mezzanine Global SCM Perl Module
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
# $Id: Util.pm,v 1.38 2004/06/04 17:16:40 mej Exp $
#

package Mezzanine::SCM::Global;
use Exporter;
use POSIX;
use Sys::Hostname;
use Mezzanine::Util;
use Mezzanine::Config;
use vars '$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS';

BEGIN {
    # set the version for version checking
    $VERSION     = 0.1;

    @ISA         = ('Exporter');

    @EXPORT = ('&get_file_type', '&create_changelog_timestamp',
               '&create_changelog_author', '&create_changelog_header',
               '&create_changelog_footer', '&edit_changelog_message',
               '&create_changelog_entry',
               '&create_changelog_entry_brief', '&append_changelog',
               '&get_changelog_entry', '&MZSCM_CANNOT_HANDLE',
               '&MZSCM_CAN_HANDLE', '&MZSCM_WILL_HANDLE');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

my %FILE_TYPES = (
                  '\.(gif|jpe?g|bmp|png|svg|tiff?|tga)$' => "binary",
                  '\.[ch](\+\+|xx|c)?$' => "source",
                  '\.p[lmh]$' => "source",
                  "default" => "none"
                 );

sub MZSCM_CANNOT_HANDLE()      {-1;}
sub MZSCM_CAN_HANDLE()         {1;}
sub MZSCM_WILL_HANDLE()        {0;}

sub
get_file_type($)
{
    my $file = &basename($_[0]);

    dprint &print_args(@_);
    foreach my $regex (keys(%FILE_TYPES)) {
        if ($file =~ /$regex/i) {
            dprint "$file matches $regex -> $FILE_TYPES{$regex}.\n";
            return $FILE_TYPES{$regex};
        }
    }
    dprint "No matches for $file -> $FILE_TYPES{default}.\n";
    return $FILE_TYPES{"default"};
}

sub
create_changelog_timestamp($)
{
    my $format = $_[0] || "";
    my ($config, $timestamp);

    $config = Mezzanine::Config->new("scm/config");
    if ($config->get("TIMESTAMP_FORMAT")) {
        $timestamp = strftime($config->get("TIMESTAMP_FORMAT", localtime()));
    } elsif ($format eq "dummyformat") {
        $timestamp = strftime("%Y-%m-%d", localtime());
    } else {
        # Default format
        $timestamp = scalar(localtime());
    }
    return $timestamp;
}

sub
create_changelog_author($)
{
    my $format = $_[0] || "";
    my ($config, $id, $fullname);

    $config = Mezzanine::Config->new("scm/config");

    # Find AUTHOR
    if ($config->get("AUTHOR")) {
        return $config->get("AUTHOR");
    }

    # Find ID
    if ($config->get("ID")) {
        $id = $config->get("ID");
    } elsif ($ENV{"USER"}) {
        $id = $ENV{"USER"};
    } elsif ($ENV{"LOGNAME"}) {
        $id = $ENV{"LOGNAME"};
    } elsif ($<) {
        my @tmp = getpwuid($<);

        $id = $tmp[0];
    } else {
        $id = "unknown";
    }

    # Find FULLNAME
    if ($config->get("FULLNAME")) {
        $fullname = $config->get("FULLNAME");
    } elsif ($<) {
        my @tmp = getpwuid($<);

        $tmp[6] =~ s/,.*$//;
        $fullname = $tmp[6];
    } else {
        $fullname = "";
    }

    # Merge them by style.
    if ($format eq "dummyformat") {
        my $host = hostname();

        return "$fullname  <$id\@$host>";
    } else {
        # Default format -- mejjie style.  ;-)
        if ($fullname) {
            return "$fullname ($id)";
        } else {
            return $id;
        }
    }
}

sub
create_changelog_header($$)
{
    my ($author, $format) = @_;
    my ($timestamp);

    $timestamp = &create_changelog_timestamp($format);
    if (! $author) {
        $author = &create_changelog_author($format);
    }

    if ($format eq "dummyformat") {
        return sprintf("%s  %s  %s\n\n", $timestamp, $author);
    } else {
        # Default format -- mejjie style.  ;-)
        return sprintf("%-25s%45s\n\n", $timestamp, $author);
    }
}

sub
create_changelog_footer($$$)
{
    my ($author, $format) = @_;

    if ($format eq "dummyformat") {
        return "\n";
    } else {
        # Default format -- mejjie style.  ;-)
        return "----------------------------------------------------------------------\n";
    }
}

sub
edit_changelog_message($$$)
{
    my ($message, $author, $format) = @_;
    my $banner;
    my $temp_logfile_name = &get_temp_dir() . "/.cvs.commit.$$";
    my (@stat_info_before, @stat_info_after, @contents);
    local *TMPFILE;

    $banner = "\n\n#######################################################################\n"
        . "#  Cols:  1         2         3         4         5         6         7\n"
        . "#1234567890123456789012345678901234567890123456789012345678901234567890\n"
        . "#\n"
        . "# Mezzanine -- Creating ChangeLog entry.\n"
        . "#\n"
        . "# Author:  $author\n"
        . "#\n"
        . "# Enter message above.  This banner (and below) will be removed.  Note\n"
        . "# that column 70 is the right margin; use the numbers above as a guide.\n"
        . "#######################################################################";

    if (!open(TMPFILE, ">$temp_logfile_name")) {
        return ($message, "Unable to open $temp_logfile_name -- $!");
    }
    if ($message) {
        print TMPFILE "$message";
    }
    print TMPFILE "$banner\n";
    close(TMPFILE);
    @stat_info_before = stat($temp_logfile_name);

    # Spawn editor to edit message.
    system("/bin/sh -c \"" . (($ENV{"EDITOR"}) ? ($ENV{"EDITOR"}) : ("vi")) . " $temp_logfile_name\"");

    # Abort if the logfile is no larger than before.
    @stat_info_after = stat($temp_logfile_name);
    if ($stat_info_after[7] <= $stat_info_before[7]) {
        return ($message, "Commit message was unmodified or is too short.  Aborting commit.");
    }

    if (!open(TMPFILE, $temp_logfile_name)) {
        return ($message, "Unable to read $temp_logfile_name -- $!");
    }
    @contents = <TMPFILE>;
    close(TMPFILE);
    unlink($temp_logfile_name, "$temp_logfile_name~");

    #for (my $i = 0; $i < scalar(@contents); $i++) {
    #    if ((($i == 0) && ($contents[$i] =~ /^\s*$/))
    #        || ($contents[$i] =~ /^\s*\#/)) {
    #        splice(@contents, $i, 1);
    #        $i--;
    #    }
    #}
    $message = join("", @contents);
    $message =~ s/[\n]+\#{10,}.*$//gs;
    $message =~ s/[ \t]+$//mg;
    dprint "Changelog message is:\n$message\n";
    return "$message\n";
}

sub
create_changelog_entry($$$$)
{
    my ($message, $author, $format) = @_;
    my $entry = "";

    if (! $format) {
        my $config;

        $config = Mezzanine::Config->new("scm/config");
        if ($config->get("CHANGELOG_FORMAT")) {
            $format = $config->get("CHANGELOG_FORMAT");
        }
    }
    $entry = &create_changelog_header($author, $format);
    if (! $message) {
        my @tmp;

        @tmp = &edit_changelog_message($message, $author, $format);
        $message = $tmp[0];
        if ($tmp[1]) {
            eprint "$tmp[1]\n";
            return undef;
        }
    }
    if (substr($message, -1, 1) ne "\n") {
        $message .= "\n";
    }
    $entry .= $message . &create_changelog_footer($author, $format);
    return $entry;
}

sub
create_changelog_entry_brief($$$$)
{
    my ($message, $author, $format) = @_;

    if (! $message) {
        my @tmp;

        @tmp = &edit_changelog_message($message, $author, $format);
        $message = $tmp[0];
        if ($tmp[1]) {
            eprint "$tmp[1]\n";
            return undef;
        }
    }
    return $message;
}

sub
append_changelog()
{
    my ($logfile, $message) = @_;
    local *LOGFILE;

    if (!open(LOGFILE, ">>$logfile")) {
        return "Unable to append to $logfile -- $!";
    }
    print LOGFILE $message;
    if (substr($message, -1, 1) != "\n") {
        print LOGFILE "\n";
    }
    close(LOGFILE);
    return "";
}

sub
get_changelog_entry($)
{
    my $log = shift;
    my $author;

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
    return &create_changelog_entry($log, $author, "");
}

1;
