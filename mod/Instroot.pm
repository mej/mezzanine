# Mezzanine Instroot Perl Module
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
# $Id: Instroot.pm,v 1.3 2004/07/28 21:40:21 mej Exp $
#

package Mezzanine::Instroot;
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

    @ISA = ("Exporter");
}
use vars ('@EXPORT_OK');

### Private global variables

### Initialize exported package variables

# Constants
my @instroot_states = ("new", "available", "inuse", "dirty");
my %defaults = (
                "PATH" => "",
                "STATUS" => "new",
                "INIT" => "",
                "RESET" => "",
                "SOURCE" => ""
               );

sub
new(%) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    my %config_hash = @_;

    bless($self, $class);
    foreach my $key (keys(%defaults)) {
        $self->{$key} = $defaults{$key};
    }
    foreach my $key (keys(%config_hash)) {
        $self->{$key} = $config_hash{$key};
    }
    return $self;
}

sub
config_guess
{
    my $self = shift;

    if (! $self->{"PATH"}) {
        $self->{"PATH"} = &create_temp_space("", "dironly");
    }
}

sub
path
{
    my $self = shift;

    #dprint "My path is $self->{PATH}.\n";
    return $self->{"PATH"};
}

sub
status
{
    my $self = shift;

    #dprint "$self->{PATH}:  My status is $self->{STATUS}\n";
    return $self->{"STATUS"};
}

sub
init
{
    my $self = shift;
    my @output;

    if (! $self->{"PATH"}) {
        $self->config_guess();
    }

    dprint "Initializing chroot jail:  $self->{INIT} $self->{PATH}\n";
    @output = &run_cmd($self->{"INIT"}, $self->{"PATH"}, "instroot-init:  ", 1800);
    if ($output[0] != MEZZANINE_SUCCESS) {
        return 0;
    }
    $self->{"STATUS"} = "available";
    return 1;
}

sub
reset
{
    my $self = shift;
    my @output;
    
    if (! $self->{"PATH"}) {
        $self->config_guess();
    }

    dprint "Resetting chroot jail:  $self->{RESET} $self->{PATH}\n";
    @output = &run_cmd($self->{"RESET"}, $self->{"PATH"}, "instroot-reset:  ", 900);
    if ($output[0] != MEZZANINE_SUCCESS) {
        return 0;
    }
    return 1;
}

sub
use
{
    my $self = shift;

    #dprint "$self->{PATH}:  Using.\n";
    return ($self->{"STATUS"} = "inuse");
}

sub
release
{
    my $self = shift;

    #dprint "$self->{PATH}:  Releasing.\n";
    return ($self->{"STATUS"} = "dirty");
}

sub
release_clean
{
    my $self = shift;

    #dprint "$self->{PATH}:  Releasing (unused).\n";
    return ($self->{"STATUS"} = "available");
}

### Private functions

1;
