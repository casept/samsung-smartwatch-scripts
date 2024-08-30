#!/usr/bin/env bash
set -eo pipefail

SCRIPT_PATH=$(dirname $(realpath -s $0))

BUILDDIR="~/asteroid/build/tmp-glibc/deploy/images/emulator"
BOOTIMG="$SCRIPT_PATH/../bzImage-enulator"
ROOTIMG="$SCRIPT_PATH/../rootfs-emulator.img"

# Copy artifacts
echo "Downloading kernel image..."
ssh "$BUILDSERVER" cp "$BUILDDIR/bzImage--*-emulator-*.bin" "$BUILDDIR/bzImage-emulator.bin.tmp"
scp "$BUILDSERVER:$BUILDDIR/bzImage-emulator.bin.tmp" "$BOOTIMG"
ssh "$BUILDSERVER" rm "$BUILDDIR/bzImage-emulator.bin.tmp"

echo "Compressing rootfs..."
ssh "$BUILDSERVER" zstd -f "$BUILDDIR/asteroid-image-emulator-*.rootfs.ext4"
echo "Downloading rootfs..."
scp "$BUILDSERVER:$BUILDDIR/asteroid-image-emulator-*.rootfs.ext4.zst" "$ROOTIMG.zst"
ssh "$BUILDSERVER" rm "$BUILDDIR/asteroid-image-emulator-*.rootfs.ext4.zst"
echo "Unpacking rootfs..."
unzstd -f "$ROOTIMG.zst"
rm "$ROOTIMG.zst"

qemu-system-x86_64 -enable-kvm -kernel $BOOTIMG \
    -device virtio-vga-gl \
    -net nic -net user,hostfwd=tcp::2222-:22 \
    -drive format=raw,file="$ROOTIMG" \
    -m 512 \
    -display sdl,gl=on \
    -cpu qemu64,+ssse3,+sse4.1,+sse4.2 \
    -device usb-mouse -machine usb=on \
    --append "verbose root=/dev/sda rw mem=512M video=800x800"
