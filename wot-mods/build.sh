#!/bin/bash
VERSION=$1

mkdir -p build/$VERSION/scripts/client/mods

for mod in $VERSION/scripts/client/mods/*.py; do
    pycompile -V 2.6 $mod;
    SRC="$VERSION/scripts/client/mods/`basename $mod .py`.pyc";
    DST="build/$VERSION/scripts/client/mods/";
    cp $SRC $DST;
done

# copy the statterbox mod as well 
SRCMASK="/home/ben/projects/statterbox/wot-mods/build/$VERSION/scripts/client/mods/*.pyc"
for modfile in $SRCMASK; do
    cp -v $modfile "./build/$VERSION/scripts/client/mods/`basename $modfile`";
done
# make a zip file that contains the mod(s)
cd build/$VERSION
zip -r wot-replays-$VERSION.zip ./scripts/
mv *.zip ..
cd ../..
