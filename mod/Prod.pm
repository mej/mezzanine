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
# $Id: Prod.pm,v 1.1 2001/07/20 15:13:55 mej Exp $
#

package Avalon::Prod;

BEGIN {
    use Exporter   ();
    use Avalon::Util;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.0;

    @ISA         = ('Exporter');
    # Exported functions go here
    @EXPORT      = ();
    %EXPORT_TAGS = ('@products', '@packages', '$prods', '$pkgs');

    # Exported variables go here
    @EXPORT_OK   = ('$VERSION');
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables
$prods = undef;
$pkgs = undef;

### Initialize private global variables

### Function prototypes

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

    $var =~ tr/[a-z]/[A-Z]/;

    # Commonly shortened variables
    if ($var =~ /^REV/ || $var eq "TAG") {
        $var = "REVISION";
    } elsif ($var =~ /^REL/) {
        $var = "RELEASE";
    } elsif ($var =~ /^VER/) {
        $var = "VERSION";
    } elsif ($var =~ /^SPEC/) {
        $var = "SPECFILE";
    } elsif ($var =~ /^DIR/) {
        $var = "DIRS";
    } elsif ($var =~ /^PATCH/) {
        $var = "PATCHES";
    } elsif ($var =~ /^LOC/) {
        $var = "LOCATIONS";
    } elsif ($var =~ /^DESC/) {
        $var = "DESCRIPTION";
    } elsif ($var =~ /^SOURCE/) {
        $var = "SRCS";
    } elsif ($var =~ /^MACRO/) {
        $var = "MACROS";
    }
    return $var;
}

# Translate a package type into its default STAGES variable
sub
get_package_stages
{
    my $type = $_[0];

    if ($type eq "srpm") {
        return "scbp";
    } elsif ($type eq "tar") {
        return "sbp";
    } elsif ($type eq "rpm") {
        return "sbp";
    } elsif ($type eq "module") {
        return "scbp";
    } elsif ($type eq "image") {
        return "s";
    } else {
        return "scbp";
    }
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
    my $tag;

    $tag = &branch_tag_prefix() . &pkg_to_release_tag($pkg_name, $pkg_version);
    return $tag;
}

# Find the proper location within the image for an output file
sub
place_file
{
    my ($pkg, $file) = @_;
    my $found = 0;

    dprint "place_file(\"$pkg\", \"$file\") called.\n";
    if (!defined($pkgs->{$pkg}{LOCATIONS})) {
        $pkgs->{$pkg}{LOCATIONS} = "/./:$basedir";
    }

    foreach $location (split(",", $pkgs->{$pkg}{LOCATIONS})) {
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
            # Grab the first part of the destination path, make sure it's an image module
            ($image = $dest) =~ s/^([^\/]+)\/.*$/$1/;
            if (($dest ne $basedir) && (!defined($pkgs->{$image}{TYPE}) || ($pkgs->{$image}{TYPE} ne "image"))) {
                qprint "Warning:  Destination \"$dest\" is not a package of type \"image\".\n";
            }

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
    my ($pkg, $stage, $msg) = @_;

    push @failed_pkgs, $pkg;
    $failure->{$pkg}{STAGE} = $stage;
    if ($msg) {
        ($failure->{$pkg}{MESSAGE} = $msg) =~ s/\.+$//;
        eprint "Package \"$pkg\" failed at the $failure->{$pkg}{STAGE} stage:  $failure->{$pkg}{MESSAGE}.\n";
    } else {
        eprint "Package \"$pkg\" failed at the $failure->{$pkg}{STAGE} stage.\n";
    }
    @packages = grep($_ ne $pkg, @packages);
    exit(AVALON_PACKAGE_FAILED) if (! $opt_f);
    return 0;
}

# Locate the product file for a particular product
sub
find_product_file
{
    my ($prodname, $prodver) = @_;
    my $prod = ($prodver ? "$prodname-$prodver" : $prodname);
    my $prodfile;
    my @contents;
    local *PRODFILE;

    dprint "find_product_file($prodname, ", ($prodver ? $prodver : ""), ")\n";
    if ($prodver) {
        # If it already has the .prod extension, and it exists, return that
        if ($prod =~ /\.prod$/) {
            if (-f $prod) {
                return $prod;
            } elsif (-f "$proddir/$prod") {
                # Just needed a path
                return "$proddir/$prod";
            } else {
                $prod =~ s/\.prod$//;
            }
        } else {
            # It has no .prod extension.  Let's try just giving it one.
            if (-f "$prod.prod") {
                return "$prod.prod";
            } elsif (-f "$proddir/$prod.prod") {
                # Extension and path needed...
                return "$proddir/$prod.prod";
            }
        }
    }

    # Try just the product name
    if ($prodname =~ /\.prod$/) {
        if (-f $prodname) {
            return $prodname;
        } elsif (-f "$proddir/$prodname") {
            # Just needed a path
            return "$proddir/$prodname";
        } else {
            $prodname =~ s/\.prod$//;
        }
    } else {
        # It has no .prod extension.  Let's try just giving it one.
        if (-f "$prodname.prod") {
            return "$prodname.prod";
        } elsif (-f "$proddir/$prodname.prod") {
            # Extension and path needed...
            return "$proddir/$prodname.prod";
        }
    }

    # Well, rats.  We've eliminated the simple cases.  Time to get creative.
    # Find all the product files and search each one for a match.
    foreach $prodfile (sort(&grepdir(sub {/\.prod$/}, $proddir))) {
        my (@lines, @names, @versions);

        dprint "find_product_file():  Searching product file $prodfile for a match...\n";
        open(PRODFILE, "$proddir/$prodfile") || next;
        @lines = <PRODFILE>;
        @names = grep($_ =~ /^\s*name\s*:/i, @lines);
        @versions = grep($_ =~ /^\s*ver(sion)?\s*:/i, @lines);
        if (grep($_ =~ /$prodname/, @names) && grep($_ =~ /$prodver/, @versions)) {
            # Found it.
            dprint "find_product_file():  Match found!\n";
            return "$proddir/$prodfile";
        }
    }

    # One last chance.  Product directory with a .prod file.
    if (-s "$builddir/$prodname/.prod") {
	return "$builddir/$prodname/.prod";
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
            # If there's no name, but there's something after the type, they probably
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
    foreach $pkgvar ("REVISION", "LOCATIONS", "RPMCMD", "TAR", "ZIP", "STAGES", "CVSROOT", "ARCH", "MACROS") {
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
    # This goes here to avoid the fallback mechanism above.
    if (defined($pkgs->{$name}{REVISION}) && $pkgs->{$name}{REVISION} =~ /^head$/i) {
        undef $pkgs->{$name}{REVISION};
    }
    # If we haven't been told which stages we want, use the defaults.
    if (!defined $pkgs->{$name}{STAGES}) {
        $pkgs->{$name}{STAGES} = &get_package_stages($type);
        if (defined($pkgs->{$name}{BINS})) {
            $pkgs->{$name}{STAGES} =~ s/c//;
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
parse_prod_file
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
    while (<PROD>) {
        chomp($line = $_);
        dprint "parse_prod_file():  Parsing $prodfile:  \"$line\"\n";
        $line =~ s/^\s*(.*\S)\s*$/$1/;  # Strip leading and trailing whitespace
        next if ($line =~ /^\#/ || $line !~ /\S/);
        next if ($skip_to_name && $line !~ /^name\s*:/i);
        next if ($skip_to_next_ver && $line !~ /^ver(sion)?\s*:/i);
        if ($line =~ /^name\s*:/) {
            if ($skip_to_name) {
                $line =~ s/^[^:]+:\s*//;
                if ($line eq $prodname) {
                    dprint "parse_prod_file():  Found product name match\n";
                    $skip_to_name = 0;
                    $skip_to_next_ver = 1;
                    next;
                }
            } else {
                # New product.  Time to quit.
                last;
            }
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

# Use revtool to download a package from the master repository
sub
fetch_package
{
    my $cmd = $_[0];
    my ($err, $msg, $line) = undef;
    local *REVTOOL;

    dprint "About to run $cmd\n";
    if (!open(REVTOOL, "$cmd 2>&1 |")) {
        $err = AVALON_COMMAND_FAILED;
        $msg = "Execution of \"$cmd\" failed -- $!";
        last;
    }
    while (<REVTOOL>) {
        chomp($line = $_);
        nprint "$line\n";
        next if ($line =~ /^\[debug:/);
        # Check the output for errors
        if ($line =~ /^revtool:\s*Error/) {
            ($msg = $line) =~ s/^revtool:\s*Error:\s*//;
        }
    }
    close(REVTOOL);
    $err = $?;
    dprintf "\"$cmd\" returned $err (%d)\n", $err >> 8;
    return ($err >> 8, $msg);
}

# Clean up the RPM build directories and the build root
sub
cleanup
{
    my $type = $_[0];
    my @dirs;

    if ($type =~ /no(ne)?/i) {
        return;
    } elsif ($type =~ /temp/i) {
        @dirs = ("$builddir/BUILD", "$builddir/SOURCES", "$builddir/SPECS", $buildroot);
    } elsif ($type =~ /rpm/i) {
        @dirs = ("$builddir/BUILD", "$builddir/SOURCES", "$builddir/SRPMS", "$builddir/RPMS", "$builddir/SPECS");
    } elsif ($type =~ /(build)?root/) {
        @dirs = ($buildroot);
    } else {
        @dirs = ("$builddir/BUILD", "$builddir/SOURCES", "$builddir/SRPMS", "$builddir/RPMS", "$builddir/SPECS", $buildroot);
    }
    foreach $f (@dirs) {
        nprint "$progname:  Cleaning up $f\n";
        &nuke_tree($f) || qprint "Warning:  Removal of $f failed -- $!\n";
    }
}

# Once we're all done, summarize any failures at the very end
# so that they're easy to find if the user is generating a log.
sub
summarize_failures
{
    my ($ns, $nf, $nt);

    # $ns is the number of successful packages.  $nf is the number of failures.
    # $nt is the total number of packages we tried to build.
    $ns = scalar(@packages);
    $nf = scalar(@failed_pkgs);
    $nt = $ns + $nf;
    dprint "Successful:  $ns    Failed:  $nf    Total:  $nt\n";

    qprint "Package Summary:  Out of $nt total packages,";
    if ($ns) {
        qprint(" ", ($ns == $nt ? "all" : "$ns"), " succeeded");
        if ($nf) {
            qprint " and";
        }
    }
    if ($nf) {
        qprint(" ", ($nf == $nt ? "all" : "$nf"), " failed");
    }
    qprint ".\n";

    if ($nf) {
        foreach $pkg (@failed_pkgs) {
            if ($failure->{$pkg}{MESSAGE}) {
                eprint "Package \"$pkg\" failed at the $failure->{$pkg}{STAGE} stage:  $failure->{$pkg}{MESSAGE}.\n";
            } else {
                eprint "Package \"$pkg\" failed at the $failure->{$pkg}{STAGE} stage.\n";
            }
        }
    }
}

# This routine handles the role of "master buildtool"
sub
parallel_build
{
    my ($pid, $err, $idx, $pkg, $logfile, $line, $nprocs, $done, $left, $failed, $bldg);
    my (@children, @vars, @p);
    my %child_pkg;
    local *ERRLOG;

    @p = ($#_ >= 0 ? @_ : @packages);
    if (! -d "$basedir/logs") {
        mkdir("$basedir/logs", 0755) || &fatal_error("Unable to mkdir $basedir/logs -- $!\n");
    }
    $idx = 0;
    # Set $nprocs equal to the index within @children that should not be exceeded.
    $nprocs = $num_cpus - 1;
    # The "!$idx || " part of the test below is required because perl's do...while construct
    # sucks.  You can't use next/last from within it.  Someone shoot whoever decided that.
    qprintf "$progname:  Beginning $num_cpus-way build of %d packages.  (${\(&get_timestamp())})\n", $#p + 1;
    while (!$idx || $#children >= 0) {
        for (; $idx <= $#p && $#children < $nprocs; $idx++) {
            # Spawn a buildtool child process to handle the next package
            $pkg = $p[$idx];
            $logfile = "$basedir/logs/$pkg.log";
            $pid = &spawn_cmd($pkg, $logfile);
            push @children, $pid;
            $child_pkg{$pid} = $pkg;
        }

        # Out of space for children for now.
        $line = "";
        foreach $pid (@children) {
            $line .= "$child_pkg{$pid} ($pid)    ";
        }
        nprint "$progname:  Currently building:  $line\n";
        $bldg = $#children + 1;
        $done = $idx - $#children - 1;
        $left = $#p + 1 - $done - $bldg;
        $failed = $#failed_pkgs + 1;
        nprint "$progname:  $done packages completed ($failed failed), $bldg building, $left in queue.\n";

        # Wait for a child to die
        $pid = waitpid(-1, 0);
        next if (! $child_pkg{$pid});
        $pkg = $child_pkg{$pid};
        $err = $? >> 8;
        if ($pid == -1) {
            # This should never happen.
            eprint "Ummm, waitpid() returned -1.  That wasn't very nice.  I'm offended.\n";
            next;
        }
        @children = grep($_ != $pid, @children);
        if ($err == AVALON_SUCCESS) {
            nprint "Child process $pid for package $pkg completed successfully.  (${\(&get_timestamp())})\n";
        } else {
            dprint "Child process $pid for package $pkg failed, returning $err.\n";
            if ($err == AVALON_SPAWN_FAILED) {
                &fail_package($pkg, "pre-build", "exec() of child failed");
            } else {
                my @tmp;

                # The last line of the logfile should give the error message
                if (!open(ERRLOG, "$basedir/logs/$pkg.log")) {
                    &fail_package($pkg, "???", "Child process returned $err but the log file is missing");
                    next;
                }
                @tmp = <ERRLOG>;
                close(ERRLOG);
                chomp($line = $tmp[$#tmp]);
                if ($line =~ /^$progname:  Error:  Package \S+ failed at the ([a-z ]+) stage:  (.*)$/) {
                    &fail_package($pkg, $1, $2);
                } else {
                    $line =~ s/^\w+:  (Error:  )?\s*//;
                    &fail_package($pkg, "???", "Child process exited with code $err -- $line");
                }
            }
        }
        # End of loop.  Time to spawn the next child.
    }
    qprint "$progname:  Parallel build complete.  (${\(&get_timestamp())})\n";
}

# This routine does the actual build process
sub
build_process
{
    # Perform the build in stages, checking after each one to see if we should stop
    &do_bootstrap_stage() if ($start_stage eq "s");
    return if ($end_stage eq "s" || $#packages == -1);

    if ($master) {
        &parallel_build();
    } else {
        &do_component_stage() if ("sc" =~ /$start_stage/);
        return if ($end_stage eq "c");

        &do_build_stage() if ("scb" =~ /$start_stage/);
        return if ($end_stage eq "b");

        &do_package_stage();
    }
}


### Private functions


1;
