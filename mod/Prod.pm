# Avalon Prod Perl Module
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
# $Id: Prod.pm,v 1.3 2001/07/25 02:57:32 mej Exp $
#

package Avalon::Prod;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ('@products', '@packages', '@failed_pkgs', '$prods', '$pkgs', '$failure', '&get_var_name', '&get_package_stages', '&branch_tag_prefix', '&pkg_to_release_tag', '&pkg_to_branch_tag', '&place_file', '&fail_package', '&find_product_file', '&parse_product_entry', '&parse_prod_file');
    %EXPORT_TAGS = ();

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$prods = undef;
$pkgs = undef;
$failure = undef;
@products = ();
@packages = ();
@failed_pkgs = ();

### Initialize private global variables
$proddir = ".";
@allvars = ();

### Function prototypes
sub get_var_name($);
sub get_package_stages($);
sub branch_tag_prefix();
sub pkg_to_release_tag($$);
sub pkg_to_branch_tag($$);
sub place_file($$$);
sub fail_package($$);
sub find_product_file($$);
sub parse_product_entry($$$);
sub parse_prod_file($$$);
sub summarize_failures();
sub parallel_build();
sub build_process();

# Private functions

### Module cleanup
END {
}

### Function definitions

# Translate abbreviated variable names into their canonical forms
sub
get_var_name
{
    my $var = $_[0];

    # Variable names are all uppercase because they are struct members.
    $var =~ tr/[a-z]/[A-Z]/;

    if ($var =~ /^REL/) {
        $var = "RELEASE";
    } elsif ($var =~ /^VER/) {
        $var = "VERSION";
    } elsif ($var =~ /^LOC/) {
        $var = "LOCATIONS";
    }
    return $var;
}

# Supply the branch tag prefix
sub
branch_tag_prefix
{
    return "VA-";
}

# Convert a package name/version to a release tag
sub
pkg_to_release_tag
{
    my ($pkg_name, $pkg_version) = @_;
    my $tag;

    $tag = "$pkg_name-$pkg_version";
    $tag =~ tr/[a-z]/[A-Z]/;
    $tag =~ s/[^-A-Z0-9]/_/g;
    return $tag;
}

# Convert a package name/version to a branch tag
sub
pkg_to_branch_tag
{
    my ($pkg_name, $pkg_version) = @_;

    return (&branch_tag_prefix() . &pkg_to_release_tag($pkg_name, $pkg_version));
}

# Find the proper location within the image for an output file
sub
place_file
{
    my ($pkg, $loc, $file) = @_;
    my $found = 0;

    dprint "place_file(\"$pkg\", \"$loc\", \"$file\") called.\n";

    foreach $location (split(",", $loc)) {
        my ($regex, $stop, $dest, $image, $subdir);

        # Format is:  /regexp/.path  where . is some delimiter character that
        # tells us whether to check other locations or stop once we match
	# (':' to continue looking for matches, or '=' to stop if a match is found).
        dprint "Testing location \"$location\"\n";
        if ($location !~ m/^\/([^\/]+)\/(.)(\S+)?$/) {
            eprint "Location specifier \"$location\" is invalid.\n";
            next;
        }
        ($regex, $stop, $dest) = ($1, $2, $3);
        if ($stop eq "!") {
            # A negative match test.  If we get a match, don't accept it.
            next if ($file =~ $regex);
        } else {
            # No match.  Try next location.
            next if ($file !~ $regex);
        }
        dprint "Match found.\n";

        if ($dest) {
            # If the destination does not contain a filename, add the filename portion of
            # $file to the directory path in $dest.  The destination could be used to rename
            # a file, however; that's why this check is in place.
            if (substr($dest, -3, 3) ne substr($file, -3, 3)) {
                my $tmp;

                ($tmp = $file) =~ s/^.*\/([^\/]+)$/$1/;
                $dest = "$dest/$tmp";
            }
            # If it exists, delete it
            if (-e $dest) {
                &nuke_tree($dest);
            }
            # Then link it
            dprint "ln -f $file $dest\n";
            if (!link($file, $dest)) {
                &fail_package($pkg, "package accumulation", "Unable to hard-link $dest to $file -- $!");
                return $found;
            }
        }
        $found++;

        # If the stop character is '=', stop checking for matches for this package.
        # If it's ':' (actually, any other character than '='), keep looking for matches.
        last if ($stop eq "=");
        dprint "Non-exclusive match.  Continuing on....\n";
    }
    return $found;
}

# What to do if a package fails
sub
fail_package
{
    my ($pkg, $msg) = @_;

    push @failed_pkgs, $pkg;
    if ($msg) {
        $msg =~ s/\.+$//;
        eprint "Package \"$pkg\" failed:  $msg.\n";
    } else {
        eprint "Package \"$pkg\" failed with an unknown error.\n";
    }
}

# Locate the product file for a particular product
sub
find_product_file
{
    my ($prodname, $prodver) = @_;
    my $prodfile;

    dprint "find_product_file($prodname, ", ($prodver ? $prodver : ""), ")\n";

    if ($prodver) {
        # Try the whole product ID.
        ($prodfile = "$proddir/$prodname-$prodver") =~ s/(\.prod)?$/.prod/;
        if (-f $prodfile) {
            return $prodfile;
        } elsif (defined($ENV{AVALON_PRODUCTS}) && -f "$ENV{AVALON_PRODUCTS}/$prodfile") {
            return "$ENV{AVALON_PRODUCTS}/$prodfile";
        }
    }

    # Try just the product name
    ($prodfile = "$proddir/$prodname") =~ s/(\.prod)?$/.prod/;
    if (-f $prodfile) {
        return $prodfile;
    } elsif (defined($ENV{AVALON_PRODUCTS}) && -f "$ENV{AVALON_PRODUCTS}/$prodfile") {
        return "$ENV{AVALON_PRODUCTS}/$prodfile";
    }

    # Give up.  It doesn't exist.
    return 0;
}

# Parse a product entry line from a file or the command line
sub
parse_product_entry
{
    my ($line, $prodname, $prodver) = @_;
    my ($type, $name, $arch, $module, $filename, $pkgvar, $var, $val);
    my $type_guess = 0;
    my (%pkgvars, @inp);
    my $prod;

    if ($prodname) {
        if ($prodver) {
            $prod = "$prodname-$prodver";
        } else {
            $prod = $prodname;
            $prodver = 0;
        }
    } else {
        $prod = $prodname = $prodver = 0;
    }
    dprint "parse_product_entry(\"$line\", \"$prodname\", \"$prodver\")\n";
    undef %pkgvars;
    undef $module;
    undef $type;
    # For now, the line we're passed is whitespace-delimited.
    @inp = split(/\s+/, $line);
    dprint "Input is \"", join("\" \"", @inp), "\"\n";
    if ($inp[0] =~ /^(prod|mod|s?rpm|tar|tbz|tgz|ima?ge?)[^:]*:/) {
        # Line begins with <type>:<name>, like "module:Eterm"
        ($type, $name) = split(":", $inp[0]);
        $type =~ tr/[A-Z]/[a-z]/;
        if (! $name && $inp[1]) {
            # If there's no name, but there's a colon after the type, they probably
            # just put in some extra whitespace.  Grab it and shift everything left.
            $name = $inp[1];
            shift @inp;
        }
        dprint "parse_product_entry():  Found type \"$type\" and name \"$name\"\n";
        if ($type =~ /^prod/) {
            $type = "product";
        } elsif ($type =~ /^mod/) {
            $type = "module";
        } elsif ($type =~ /^srpm/) {
            $type = "srpm";
        } elsif ($type =~ /^rpm/) {
            $type = "rpm";
        } elsif ($type =~ /^t(ar|bz|gz)/) {
            $type = "tar";
        } elsif ($type =~ /^image/) {
            $type = "image";
        } else {
            eprint "$type is not a valid package type.  I'll try to guess the correct one.\n";
            $type = 0;
        }
    }
    if (! $type) {
        # They didn't tell us the type, so let's guess educatedly.
        $type_guess = 1;
        ($name = $inp[0]) =~ s/^\w*://;
        dprint "Guessing type of \"$name\"\n";
        if ($name =~ /src\.rpm$/) {
            # Name ends with src.rpm.
            $type = "srpm";
        } elsif ($name =~ /\.rpm$/) {
            # Name ends with .rpm but it's not a source RPM. 
            $type = "rpm";
        } elsif ($name =~ /\.(t?gz|Z|bz2)$/) {
            # Name ends with .tgz, .Z, .bz2, etc.  Tarball.
            $type = "tar";
        } elsif ($proddir ne "") {
            my @contents = ();
	    
            # Check to see if there is a product file for it
            @contents = &grepdir(sub {/^$name-?.*\.prod$/}, $proddir);
            # Product files win over modules because they contain more detail
            # about the package and are more likely to succeed.
            if ($#contents >= 0) {
		$type = "product";
                ($name = $contents[0]) =~ s/\.prod$//;
            } else {
                $type = "module";
            }
	} else {
	    dprint "Can't find anything useful, assuming a module\n";
	    $type = "module";
	}
    }

    if ($name =~ /\/.+$/) {
	# If the name contains a / and at least *something* after it, split out the module name
	# (the part before the /) and the actual package name (the part after the /).  Otherwise,
	# assume that the module name is exactly the same as the package name.
        ($module = $name) =~ s/^([^\/]+)(.+)$/$1/;
        $name =~ s/^(.*)\/([^\/]+)$/$2/;
    } else {
        $module = $name;
    }
    # The rest of the line is whitespace-delimited sets of var=value
    shift @inp;
    dprint "Input is now \"", join("\" \"", @inp), "\"\n";
    foreach $varval (@inp) {
        ($var, $val) = split("=", $varval, 2);
        $var = &get_var_name($var);
	# Store them in %pkgvars for now; we'll move them later.
        $pkgvars{$var} = $val;
    }
    # Some package types require special treatment at this point.
    if ($type eq "product") {
        my ($pname, $pver);

        # Separate name and version
        if ($pkgvars{VERSION}) {
            ($pname, $pver) = ($name, $pkgvars{VERSION});
            $name = "$pname-$pver";
        } elsif ($name =~ /^(\S+)-((?:\d|us|a|alpha|b|beta)[^-]+)$/) {
            ($pname, $pver) = ($1, $2);
        } else {
            $pname = $name;
            $pver = 0;
        }

        # Recursively convert products into their component packages
        $prods->{$name}{PRODUCT} = $prod;
        dprint "parse_product_entry():  Parent product of $name is $prod.\n";
        if (! &parse_prod_file($pname, $pver, $prod)) {
            dprint "parse_product_entry():  parse_prod_file($pname, $pver, $prod) failed.\n";
            undef $prods->{$name}{PRODUCT};
            if ($type_guess) {
                # If this was a guess, a potential infinite loop exists if we try
                # to parse the product entry again.  So just punt at this point.
                dprint "parse_product_entry() returning 0.\n";
                return 0;
            } else {
                my $tmp;

                $line =~ s/^[^:]+://;
                $tmp = &parse_product_entry($line, $prodname, $prodver);
                dprint "parse_product_entry():  parse_product_entry(\"$line\", $prodname, $prodver) returned $tmp, so I will to.\n";
                return $tmp;
            }
        }
        dprint "parse_product_entry():  parse_prod_file($pname, $pver, $prod) succeeded, so I'm returning 1.\n";
        return 1;
    }

    dprint "parse_product_entry():  Module is $module, name is $name\n";
    # Add defaults for stuff that is required
    if ($type eq "module" || $type eq "image") {
        # Anything needed here?
    } elsif ($type eq "tar") {
        $filename = "$module/$name";
    } elsif ($type eq "srpm" || $type eq "rpm") {
        if ($name =~ /^(\S+)\.(\w+)\.rpm$/) {
            ($name, $arch) = ($1, $2);
        } else {
            $arch = ($type eq "srpm" ? "src" : "i386");
        }
        if (!defined $pkgvars{RELEASE}) {
            if ($name !~ /^\S+-[^-]+-[^-]+$/) {
                eprint "I wasn't given enough information about the $name package in $prodfile.  For RPM/SRPM\n";
                eprint "packages, the version and release information must be specified as variables or\n";
                eprint "embedded in the package name.  I'm going to have to skip that one.\n";
                return 0;
            } else {
                ($tmp = $name) =~ s/^\S+-[^-]+-//;
                $name =~ s/-[^-]+$//;
                $pkgvars{RELEASE} = $tmp;
            }
        }
        if (!defined $pkgvars{VERSION}) {
            if ($name !~ /^\S+-[^-]+$/) {
                eprint "I wasn't given enough information about the $name package in $prodfile.  For RPM/SRPM\n";
                eprint "packages, the version and release information must be specified as variables or\n";
                eprint "embedded in the package name.  I'm going to have to skip that one.\n";
                return 0;
            } else {
                ($tmp = $name) =~ s/^(\S+)-([^-]+)$/$2/;
                $name =~ s/^(\S+)-([^-]+)$/$1/;
                $pkgvars{VERSION} = $tmp;
            }
        }
        $filename = "$name-$pkgvars{VERSION}-$pkgvars{RELEASE}.$arch.rpm";

        if (defined($pkgvars{BINS})) {
            my @tmp;
            my $arch = "i386";

            foreach my $p (split(',', $pkgvars{BINS})) {
                if ($p =~ /^(.+\/)?.*-[^-]+-[^-]+\.(\w+)\.rpm$/) {
                    push @tmp, $p;
                } else {
                    push @tmp, "$p-$pkgvars{VERSION}-$pkgvars{RELEASE}.$arch.rpm";
                }
            }
            delete $pkgvars{BINS};
            @{$pkgs->{$name}{BINS}} = @tmp;
        }
    }

    # Check for duplicate packages.
    if (grep($_ eq $name, @packages)) {
        if ($type eq "rpm" && ($pkgs->{$name}{TYPE} eq "srpm" || $pkgs->{$name}{TYPE} eq "tar")) {
            dprint "Adding $module/$filename as a binary package for $name\n";
            push(@{$pkgs->{$name}{BINS}}, "$module/$filename");
            $pkgs->{$name}{STAGES} =~ s/c//;
        } else {
            eprint "I already have $name as a $pkgs->{$name}{TYPE} package in $pkgs->{$name}{PRODUCT}.\n";
            eprint "I will ignore the duplicate entry found in $prodname $prodver\n";
        }
        return 0;
    }
    # Now that we've got the name/version/release in their final forms, set up the data structures.
    $pkgs->{$name}{TYPE} = $type;
    $pkgs->{$name}{MODULE} = $module;
    $pkgs->{$name}{FILENAME} = ($filename ? $filename : $module);
    dprint "parse_product_entry():  New package:  $name (module $pkgs->{$name}{MODULE}, "
        . "filename $pkgs->{$name}{FILENAME}) is a $pkgs->{$name}{TYPE}\n";
    foreach $pkgvar (keys %pkgvars) {
        if ($pkgvars{$pkgvar} !~ /^$/) {
            $pkgs->{$name}{$pkgvar} = $pkgvars{$pkgvar};
            xpush(@allvars, $var);
            dprint "parse_product_entry():  Added variable $pkgvar to package $name with value \"$pkgs->{$name}{$pkgvar}\"\n";
        }
    }
    # Go through each propogated variable.  If there is no assigned value for that
    # variable for the current package, see if it has a value for the parent product
    # of that package.  If not, try the parent product of that product, and continue
    # going back through the product hierarchy until we find a value or run out or products.
    #
    # FIXME:  Perhaps these shouldn't be hard-coded.  Perhaps we should keep a list of
    #         all package/product variables we've encountered thus far and iterate
    #         through those only, since we're guaranteed no others will have a fallback.
    foreach $pkgvar (@allvars) {
        if (! $pkgs->{$name}{$pkgvar}) {
            my ($pkg, $val) = undef;

            dprint "parse_product_entry():  No value for the variable $pkgvar for $name.\n";
            for ($pkg = $prod; $pkg; $pkg = $prods->{$pkg}{PRODUCT}) {
                dprint "parse_product_entry():  Checking $pkg for $pkgvar\n";
                if ($prods->{$pkg}{$pkgvar}) {
                    $val = $prods->{$pkg}{$pkgvar};
                    dprint "parse_product_entry():  Found fallback value $val in product $pkg\n";
                    last;
                }
            }
            if ($val) {
                $pkgs->{$name}{$pkgvar} = $val;
            }
        }
    }
    # Add the package name to the list of packages
    push @packages, $name;
    # Set the parent product name
    $pkgs->{$name}{PRODUCT} = ($prod ? $prod : "unknown-product");
    dprint "parse_product_entry():  Parent product of $name set to $prod.  I'm done, returning 1.\n";
    return 1;
}

# Parse product definition files recursively to establish
# all the products we need to work with and what packages or
# other products compose them.
sub
parse_prod_file($$$)
{
    my ($prodname, $prodver, $parent_prod) = @_;
    my ($prodfile, $skip_to_name, $skip_to_next_ver, $found, $line);
    my $prod = $prodname;
    local *PROD;

    # First, find the product file and open it.
    dprint "parse_prod_file($prodname, ", ($prodver ? $prodver : ""), ", ", ($parent_prod ? $parent_prod : ""), ")\n";
    if (!($prodfile = &find_product_file($prodname, $prodver))) {
        dprint "parse_prod_file():  find_product_file() failed.  Returning 0.\n";
        return 0;
    }
    dprint "parse_prod_file():  Found product file \"$prodfile\"\n";
    open(PROD, "$prodfile") || return 0;

    # Ignore everything until we encounter a product name
    ($skip_to_name, $skip_to_next_ver, $found) = (1, 0, 0); 
    @allvars = ();
    while (<PROD>) {
        chomp($line = $_);
        dprint "parse_prod_file():  Parsing $prodfile:  \"$line\"\n";
        $line =~ s/^\s*(.*\S)\s*$/$1/;  # Strip leading and trailing whitespace
        next if ($line =~ /^\#/ || $line !~ /\S/);
        next if ($skip_to_name && $line !~ /^name\s*:/i);
        next if ($skip_to_next_ver && $line !~ /^ver(sion)?\s*:/i);
        if ($line =~ /^name\s*:/) {
            $line =~ s/^[^:]+:\s*//;
            $prodname = $line;
            $skip_to_name = 0;
            $skip_to_next_ver = 1;
            next;
        } elsif ($line =~ /^ver(sion)?\s*:/) {
            if ($skip_to_next_ver) {
                $line =~ s/^[^:]+:\s*//;
                next if ($prodver && $line ne $prodver);
                # Found it!
                if ($prodver) {
                    dprint "parse_prod_file():  Found product version match.  Time to parse the product.\n";
                } else {
                    dprint "parse_prod_file():  No product version given.  Using first entry:  $line\n";
                    $prodver = $line;
                }
                $prod = "$prodname-$prodver";
                ($found, $skip_to_next_ver) = (1, 0);
                push @products, $prod;
                if ($parent_prod) {
                    $prods->{$prod}{PRODUCT} = $parent_prod;
                    dprint "parse_prod_file():  Parent product of $prod is $prods->{$prod}{PRODUCT}.\n";
                } elsif ($prods->{$prodname}{PRODUCT}) {
                    $prods->{$prod}{PRODUCT} = $prods->{$prodname}{PRODUCT};
                    dprint "parse_prod_file():  Parent product of $prod is $prods->{$prod}{PRODUCT}.\n";
                }
                next;
            } else {
                # New version.  Time to quit.
                last;
            }
        } else {
            dprint "parse_prod_file():  Checking \"$line\" for product variables.\n";
            if ($line !~ /^(prod|mod|s?rpm|ima?ge?)/i && $line =~ /^([^ \t:]+)\s*:\s*(\S+.*)$/) {
                my ($var, $val);

                # The regexp above should only match var:value (a product variable)
                ($var, $val) = ($1, $2);
                $var = &get_var_name($var);
                dprint "parse_prod_file():  Product variable for $prod:  $var -> $val\n";
                $prods->{$prod}{$var} = $val;
            } elsif (!($skip_to_name || $skip_to_next_ver)) {
                my $tmp;

                dprint "parse_prod_file():  Calling parse_product_entry()...\n";
                $tmp = &parse_product_entry($line, $prodname, $prodver);
                dprint "parse_prod_file():  parse_product_entry() returned $tmp\n";
            }
        }
    }
    dprint "parse_prod_file():  Closing file $prodfile and returning $found\n";
    close(PROD);
    return ($found);
}

### Private functions


1;