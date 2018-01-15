#!/bin/sh
PRG="$0"
# Need this for relative symlinks.
while [ -h "$PRG" ] ; do
    ls=`ls -ld "$PRG"`
    link=`expr "$ls" : '.*-> \(.*\)$'`
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=`dirname "$PRG"`"/$link"
    fi
done

ROOT=`dirname "$PRG"`
ROOT=`cd "$ROOT/..";pwd`

cd "$ROOT"

if echo "$1" | grep -vq '[0-9][0-9]*\(\.[0-9][0-9]*\)*' ; then
  echo "version not set"
  exit 1
fi

ls | grep yam- | while read pkg; do
  sed -i.bak "s|version:\(  *\)[0-9][0-9]*\(\.[0-9][0-9]*\)*|version:\1$1|" $pkg/$pkg.cabal
  rm -f $pkg/$pkg.cabal.bak
done