# Mezzanine Subversion SCM Perl Module
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
# $Id: Subversion.pm,v 1.3 2004/06/24 23:31:43 mej Exp $
#

package Mezzanine::SCM::Subversion;
use Mezzanine::Util;
use Mezzanine::SCM::Global;

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

# Constants

sub
new($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my $type = shift;

    bless($self, $class);
    return $self;
}

sub
can_handle($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $path = shift;

    dprint "Subversion::can_handle():  $proto $class $path\n";
    return MEZZANINE_CANNOT_HANDLE;
}


### Private functions

1;
