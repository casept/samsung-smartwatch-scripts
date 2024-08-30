set shell := ["bash", "-uc"]

default:
	@just --list

# Flash a kernel
@flash kernel:
	heimdall-grimler flash --BOOT {{kernel}}

# Build the downstream kernel in a container
build-downstream:
	#!/usr/bin/env bash
	set -exo pipefail
	docker run --entrypoint "/bin/bash"  \
		-v "$(pwd)/linux-exynos3250-common:/src" --rm -t docker.io/casept/rinato-downstream-build \
		-c 'make -C /src ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage'
	cp "linux-exynos3250-common/arch/arm/boot/zImage" "zImage-downstream"

# Get a shell into an environment suitable for building or configuring the downstream kernel
edit-downstream:
	#!/usr/bin/env bash
	set -exo pipefail
	docker run --entrypoint /bin/bash \
	-v $(pwd)/linux-exynos3250-common:/src --rm -it docker.io/casept/rinato-downstream-build

# Build and flash the downstream kernel
downstream: build-downstream (flash "zImage-downstream")

# Build the mainline kernel
build-mainline:
	#!/usr/bin/env bash
	set -eo pipefail

	# Add toolchain to PATH
	export PATH="$PATH:$(pwd)/../toolchain-mainline/bin"

	# Build
	pushd "linux-mainline"
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules
	make ARCH=arm INSTALL_MOD_PATH="mainline-modules" CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules_install
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) dtbs
	# Fails for production kernel without GDB enabled, ignore that
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) scripts_gdb || true

	DTB="exynos3250-rinato.dts"
	# S-Boot is too old to support device tree, use concat dtree
	cat arch/arm/boot/zImage "arch/arm/boot/dts/samsung/$DTB" > "../zImage-with-dtree"
	popd

	# Remove non-transferable symlink from kernel modules dir
	unlink "mainline-modules/*/build" || true

# Build and flash the mainline kernel (via download mode)
mainline-download: build-mainline
	heimdall-grimler flash --BOOT ./zImage-with-dtree

# Build and flash the mainline kernel (via SSH to a booted system)
mainline-flash: build-mainline
	# DANGER: Getting this wrong may lead to a wiped bootloader and brick!
	scp ./zImage-with-dtree root@rinato:/dev/mmcblk0p5
	ssh root@rinato reboot

# Decode a stracktrace from the mainline kernel
decode-stacktrace-mainline path:
	./decode-stacktrace-mainline.sh {{path}}

# Flash the unmodified stock kernel binary
flash-stock:
	./flash-stock.sh

# Provide a route to the Internet for the watch
internet:
	./internet.sh
		
# Install kernel modules for the currently-built mainline kernel onto the watch
update-modules:
	./update-modules.sh

# Assign an IP address to the watch when running Debian
ip-debian:
	#!/usr/bin/env bash
	while true; do sudo ifconfig usb0 192.168.0.101 netmask 255.255.255.0; sleep 5; done

# Assign an IP address to the watch when running AsteroidOS (non-standard IP to avoid conflict with home network)
ip-asteroid:
	#!/usr/bin/env bash
	while true; do sudo ifconfig enp7s0f4u2 192.168.3.15 netmask 255.255.255.0; sleep 5; done

# Expose a watch running AsteroidOS to the remote build server
expose-asteroid:
	#!/usr/bin/env bash
	ssh -R 2022:192.168.3.15:22 -N $BUILDSERVER

# Unload and load a kernel module that's being iteratively worked on
@test-module path name:
	./test-module.sh {{path}} {{name}}

# Test the bluetooth driver
test-bt: (test-module "drivers/bluetooth/hci_uart.ko" "hci_uart")

# Test the Wi-Fi driver
test-wifi: (test-module "drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko" "brcmfmac")

# Test the display panel driver
test-panel: (test-module "drivers/gpu/drm/panel/panel-samsung-s6e63j0x03.ko" "panel-samsung-s6e63j0x03")

# Test the IR blaster driver
test-ir: (test-module "drivers/misc/ice4_irda.ko" "ice4_irda")

# Test the sensorhub core driver
test-ssp: (test-module "drivers/iio/common/ssp_sensors/sensorhub.ko" "sensorhub")

# Test the sensorhub IIO driver
test-ssp-iio: (test-module "drivers/iio/common/ssp_sensors/ssp_iio.ko" "ssp_iio")

# Decompile the IR FPGA bitstream
decomp-fpga:
	iceunpack fpga/bitstream.fw fpga/bitstream.asc
	icetime -d lp1k -o fpga/bitstream.v -j fpga/bitstream.json fpga/bitstream.asc

# Launch a GDB session for debugging the kernel via UART cable
debug:
	zellij -c kgdb.kdl
