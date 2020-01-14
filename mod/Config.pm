# Mezzanine Config Perl Module
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
# $Id: Config.pm,v 1.6 2007/02/27 21:29:36 mej Exp $
#

package Mezzanine::Config;
use strict;
use Mezzanine::Util;

BEGIN {
    use Exporter ();
    use vars ('$VERSION', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS', '$UNDEF_SENTINEL');

    # set the version for version checking
    $VERSION     = 0.1;

    # Stuff that's always exported.
    @EXPORT      = ();

    # Stuff that's exported upon request.
    @EXPORT_OK   = ('$VERSION');

    %EXPORT_TAGS = ( "FIELDS" => [ @EXPORT_OK, @EXPORT ] );
}

### Private global variables

### Initialize exported package variables
$UNDEF_SENTINEL = "!!<undef>!!";

# Constants

sub
new($) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    my $config_subpath = shift;

    bless($self, $class);
    &load($self, $config_subpath);
    return $self;
}

sub
load($)
{
    my ($self, $config_subpath) = @_;
    my ($filename, $path, $line);

    $config_subpath =~ s/::/\//g;
    $filename = sprintf("%s/.mezz/%s", $ENV{"HOME"}, $config_subpath);
    if ($filename =~ m!^(/[^\`\'\"]*)$!) {
        $filename = $1;
    } else {
        return;
    }

    $path = &dirname($filename);
    if (! -d $path) {
        &mkdirhier($path);
    }

    if (substr($filename, -4, 4) eq ".cdf" && -s $filename) {
        $self->{"__FILENAME"} = $filename;
        &load_config_cdf($self);
    } elsif (-s "$filename.cdf") {
        $self->{"__FILENAME"} = "$filename.cdf";
        &load_config_cdf($self);
    } elsif (substr($filename, -4, 4) eq ".xml" && -s $filename) {
        $self->{"__FILENAME"} = $filename;
        &load_config_xml($self);
    } elsif (-s "$filename.xml") {
        $self->{"__FILENAME"} = "$filename.xml";
        &load_config_xml($self);
    } elsif (-s $filename) {
        $self->{"__FILENAME"} = $filename;
        &load_config_vars($self);
    } else {
        $self->{"__FILENAME"} = $filename;
    }
}

sub
save()
{
    my $self = shift;
    my $filename;

    $filename = $self->{"__FILENAME"};

    if (substr($filename, -4, 4) eq ".xml") {
        &save_config_xml($self);
    } elsif (substr($filename, -4, 4) eq ".cdf") {
        &save_config_cdf($self);
    } else {
        &save_config_vars($self);
    }
}

sub
save_as($)
{
    my ($self, $filename) = @_;

    $self->{"__FILENAME"} = $filename;
    return $self->save();
}

sub
keys()
{
    my $self = shift;

    return grep { substr($_, 0, 2) ne "__" } @{$self->{"__KEYS"}};
}

sub
has_key($)
{
    my $self = shift;
    my $key = shift;

    return exists($self->{$key});
}

sub
get($)
{
    my $self = shift;
    my $key = shift;

    dprintf("Config::get(%s):  %s\n", $key, ((exists($self->{$key})) ? ($self->{$key}) : ("<undef>")));
    return ((exists($self->{$key})) ? ($self->{$key}) : (undef));
}

sub
set($)
{
    my $self = shift;
    my $key = shift;

    dprintf("Config::set(%s):  %s\n", $key, ((defined($_[0])) ? ($_[0]) : ("<undef>")));
    return ($self->{$key} = $_[0]);
}

### Private functions

sub
load_config_cdf()
{
    my $self = shift;
    local *CFG;

    if (!open(CFG, $self->{"__FILENAME"})) {
        eprint "Unable to open $self->{__FILENAME} -- $!\n";
        return;
    }
    while (<CFG>) {
        my @inp;
        my $key;
        my $line;

        chomp($line = $_);
        @inp = split(':', $line);
        $key = shift @inp;
        xpush @{$self->{"__KEYS"}}, $key;
        @{$self->{$key}} = @inp;
    }
    close(CFG);
}

sub
save_config_cdf()
{
    my $self = shift;
    local *CFG;

    if (!open(CFG, ">$self->{__FILENAME}")) {
        eprint "Unable to open $self->{__FILENAME} -- $!\n";
        return;
    }
    foreach my $key (sort(grep { substr($_, 0, 2) ne "__" } keys(%{$self}))) {
        print CFG "$key:", join(':', @{$self->{$key}}), "\n";
    }
    close(CFG);
}

sub
load_config_xml()
{
    my $self = shift;
    local *CFG;

}

sub
save_config_xml()
{
    my $self = shift;
    local *CFG;

    if (!open(CFG, ">$self->{__FILENAME}")) {
        eprint "Unable to open $self->{__FILENAME} -- $!\n";
        return;
    }
    close(CFG);
}

sub
load_config_vars()
{
    my $self = shift;
    local *CFG;

    if (!open(CFG, $self->{"__FILENAME"})) {
        eprint "Unable to open $self->{__FILENAME} -- $!\n";
        return;
    }
    while (<CFG>) {
        my ($key, $value);
        my $line;

        chomp($line = $_);
        ($key, $value) = split(/\s*=\s*/, $line, 2);
        xpush @{$self->{"__KEYS"}}, $key;
        if ($value eq $UNDEF_SENTINEL) {
            $self->{$key} = undef;
        } else {
            $self->{$key} = $value;
        }

        # Create an anonymous subroutine which matches the given key
        # as an "accessor" member function to the Mezzanine::Config class.
        no strict "refs";
        *$key = sub {
            shift;
            if (@_) {
                $self->{$key} = shift;
            }
            return $self->{$key};
        };
    }
    close(CFG);
}

sub
save_config_vars()
{
    my $self = shift;
    local *CFG;

    if (!open(CFG, ">$self->{__FILENAME}")) {
        eprint "Unable to open $self->{__FILENAME} -- $!\n";
        return;
    }

    foreach my $key (sort(grep { substr($_, 0, 2) ne "__" } keys(%{$self}))) {
        printf CFG "%s = %s\n", $key, ((defined($self->{$key})) ? ($self->{$key}) : ($UNDEF_SENTINEL));
    }
    close(CFG);
}

1;
