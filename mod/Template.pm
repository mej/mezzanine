# Mezzanine Template Perl Module
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
# $Id: Template.pm,v 1.2 2004/03/26 21:31:20 mej Exp $
#

package Mezzanine::Template;
use Class::Struct ('&struct');
use Mezzanine::Util;
use Cwd;

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
# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

### Private global variables

### Initialize exported package variables

# Constants

struct "Mezzanine::Template" => {
    "file" => "\$",
    "directory" => "\$",
    "delimiter" => "\$",
    "vars" => "\%"
};

# Build the object out of a hash/hashref we've been passed.
sub
build
{
    my $self = shift;
    my @params = @_;
    my %params = @_;

    if (!scalar(@params)) {
        return;
    }

    if (ref($params[0])) {
        foreach my $p (@params) {
            my $href;

            if (ref($p) eq "HASH") {
                $self->build(%{$p});
            }
        }
    } else {
        # It's a list of key/value pairs.
        foreach my $k (keys(%params)) {
            my $fref;

            # Make sure we have that property (really a method) before calling it.
            $fref = $self->can($k);
            if (defined($fref)) {
                &{$fref}($self, $params{$k});
            }
        }
    }
    return $self;
}

# Add a variable to the hash.
sub
add_var($$)
{
    my ($self, $var, $val) = @_;
    my $fref;
    my $href;

    # Make sure we have that property (really a method) before calling it.
    $fref = $self->can($var);
    if (defined($fref)) {
        $href = &{$fref}($self);
        $href->{$var} = $val;
    }
    return $val;
}

# Delete a variable from the hash.
sub
del_var($$)
{
    my ($self, $var) = @_;
    my $fref;
    my $href;

    # Make sure we have that property (really a method) before calling it.
    $fref = $self->can($var);
    if (defined($fref)) {
        $href = &{$fref}($self);
        delete $href->{$var};
        return 1;
    } else {
        return 0;
    }
}

# Find the template
sub
find(@)
{
    my $self = shift;
    my @dirs = @_;
    my $template = $self->file();

    push @dirs, @INC;
    push @dirs, &getcwd();
    foreach my $dir (@dirs) {
        next if (! $dir);
        if (-f "$dir/Mezzanine/templates/$template") {
            $self->directory("$dir/Mezzanine/templates");
            return $self->directory();
        } elsif (-f "$dir/templates/$template") {
            $self->directory("$dir/templates");
            return $self->directory();
        }
    }
    return undef;
}

# Verify that the requested template exists.
sub
verify()
{
    my $self = shift;
    my $pathname = sprintf("%s/%s", $self->directory(), $self->file());

    if (-f $pathname) {
        return 1;
    } else {
        return 0;
    }
}

sub
subst($)
{
    my ($self, $contents) = @_;
    my $delim;
    my %vars;

    $delim = $self->delimiter();
    %vars = %{$self->vars()};

    foreach my $var (keys(%vars)) {
        $contents =~ s/$delim$var$delim/$vars{$var}/eg;
    }

    return $contents;
}

sub
generate($)
{
    my ($self, $newfile) = @_;
    my ($filename, $directory, $contents);
    local *DATAFILE;

    $filename = $self->file();
    $directory = $self->directory();
    open(DATAFILE, "$directory/$filename") || return undef;
    $contents = join("", <DATAFILE>);
    close(DATAFILE);

    $contents = $self->subst($contents);

    open(DATAFILE, ">$newfile") || return 0;
    print DATAFILE $contents;
    close(DATAFILE);
    return $contents;
}

### Private functions

1;
