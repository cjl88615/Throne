#!/bin/bash
set -e

rm -rf $DEST
mkdir -p $DEST

#### copy exe ####
cp $GITHUB_WORKSPACE/build/Throne.exe $DEST/TaliabuVPN.exe
cp $GITHUB_WORKSPACE/build/Throne.pdb $DEST/TaliabuVPN.pdb || true

source "$(dirname "$0")/extract_core_artifact.sh"
