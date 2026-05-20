#!/bin/bash
set -e

rm -rf $DEST
mkdir -p $DEST

#### copy exe ####
cp $GITHUB_WORKSPACE/build/Throne.exe $DEST/TaliabuVPN2026v2.exe
cp $GITHUB_WORKSPACE/build/Throne.pdb $DEST/TaliabuVPN2026v2.pdb || true

cd download-artifact
cd *$DEST_SUFFIX
tar xvzf artifacts.tgz -C ../../
cd ../..
