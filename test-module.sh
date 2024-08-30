#!/usr/bin/env bash
set -eo pipefail

# Add toolchain to PATH
SCRIPT_PATH=$(dirname $(realpath -s $0))
export PATH="$PATH:$SCRIPT_PATH/../toolchain-mainline/bin"

# Build
echo "Building modules..."
pushd "$SCRIPT_PATH/../linux-mainline"
make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules

# Copy kernel module
echo "Copying module..."
scp "$SCRIPT_PATH/../linux-mainline/$1" "root@rinato:/lib/modules/6.10.0-rc5-next-20240627-gcdce41c4a6c6-dirty/kernel/$1"

# Reload module
echo "Unloading..."
ssh root@rinato modprobe -r "$2" || true
echo "Loading..."
ssh root@rinato modprobe "$2"

# Observe debug output
ssh rinato dmesg -w
