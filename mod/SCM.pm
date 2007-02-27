# Mezzanine SCM Master Perl Module
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
# $Id: SCM.pm,v 1.7 2007/02/27 21:29:36 mej Exp $
#

package Mezzanine::SCM;
use Exporter;
use Mezzanine::Util;
use Mezzanine::SCM::Global;
use strict;

BEGIN {
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
my @SCM_MODULE_LIST;
BEGIN {
    @SCM_MODULE_LIST = ();
    foreach my $inc (@INC) {
        my @tmp = glob("$inc/Mezzanine/SCM/*.pm");

        dprint "Include directory $inc has:  ", join(' ', @tmp), "\n";
        foreach my $module (@tmp) {
            my $modname = &basename($module);

            $modname =~ s/\.pm$//;
            $modname = &untaint(\$modname, qr/^(\w+)$/);
            next if ($modname eq "Global");
            if (!scalar(grep { $_ eq $modname } @SCM_MODULE_LIST)) {
                dprint "$modname not loaded.  Loading.\n";
                eval "use Mezzanine::SCM::$modname";
                if ($@) {
                    eprint "Loading module Mezzanine::SCM::$modname from $module failed -- $@\n";
                } else {
                    push @SCM_MODULE_LIST, $modname;
                }
            }
        }
    }
    dprint "Loaded:  ", join(' ', @SCM_MODULE_LIST), "\n";
}

### Initialize exported package variables

sub
new($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $type = shift;

    dprint &print_args($proto, $class, $type, @_);
    if (!defined($type)) {
        $type = $proto;
    }
    if (! $type) {
        return Mezzanine::SCM::auto_detect(undef, ".");
    } elsif (lc($type) eq "cvs" && grep { $_ eq "CVS" } @SCM_MODULE_LIST) {
        return Mezzanine::SCM::CVS->new();
    } elsif ((lc($type) eq "svn" || lc($type) eq "subversion")
             && grep { $_ eq "Subversion" } @SCM_MODULE_LIST) {
        return Mezzanine::SCM::Subversion->new();
    } else {
        return undef;
    }
}

sub
auto_detect($)
{
    my ($self, $path) = @_;
    my $will;

    dprint &print_args(@_);
    if (!ref($self) && (! $path)) {
        $path = $self;
    }
    if (! $path) {
        $path = '.';
    }
    foreach my $mod (@SCM_MODULE_LIST) {
        my $ret;

        dprint "Trying $mod.\n";
        $ret = eval "Mezzanine::SCM::$mod->can_handle(\"$path\")";
        if ($@) {
            eprint "can_handle() member function call failed -- $@\n";
        } elsif (!defined($ret)) {
            dprint "$mod returned undef.\n";
        } elsif ($ret == MZSCM_CANNOT_HANDLE) {
            dprint "$mod cannot handle $path.\n";
        } elsif ($ret == MZSCM_CAN_HANDLE) {
            dprint "$mod can handle $path.\n";
            return Mezzanine::SCM->new($mod);
        } elsif ($ret == MZSCM_WILL_HANDLE) {
            dprint "$mod is willing to handle $path.\n";
            if (! $will) {
                $will = $mod;
            }
            # Keep looking
        } else {
            dprint $mod . "->can_handle($path) returned $ret?!\n";
        }
    }
    if ($will) {
        return Mezzanine::SCM->new($will);
    }
    return undef;
}


### Private functions

1;
