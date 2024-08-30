#!/usr/bin/env bash
set -eo pipefail

SCRIPT_PATH=$(dirname $(realpath -s $0))

BUILDDIR="/home/casept/build/asteroid/build/tmp-glibc/deploy/images/rinato"
BOOTIMG="$SCRIPT_PATH/../zImage-asteroid"
ROOTIMG="$SCRIPT_PATH/../rootfs-asteroid.img"

# Copy artifacts
echo "Downloading kernel image..."
scp "$BUILDSERVER:$BUILDDIR/zImage-exynos3250-rinato.dtb.bin" "$BOOTIMG"

echo "Compressing rootfs..."
ssh "$BUILDSERVER" zstd -f "$BUILDDIR/asteroid-image-rinato.rootfs.ext4"
echo "Downloading rootfs..."
scp "$BUILDSERVER:$BUILDDIR/asteroid-image-rinato.rootfs.ext4.zst" "$ROOTIMG.zst"
ssh "$BUILDSERVER" rm "$BUILDDIR/asteroid-image-rinato.rootfs.ext4.zst"
echo "Unpacking rootfs..."
unzstd -f "$ROOTIMG.zst"
rm "$ROOTIMG.zst"

# Flash (via Heimdall)
echo "Flashing kernel..."
heimdall-grimler flash --no-reboot --BOOT "$BOOTIMG"
echo "Flashing rootfs..."
heimdall-grimler flash --resume --USER "$ROOTIMG"
echo "Done!"
