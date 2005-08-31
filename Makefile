# Makefile to build mezz tarball and RPM's from scratch.
#
# $Id: Makefile,v 1.1 2005/08/31 19:25:41 mej Exp $
#

all: package

mezzdir:
	test -d Mezzanine || ln -sv mod Mezzanine

package: mezzdir
	perl -I$${PWD} ./pkgtool -b
