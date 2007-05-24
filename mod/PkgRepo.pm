# Mezzanine Package Repository Perl Module
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
# $Id: PkgRepo.pm,v 1.1 2007/05/24 20:37:41 mej Exp $
#

package Mezzanine::PkgRepo;
use strict;
use Exporter;
use POSIX;
use Mezzanine::Config;
use Mezzanine::Util;
use Mezzanine::RPM;
use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

BEGIN {
    # set the version for version checking
    $VERSION     = 1.0;

    @ISA         = ('Exporter');

    @EXPORT = ('&get_newest', '&get_oldest', '&build_package_hash',
               '&filter_newest', '&filter_oldest', '&filter_old',
               '&span_dirs', '&compare_dirs', '&compare_package_sets');

    %EXPORT_TAGS = ( );

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

### Initialize private global variables

### Function prototypes
sub get_newest(@);
sub get_oldest(@);
sub build_package_hash($);
sub filter_newest($);
sub filter_oldest($);
sub filter_old($);
sub span_dirs($);
sub compare_dirs($$);
sub compare_package_sets($$);

# Private functions

### Module cleanup
END {
}

### Function definitions

# Return the newest RPM in a list, or the list sorted newest -> oldest
sub
get_newest(@)
{
    my @rpms = @_;

    @rpms = reverse(&rpm_sort(@rpms));
    return ((wantarray()) ? (@rpms) : ($rpms[0]));
}

# Return the oldest RPM in a list, or the list sorted oldest -> newest
sub
get_oldest(@)
{
    my @rpms = @_;

    @rpms = &rpm_sort(@rpms);
    return ((wantarray()) ? (@rpms) : ($rpms[0]));
}

# Build hash of package name -> array of RPM's
sub
build_package_hash($)
{
    my $scan = $_[0];
    my $pkgs;

    foreach my $dir (sort(keys(%{$scan}))) {
        foreach my $pkg (sort(keys(%{$scan->{$dir}}))) {
            # pkgs->{DIR}{NAME} is a list of filenames
            push @{$pkgs->{$dir}{$scan->{$dir}{$pkg}{"NAME"}}}, $pkg;
        }
    }
    return $pkgs;
}

# Get only the newest packages from the complete scan list.
sub
filter_newest($)
{
    my $scan = $_[0];
    my $pkgs;

    $pkgs = &build_package_hash($scan);

    # For each unique package, keep only the newest one.
    foreach my $dir (sort(keys(%{$pkgs}))) {
        foreach my $pkg (sort(keys(%{$pkgs->{$dir}}))) {
            my @rpms = &get_newest(@{$pkgs->{$dir}{$pkg}});

            shift @rpms;
            foreach my $rpm (@rpms) {
                delete $scan->{$dir}{$rpm};
            }
        }
    }
    return $scan;
}

# Get only the oldest packages from the complete scan list.
sub
filter_oldest($)
{
    my $scan = $_[0];
    my $pkgs;

    $pkgs = &build_package_hash($scan);

    # For each unique package, keep only the oldest one.
    foreach my $dir (sort(keys(%{$pkgs}))) {
        foreach my $pkg (sort(keys(%{$pkgs->{$dir}}))) {
            my @rpms = &get_oldest(@{$pkgs->{$dir}{$pkg}});

            shift @rpms;
            foreach my $rpm (@rpms) {
                delete $scan->{$dir}{$rpm};
            }
        }
    }
    return $scan;
}

# Get only old packages in the scan list (exact opposite of newest).
sub
filter_old($)
{
    my $scan = $_[0];
    my $pkgs;

    $pkgs = &build_package_hash($scan);

    # For each unique package, pick only the old one.
    foreach my $dir (sort(keys(%{$pkgs}))) {
        foreach my $pkg (sort(keys(%{$pkgs->{$dir}}))) {
            my @rpms = &get_newest(@{$pkgs->{$dir}{$pkg}});
            my $newest_rpm = shift @rpms;

            delete $scan->{$dir}{$newest_rpm};
        }
    }
    return $scan;
}

# Merge all repositories into one
sub
span_dirs($)
{
    my $scan = $_[0];

    foreach my $dir (keys(%{$scan})) {
        foreach my $pkg (keys(%{$scan->{$dir}})) {
            $scan->{'-'}{$pkg} = $scan->{$dir}{$pkg};
        }
        delete $scan->{$dir};
    }
    return $scan;
}

# Display differences between two repositories
sub
compare_dirs($$)
{
    my ($pkgs1, $pkgs2) = @_;
    my (@pkgs1, @pkgs2, @results);
    my ($i, $j);

    # Create sorted arrays of package names
    @pkgs1 = sort(keys(%{$pkgs1}));
    @pkgs2 = sort(keys(%{$pkgs2}));

    dprintf("Comparing %d packages from master dir with %d packages from slave dir.\n",
            scalar(@pkgs1), scalar(@pkgs2));
    for (($i, $j) = (0, 0); ($i < scalar(@pkgs1)) && ($j < scalar(@pkgs2)); ) {
        my $c = $pkgs1[$i] cmp $pkgs2[$j];

        dprintf("Comparing %s (%d) vs. %s (%d):  $c\n", $pkgs1[$i], $i, $pkgs2[$j], $j);
        if ($c < 0) {
            push @results, [ '<<', $pkgs1[$i] ];
            $i++;
        } elsif ($c > 0) {
            push @results, [ '>>', $pkgs2[$j] ];
            $j++;
        } else {
            # For packages that both dirs contain, compare the RPM sets.
            push @results, [ '==', $pkgs1[$i] ];
            push @results, &compare_package_sets($pkgs1->{$pkgs1[$i]}, $pkgs2->{$pkgs2[$j]});
            $i++, $j++;
        }
    }
    # Handle any leftovers.
    while ($i < scalar(@pkgs1)) {
        push @results, [ '<<', $pkgs1[$i] ];
        $i++;
    }
    while ($j < scalar(@pkgs2)) {
        push @results, [ '>>', $pkgs2[$j] ];
        $j++;
    }
    return @results;
}

# Display differences between two sets of a given package
sub
compare_package_sets($$)
{
    my ($pkgs1, $pkgs2) = @_;
    my (@pkgs1, @pkgs2, @results);
    my ($i, $j);

    # Create sorted arrays of RPM packages.
    @pkgs1 = map { &basename($_) } &rpm_sort(@{$pkgs1});
    @pkgs2 = map { &basename($_) } &rpm_sort(@{$pkgs2});

    dprintf("Comparing %d package files from master dir with %d package files from slave dir.\n",
            scalar(@pkgs1), scalar(@pkgs2));
    for ($i = 0, $j = 0; ($i < scalar(@pkgs1)) && ($j < scalar(@pkgs2)); ) {
        my $c = &rpm_cmp($pkgs1[$i], $pkgs2[$j]);

        dprintf("Comparing %s (%d) vs. %s (%d):  $c\n", $pkgs1[$i], $i, $pkgs2[$j], $j);
        if ($c < 0) {
            push @results, [ '<', $pkgs1[$i] ];
            $i++;
        } elsif ($c > 0) {
            push @results, [ '>', $pkgs2[$j] ];
            $j++;
        } else {
            push @results, [ '=', $pkgs1[$i] ];
            $i++, $j++;
        }
    }
    # Handle any leftovers.
    while ($i < scalar(@pkgs1)) {
        push @results, [ '<', $pkgs1[$i] ];
        $i++;
    }
    while ($j < scalar(@pkgs2)) {
        push @results, [ '>', $pkgs2[$j] ];
        $j++;
    }
    return @results;
}

### Private functions

1;
