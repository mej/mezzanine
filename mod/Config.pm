# Mezzanine Config Perl Module
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
# $Id: Config.pm,v 1.1 2004/04/01 23:25:24 mej Exp $
#

package Mezzanine::Config;
use Mezzanine::Util;

BEGIN {
    use Exporter ();
    use vars ('$VERSION', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 0.1;

    # Stuff that's always exported.
    @EXPORT      = ();

    # Stuff that's exported upon request.
    @EXPORT_OK   = ('$VERSION');

    %EXPORT_TAGS = ( "FIELDS" => [ @EXPORT_OK, @EXPORT ] );
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
our %mzconfig_data = ();

# Constants

sub
new($) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    my $config_type = shift;

    bless($self, $class);
    &load($self, $config_type);
    return $self;
}

sub
load($)
{
    my ($self, $config_type) = @_;
    my ($filename, $path, $line);
    local *CFG;

    $config_type =~ s/::/\//g;
    $filename = sprintf("%s/.mezz/%s", $ENV{"HOME"}, $config_type);

    $path = &dirname($filename);
    if (! -d $path) {
        &mkdirhier($path);
    }

    if (-s $filename) {
        $mzconfig_data{"__FILENAME"} = $filename;
        if (!open(CFG, $filename)) {
            eprint "Unable to open $filename -- $!\n";
            return;
        }
        while (<CFG>) {
            my ($key, $value);

            chomp($line = $_);
            ($key, $value) = split(/ = /, $line, 2);
            xpush @{$mzconfig_data{"__KEYS"}}, $key;
            $mzconfig_data{$key} = $value;

            # Create an anonymous subroutine which matches the given key
            # as an "accessor" member function to the Mezzanine::Config class.
            no strict "refs";
            *$key = sub {
                shift;
                if (@_) {
                    $mzconfig_data{$key} = shift;
                }
                return $mzconfig_data{$key};
            };
        }
        close(CFG);
    } elsif (-s "$filename.cdf") {
        $mzconfig_data{"__FILENAME"} = "$filename.cdf";
        if (!open(CFG, "$filename.cdf")) {
            eprint "Unable to open $filename.cdf -- $!\n";
            return;
        }
        while (<CFG>) {
            my @inp;
            my $key;

            chomp($line = $_);
            @inp = split(':', $line);
            $key = shift @inp;
            xpush @{$mzconfig_data{"__KEYS"}}, $key;
            @{$mzconfig_data{$key}} = @inp;

            # Create an anonymous subroutine which matches the given key
            # as an "accessor" member function to the Mezzanine::Config class.
            no strict "refs";
            *$key = sub {
                shift;
                if (@_) {
                    $mzconfig_data{$key} = shift;
                }
                return $mzconfig_data{$key};
            };
        }
        close(CFG);
    } elsif (-s "$filename.xml") {
        $mzconfig_data{"__FILENAME"} = "$filename.xml";

    } else {
        $mzconfig_data{"__FILENAME"} = $filename;
    }
}

sub
save()
{
    my ($self, $config_type) = @_;
    my ($filename, $line);
    local *CFG;

    $filename = $mzconfig_data{"__FILENAME"};
    if (!open(CFG, ">$filename")) {
        eprint "Unable to open $filename -- $!\n";
        return;
    }

    if (substr($filename, -4, 4) eq ".xml") {

    } elsif (substr($filename, -4, 4) eq ".cdf") {
        foreach my $key (sort(grep { substr($_, 0, 2) ne "__" } keys(%mzconfig_data))) {
            print CFG "$key:", join(':', @{$mzconfig_data{$key}}), "\n";
        }
    } else {
        foreach my $key (sort(grep { substr($_, 0, 2) ne "__" } keys(%mzconfig_data))) {
            print CFG "$key = $mzconfig_data{$key}\n";
        }
    }
    close(CFG);
}

sub
keys()
{
    my $self = shift;

    return @{$mzconfig_data{"__KEYS"}};
}

sub
get($)
{
    my $self = shift;
    my $key = shift;

    return $mzconfig_data{$key};
}

sub
set($)
{
    my $self = shift;
    my $key = shift;

    if (!exists($mzconfig_data{$key})) {
        # Create an anonymous subroutine which matches the given key
        # as an "accessor" member function to the Mezzanine::Config class.
        no strict "refs";
        *$key = sub {
            shift;
            if (@_) {
                $mzconfig_data{$key} = shift;
            }
            return $mzconfig_data{$key};
        };
    }
    return ($mzconfig_data{$key} = $_[0]);
}

### Private functions

1;
