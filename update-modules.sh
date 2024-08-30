#!/usr/bin/env bash
set -eo pipefail

MACHINE=rinato

# Add toolchain to PATH
SCRIPT_PATH=$(dirname $(realpath -s $0))
export PATH="$PATH:$SCRIPT_PATH/../toolchain-mainline/bin"

echo "Cleaning staging dir..."
rm -rf "$SCRIPT_PATH/../mainline-modules/lib/modules/"
mkdir "$SCRIPT_PATH/../mainline-modules/lib/modules/"

echo "Building modules..."
pushd "$SCRIPT_PATH/../linux-mainline"
make ARCH=arm INSTALL_MOD_PATH="$SCRIPT_PATH/../mainline-modules" CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules_install

echo "Removing old modules..."
ssh root@$MACHINE rm -rf "/lib/modules/"

echo "Copying modules..."
rsync --compress -av "$SCRIPT_PATH/../mainline-modules/lib/modules/" root@$MACHINE:/lib/modules/
