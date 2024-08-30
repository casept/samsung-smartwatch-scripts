#!/usr/bin/env bash
set -eo pipefail

# Add toolchain to PATH
SCRIPT_PATH=$(dirname $(realpath -s $0))
export PATH="$PATH:$SCRIPT_PATH/../toolchain-mainline/bin"

# Build
pushd "$SCRIPT_PATH/../linux-mainline"
make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage
make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules
make ARCH=arm INSTALL_MOD_PATH="$SCRIPT_PATH/../mainline-modules" CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules_install
make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) dtbs
# Fails for production kernel without GDB enabled, ignore that
make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) scripts_gdb || true

# make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) -C tools/perf

DTB="exynos3250-rinato.dtb"
# S-Boot is too old to support device tree, use concat dtree
cat arch/arm/boot/zImage "arch/arm/boot/dts/samsung/$DTB" > "../zImage-with-dtree"
popd

# Remove non-transferable symlink from kernel modules dir
unlink "$SCRIPT_PATH/../mainline-modules/*/build" || true

# Flash (via Heimdall)
IMG="$SCRIPT_PATH/../zImage-with-dtree"
heimdall-grimler flash --BOOT "$IMG"
