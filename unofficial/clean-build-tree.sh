#!/bin/sh

PATH=/bin:/usr/bin

SRPM_DIR=$HOME/caos/cAos-1/srpms/
CREATION_DIR=/os/build.mezzanine
CREATION_TRASH=/os/caos-old-build-trees

test -d $CREATION_TRASH || mkdir -p $CREATION_TRASH

find $CREATION_DIR -type d -mindepth 1 -maxdepth 1 | sort | while read dir; do
   NAME=`basename $dir`
   if [ ! -f "$SRPM_DIR/$NAME.src.rpm" -a ! -f "$SRPM_DIR/$NAME.nosrc.rpm" ]; then
      echo "Scrubbing obsolete package $NAME"
      tar -jcf "$CREATION_TRASH/$NAME.tar.bz2" $dir 2>/dev/null && rm -rf $dir 2>/dev/null
   fi
done
