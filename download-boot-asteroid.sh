#!/usr/bin/env bash
set -eo pipefail

SCRIPT_PATH=$(dirname $(realpath -s $0))

BUILDDIR="/home/casept/build/asteroid/build/tmp-glibc/deploy/images/rinato"
BOOTIMG="$SCRIPT_PATH/../zImage-asteroid"
ROOTIMG="$SCRIPT_PATH/../rootfs-asteroid.img"

# Copy artifacts
echo "Downloading kernel image..."
rsync -zaPL "$BUILDSERVER:$BUILDDIR/zImage-rinato.bin" "$BOOTIMG"

echo "Downloading rootfs..."
rsync -zaPL "$BUILDSERVER:$BUILDDIR/asteroid-image-rinato.rootfs.ext4" "$ROOTIMG"

# Flash (via Heimdall)
echo "Flashing kernel..."
heimdall-grimler flash --no-reboot --BOOT "$BOOTIMG"
echo "Flashing rootfs..."
heimdall-grimler flash --resume --USER "$ROOTIMG"
echo "Done!"
