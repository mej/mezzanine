# Mezzanine Prod Perl Module
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
# $Id: Prod.pm,v 1.23 2004/03/14 15:42:08 mej Exp $
#

package Mezzanine::Prod;

BEGIN {
    use strict;
    use Exporter   ();
    use Cwd;
    use Mezzanine::Util;
    use Mezzanine::PkgVars;
    use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK', '%EXPORT_TAGS');

    # set the version for version checking
    $VERSION     = 2.1;

    @ISA         = ('Exporter');

    @EXPORT = ('@products', '@packages', '$prods', '$pkgs',
               '&make_build_dir', '&make_log_dir', '&get_var_name',
               '&find_product_file', '&parse_product_entry',
               '&parse_prod_file', '&assign_product_variable',
               '&assign_package_variable');

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
@allvars = ("TAG", "REPOSITORY", "LOCATIONS");

### Function prototypes
sub make_build_dir($);
sub make_log_dir($);
sub get_var_name($);
sub find_product_file($$);
sub parse_product_entry($$$);
sub parse_prod_file($$$);

# Private functions

### Module cleanup
END {
}

### Function definitions

# Create the top-level build directory for doing product builds
sub
make_build_dir
{
    my $builddir = shift;

    # Create a build area for ourselves.
    if (-f $builddir) {
        &nuke_tree($builddir);
    }
    if (!(-d $builddir || &mkdirhier($builddir, 0755))) {
        &fatal_error("Unable to create build directory -- $!\n");
    }
    if (!chdir($builddir)) {
        &fatal_error("Unable to chdir to build directory -- $!\n");
    }
    chown($mz_uid, $mz_gid, $builddir);
    #dprint "Chose build directory $builddir\n";
    return $builddir;
}

# Create the directory to keep the log files for parallel/distributed builds
sub
make_log_dir
{
    my $logdir = shift;

    if (-f $logdir) {
        &nuke_tree($logdir);
    }
    if (!(-d $logdir || &mkdirhier($logdir, 0755))) {
        &fatal_error("Unable to create log directory -- $!\n");
    }
    chown($mz_uid, $mz_gid, $logdir);
    #dprint "Chose log directory $logdir\n";
    return $logdir;
}

# Translate abbreviated variable names into their canonical forms
sub
get_var_name
{
    my $var = $_[0];

    # Variable names are all uppercase because they are struct members.
    $var =~ tr/[a-z]/[A-Z]/;

    if ($var =~ /^REV/ || $var eq "TAG") {
        $var = "TAG";
    } elsif ($var =~ /^EPOCH/) {
        $var = "EPOCH";
    } elsif ($var =~ /^REL/) {
        $var = "RELEASE";
    } elsif ($var =~ /^VER/) {
        $var = "VERSION";
    } elsif ($var =~ /^LOC/) {
        $var = "LOCATIONS";
    } elsif ($var =~ /^SOURCE/) {
        $var = "SRCS";
    } elsif ($var =~ /^ARCH/) {
        $var = "ARCH";
    } elsif ($var =~ /^TARGET/) {
        $var = "TARGET";
    } elsif ($var =~ /^CVS(DIR|ROOT)/) {
        $var = "REPOSITORY";
    } elsif ($var =~ /^((CH|INST)ROOT|JAIL)([_A-Z]*)$/) {
        # This one case covers CHROOT, CHROOT_INIT, CHROOT_RESET, et al.
        $var = "INSTROOT$3";
    } elsif ($var =~ /^BUILD_?(USER|AS)$/) {
        $var = "BUILDUSER";
    }
    return $var;
}

# Locate the product file for a particular product
sub
find_product_file
{
    my ($prodname, $prodver) = @_;
    my $prodfile;

    dprint &print_args(@_);

    if (! $prodname) {
        if (-f "prod.mezz") {
            return "prod.mezz";
        } else {
            return 0;
        }
    }

    if ($prodver) {
        # Try the whole product ID.
        ($prodfile = "$proddir/$prodname-$prodver") =~ s/(\.prod)?$/.prod/;
        if (-f $prodfile) {
            return $prodfile;
        } elsif (defined($ENV{MEZZANINE_PRODUCTS}) && -f "$ENV{MEZZANINE_PRODUCTS}/$prodfile") {
            return "$ENV{MEZZANINE_PRODUCTS}/$prodfile";
        }
    }

    # Try just the product name
    ($prodfile = "$proddir/$prodname") =~ s/(\.prod)?$/.prod/;
    if (-f $prodfile) {
        return $prodfile;
    } elsif (defined($ENV{MEZZANINE_PRODUCTS}) && -f "$ENV{MEZZANINE_PRODUCTS}/$prodfile") {
        return "$ENV{MEZZANINE_PRODUCTS}/$prodfile";
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

    dprint &print_args(@_);
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
        dprint "Found type \"$type\" and name \"$name\"\n";
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

    if ($name =~ /^(.*)\/([^\/]+)$/) {
	# If the name contains a / and at least *something* after it, split out the module name
	# (the part before the /) and the actual package name (the part after the /).  Otherwise,
	# assume that the module name is exactly the same as the package name.
        ($module, $name) = ($1, $2);
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

        foreach my $pkgvar (keys %pkgvars) {
            if ($pkgvars{$pkgvar} !~ /^$/) {
                $prods->{$name}{$pkgvar} = $pkgvars{$pkgvar};
                xpush(@allvars, $pkgvar);
            }
        }

        # Recursively convert products into their component packages
        $prods->{$name}{PRODUCT} = $prod;
        dprint "Parent product of $name is $prod.\n";
        if (! &parse_prod_file($pname, $pver, $prod)) {
            dprint "parse_prod_file($pname, $pver, $prod) failed.\n";
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
                dprint "parse_product_entry(\"$line\", $prodname, $prodver) returned $tmp, so I will too.\n";
                return $tmp;
            }
        }
        dprint "parse_prod_file($pname, $pver, $prod) succeeded, so I'm returning 1.\n";
        return 1;
    }

    dprint "Module is $module, name is $name\n";
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
        $pkgvars{"ARCH"} = $arch;
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
    $pkgs->{$name}{"TYPE"} = $type;
    $pkgs->{$name}{"MODULE"} = $module;
    $pkgs->{$name}{"FILENAME"} = ($filename ? $filename : $module);
    $pkgs->{$name}{"INSTROOT"} = &pkgvar_get("instroot");
    $pkgs->{$name}{"HINTS"} = &pkgvar_get("hints");
    $pkgs->{$name}{"HINT_INSTALLER"} = &pkgvar_get("hint_installer");
    dprint "New package:  $name (module $pkgs->{$name}{MODULE}, "
        . "filename $pkgs->{$name}{FILENAME}) is a(n) $pkgs->{$name}{TYPE}\n";
    foreach $pkgvar (keys %pkgvars) {
        if ($pkgvars{$pkgvar} !~ /^$/) {
            $pkgs->{$name}{$pkgvar} = $pkgvars{$pkgvar};
            xpush(@allvars, $pkgvar);
            dprint "Added variable $pkgvar to package $name with value \"$pkgs->{$name}{$pkgvar}\"\n";
        }
    }
    # Go through each propogated variable.  If there is no assigned value for that
    # variable for the current package, see if it has a value for the parent product
    # of that package.  If not, try the parent product of that product, and continue
    # going back through the product hierarchy until we find a value or run out or products.
    foreach $pkgvar (@allvars) {
        if (! $pkgs->{$name}{$pkgvar}) {
            my ($pkg, $val) = undef;

            dprint "No value for the variable $pkgvar for $name.\n";
            for ($pkg = $prod; $pkg; $pkg = $prods->{$pkg}{PRODUCT}) {
                dprint "Checking $pkg for $pkgvar\n";
                if ($prods->{$pkg}{$pkgvar}) {
                    $val = $prods->{$pkg}{$pkgvar};
                    dprint "Found fallback value $val in product $pkg\n";
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
    dprint "Parent product of $name set to $prod.  I'm done, returning 1.\n";
    return 1;
}

# Parse product definition files recursively to establish
# all the products we need to work with and what packages or
# other products compose them.
sub
parse_prod_file($$$)
{
    my ($prodname, $prodver, $parent_prod) = @_;
    my ($prodfile, $pkg, $found, $line);
    my $prod = $prodname;
    my $PROD;

    # First, find the product file and open it.
    dprint &print_args(@_);
    if (!($prodfile = &find_product_file($prodname, $prodver))) {
        dprint "find_product_file() failed.  Returning 0.\n";
        return 0;
    }
    dprint "Found product file \"$prodfile\"\n";
    open($PROD, "$prodfile") || return 0;

    if ($prodname) {
        $prodname = &skip_to_name($PROD, $prodname);
        return 0 if (! $prodname);
    } else {
        $pkg = &basename(&getcwd());
    }
    if ($prodver) {
        $prodver = &skip_to_version($PROD, $prodver);
        return 0 if (! $prodver);
    }

    if (! $pkg) {
        $prod = "$prodname-$prodver";
        $found = 1;
        push @products, $prod;
        if ($parent_prod) {
            $prods->{$prod}{PRODUCT} = $parent_prod;
            dprint "Parent product of $prod is $prods->{$prod}{PRODUCT}.\n";
        } elsif ($prods->{$prodname}{PRODUCT}) {
            $prods->{$prod}{PRODUCT} = $prods->{$prodname}{PRODUCT};
            dprint "Parent product of $prod is $prods->{$prod}{PRODUCT}.\n";
        }
    }

    while (<$PROD>) {
        chomp($line = $_);
        dprint "Parsing $prodfile:  \"$line\"\n";
        $line =~ s/^\s*(.*\S)\s*$/$1/;  # Strip leading and trailing whitespace
        next if ($line =~ /^\#/ || $line !~ /\S/);
        if ($line =~ /^name\s*:/i) {
            if ($pkg) {
                next;
            } else {
                last;
            }
        } elsif ($line =~ /^ver(sion)?\s*:\s*(\S+)/i) {
            if (! $prodver) {
                $prodver = $2;
                dprint "Deleting bogus product $prod\n";
                @products = grep($_ ne $prod, @products);
                $prod = "$prodname-$prodver";
                push @products, $prod;
                if ($parent_prod) {
                    $prods->{$prod}{PRODUCT} = $parent_prod;
                    dprint "Parent product of $prod is $prods->{$prod}{PRODUCT}.\n";
                } elsif ($prods->{$prodname}{PRODUCT}) {
                    $prods->{$prod}{PRODUCT} = $prods->{$prodname}{PRODUCT};
                    dprint "Parent product of $prod is $prods->{$prod}{PRODUCT}.\n";
                }
                next;
            } elsif ($2 eq $prodver) {
                next;
            } else {
                last;
            }
        }
        dprint "Checking \"$line\" for product variables.\n";
        if ($line !~ /^(prod|mod|s?rpm|ima?ge?)/i && $line =~ /^([^ \t:]+)\s*:\s*(\S+.*)$/) {
            if ($pkg) {
                &assign_package_variable($pkg, $1, $2);
            } else {
                &assign_product_variable($prod, $1, $2);
            }
        } else {
            dprint "parse_product_entry() returned ", &parse_product_entry($line, $prodname, $prodver), "\n";
        }
    }
    dprint "Closing file $prodfile\n";
    close($PROD);
    return (1);
}

sub
assign_product_variable
{
    my ($prod, $var, $val) = @_;

    $var = &get_var_name($var);
    dprint "Product variable for $prod:  $var -> $val\n";
    $prods->{$prod}{$var} = $val;
    xpush @allvars, $var;
}

sub
assign_package_variable
{
    my ($pkg, $var, $val) = @_;

    $var = &get_var_name($var);
    dprint "Package variable for $pkg:  $var -> $val\n";
    $pkgs->{$pkg}{$var} = $val;
    xpush @allvars, $var;
}

### Private functions

sub
skip_to_name
{
    my ($PROD, $prodname) = @_;

    while (<$PROD>) {
        my $line;

        chomp($line = $_);
        dprint "Skipping to name:  \"$line\"\n";
        $line =~ s/^\s*(.*\S)\s*$/$1/;  # Strip leading and trailing whitespace
        next if ($line =~ /^\#/ || $line !~ /\S/);
        if ($line =~ /^name\s*:/i) {
            $line =~ s/^[^:]+:\s*//;
            return $line;
        }
    }
    return "";
}

sub
skip_to_version
{
    my ($PROD, $prodver) = @_;

    while (<$PROD>) {
        my $line;

        chomp($line = $_);
        dprint "Skipping to version:  \"$line\"\n";
        $line =~ s/^\s*(.*\S)\s*$/$1/;  # Strip leading and trailing whitespace
        next if ($line =~ /^\#/ || $line !~ /\S/);
        if ($line =~ /^ver(sion)?\s*:/i) {
            $line =~ s/^[^:]+:\s*(\S+)\s*$/$1/;
            next if ($prodver && $line ne $prodver);
            # Found it!
            if ($prodver) {
                dprint "Found product version match.  Time to parse the product.\n";
            } else {
                dprint "No product version given.  Using first entry:  $line\n";
                $prodver = $line;
            }
            return $prodver;
        }
    }
    return "";
}

1;
