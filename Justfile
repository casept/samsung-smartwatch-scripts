set shell := ["bash", "-uc"]

default:
	@just --list

# Flash a kernel
@flash kernel:
	heimdall flash --BOOT {{kernel}}

# Build the downstream kernel in a container
downstream-build:
	#!/usr/bin/env bash
	set -exo pipefail
	docker run --entrypoint "/bin/bash"  \
		-v "$(pwd)/linux-exynos3250-common:/src" --rm -t docker.io/casept/rinato-downstream-build \
		-c 'make -C /src ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage'
	cp "linux-exynos3250-common/arch/arm/boot/zImage" "zImage-downstream"

# Get a shell into an environment suitable for building or configuring the downstream kernel
downstream-edit:
	#!/usr/bin/env bash
	set -exo pipefail
	docker run --entrypoint /bin/bash \
	-v $(pwd)/linux-exynos3250-common:/src --rm -it docker.io/casept/rinato-downstream-build

# Build and flash the downstream kernel for Rinato
downstream-download: downstream-build (flash "zImage-downstream")

# Build the mainline kernel for Rinato
mainline-build:
	#!/usr/bin/env bash
	set -eo pipefail

	# Build
	pushd "linux-samsung-smartwatch"
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) vmlinux
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules
	make ARCH=arm INSTALL_MOD_PATH="mainline-modules" CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules_install
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) dtbs
	# Fails for production kernel without GDB enabled, ignore that
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) scripts_gdb || true

	DTB="exynos3250-rinato.dtb"
	# S-Boot is too old to support device tree, use concat dtree
	cat arch/arm/boot/zImage "arch/arm/boot/dts/samsung/$DTB" > "../zImage-with-dtree"
	popd

	# Remove non-transferable symlink from kernel modules dir
	unlink "mainline-modules/*/build" || true

# Build and flash the mainline kernel (via download mode)
mainline-download *flags: mainline-build
	heimdall flash {{flags}} --BOOT ./zImage-with-dtree

# Build the mainline kernel for Artik5 eval
mainline-build-artik:
	#!/usr/bin/env bash
	set -eo pipefail

	# Build
	pushd "linux-samsung-smartwatch"
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) vmlinux
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) zImage
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules
	make ARCH=arm INSTALL_MOD_PATH="mainline-modules" CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules_install
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) dtbs
	# Fails for production kernel without GDB enabled, ignore that
	make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) scripts_gdb || true

	DTB="exynos3250-artik5-eval.dtb"
	# U-Boot is too old to support device tree in boot.img, use concat dtree
	cat arch/arm/boot/zImage "arch/arm/boot/dts/samsung/$DTB" > "../zImage-with-dtree-artik"
	popd
	mkbootimg --os_version 4 --kernel zImage-with-dtree-artik -o bootimg-artik.img

	# Remove non-transferable symlink from kernel modules dir
	unlink "mainline-modules/*/build" || true

# Build and flash the mainline kernel (via download mode)
mainline-download-artik: mainline-build-artik
	fastboot boot bootimg-artik.img

# Build and flash the mainline kernel (via SSH to a booted system)
mainline-flash: mainline-build
	# DANGER: Getting this wrong may lead to a wiped bootloader and brick!
	scp ./zImage-with-dtree root@rinato:/dev/mmcblk0p5
	ssh root@rinato reboot

# Decode a stracktrace from the mainline kernel
mainline-decode-stacktrace path:
	./decode-stacktrace-mainline.sh {{path}}

# Flash the unmodified stock kernel binary
stock-flash:
	./flash-stock.sh

# Provide a route to the Internet for the watch
internet:
	./scripts/internet.sh

# Install kernel modules for the currently-built mainline kernel onto the watch
mainline-update-modules:
	./scripts/update-modules.sh

# Assign an IP address to the host USB network interface connected to the watch
ip:
	#!/usr/bin/env bash
	while true; do sudo ifconfig enp7s0f4u2u2 192.168.2.14 netmask 255.255.255.0; sleep 5; done

# Expose a watch running AsteroidOS to the remote build server
expose-asteroid:
	#!/usr/bin/env bash
	ssh -R 2022:192.168.3.15:22 -N $BUILDSERVER

# Unload and load a kernel module that's being iteratively worked on
@test-module path name:
	./test-module.sh {{path}} {{name}}

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

# Dump bootloader logs to bootloader.log
dump-bootloader-logs:
    samupload range 0x46000000 0x46200000
    mv range.bin bootloader.log
    # Clean out non-printable garbage memory
    perl -pi -e 's/[^[:ascii:]]//g' bootloader.log
    cat bootloader.log

# Dump kernel pstore to pstore.bin
dump-pstore:
    samupload range 0x51000000 0x51100000
    mv range.bin pstore.bin

# Build mainline U-Boot for Artik5
mainline-uboot-artik-build:
	cd u-boot-samsung-smartwatch && make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc)

# Build downstream U-Boot for Artik5
downstream-uboot-artik-build:
	cd u-boot-artik && make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc)

# Upload mainline U-Boot to ARTIK5's RAM and execute it
mainline-uboot-artik: mainline-uboot-artik-build
	./scripts/artik5-boot-u-boot.exp ./u-boot-samsung-smartwatch/u-boot.bin

# Upload downstream U-Boot to ARTIK5's RAM and execute it
downstream-uboot-artik: downstream-uboot-artik-build
	./scripts/artik5-boot-u-boot.exp ./u-boot-artik/u-boot.bin

# Debootstrap Debian 13 (trixie) for armhf and pack it into an ext4 image for the userdata partition
debian size="3068133376" out="debian.img": mainline-build
	#!/usr/bin/env bash
	set -exo pipefail
	ROOTFS="debian-rootfs"
	MODULES="debian-modules"
	trap 'sudo rm -rf "$ROOTFS" "$MODULES"' EXIT
	sudo rm -rf "$ROOTFS" "$MODULES"

	PACKAGES=(
		openssh-server rsync systemd-timesyncd
		# debugging and stress testing
		stress-ng htop strace gdb linux-perf util-linux-extra python3 iperf3
		libiio-utils i2c-tools
		# camera, video codecs and IR (ir-ctl)
		v4l-utils gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
		# gstreamer1.0-plugins-bad pulls in libonnxruntime1.21, which depends on the
		# virtual libre2-11-absl20240722 (old name of libre2-11). debootstrap's dependency
		# resolver can't follow Provides, so the real package has to be requested explicitly.
		libre2-11
		# runtime dependencies of libcamera
		libyaml-0-2 libgnutls30t64 libudev1 libevent-2.1-7t64 libevent-pthreads-2.1-7t64
		libdrm2 libtiff6 libdw1t64 libunwind8 libegl1 libgles2
		# GPU and display
		kmscube glmark2-es2-drm
		# audio
		alsa-utils alsa-ucm-conf pipewire pipewire-bin pipewire-alsa pipewire-pulse wireplumber
		pulseaudio-utils dbus-user-session libspa-0.2-modules
		# WiFi and Bluetooth
		iw wpasupplicant bluez bluez-hcidump
		# bluez and libpam-systemd depend on the virtual default-dbus-system-bus,
		# which debootstrap can't resolve, so request its provider explicitly.
		dbus
	)
	# qemu-arm-static must be registered with binfmt_misc (F flag) for the second stage to run in the chroot
	sudo "$(command -v debootstrap)" --arch=armhf --include="$(IFS=,; echo "${PACKAGES[*]}")" \
		trixie "$ROOTFS" http://deb.debian.org/debian

	echo "root:root" | sudo chroot "$ROOTFS" chpasswd
	echo "PermitRootLogin yes" | sudo tee "$ROOTFS/etc/ssh/sshd_config.d/root-login.conf" >/dev/null
	sudo install -d -m 700 "$ROOTFS/root/.ssh"
	sudo install -m 600 "$HOME/.ssh/id_ed25519.pub" "$ROOTFS/root/.ssh/authorized_keys"
	echo "rinato" | sudo tee "$ROOTFS/etc/hostname" >/dev/null
	echo "LABEL=debian / ext4 errors=remount-ro 0 1" | sudo tee "$ROOTFS/etc/fstab" >/dev/null
	echo "nameserver 1.1.1.1" | sudo tee "$ROOTFS/etc/resolv.conf" >/dev/null
	# USB gadget ethernet, the host side is 192.168.2.1 (NAT-shared for internet access)
	printf "auto usb0\nallow-hotplug usb0\niface usb0 inet static\n    address 192.168.2.15/24\n    gateway 192.168.2.1\n" \
		| sudo tee "$ROOTFS/etc/network/interfaces.d/usb0" >/dev/null
	sudo chroot "$ROOTFS" systemctl enable systemd-timesyncd
	sudo chroot "$ROOTFS" apt-get clean

	make -C linux-samsung-smartwatch ARCH=arm CROSS_COMPILE=arm-none-eabi- \
		INSTALL_MOD_PATH="$(pwd)/$MODULES" modules_install
	rm -f "$MODULES"/lib/modules/*/build
	sudo mkdir -p "$ROOTFS/usr/lib/modules"
	sudo cp -r --no-preserve=ownership "$MODULES/lib/modules/." "$ROOTFS/usr/lib/modules/"

	sudo mkdir -p "$ROOTFS/usr/lib/firmware" "$ROOTFS/usr/share/alsa/ucm2"
	for f in firmware/rinato/*; do
		[ "${f##*/}" = ucm2 ] && continue
		sudo cp -r --no-preserve=ownership "$f" "$ROOTFS/usr/lib/firmware/"
	done
	sudo cp -r --no-preserve=ownership firmware/rinato/ucm2/. "$ROOTFS/usr/share/alsa/ucm2/"

	sudo mkdir -p "$ROOTFS/var/lib/systemd/linger"
	sudo touch "$ROOTFS/var/lib/systemd/linger/root"
	for u in pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service; do
		sudo mkdir -p "$ROOTFS/root/.config/systemd/user/$u.d"
		printf "[Unit]\nConditionUser=\n" | sudo tee "$ROOTFS/root/.config/systemd/user/$u.d/allow-root.conf" >/dev/null
	done
	sudo chroot "$ROOTFS" systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

	rm -f "{{out}}"
	truncate -s "{{size}}" "{{out}}"
	# Run as root so mkfs.ext4 -d preserves file ownership from the rootfs
	sudo mkfs.ext4 -F -L debian -E no_copy_xattrs -d "$ROOTFS" "{{out}}"
	sudo chown "$(id -u):$(id -g)" "{{out}}"

debian-download: debian (mainline-download "--no-reboot")
	heimdall flash --resume --USER debian.img
