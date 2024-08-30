#!/usr/bin/env bash
set -eo pipefail

# Add toolchain to PATH
SCRIPT_PATH=$(dirname $(realpath -s $0))
export PATH="$PATH:$SCRIPT_PATH/../toolchain-mainline/bin"

KERNEL_VERSION="6.8.0-rc1-next-20240125-g18dc9978d34f-dirty"

# Build
echo "Building modules..."
pushd "$SCRIPT_PATH/../linux-mainline"
make ARCH=arm CROSS_COMPILE=arm-none-eabi- -j$(nproc) modules

# Copy kernel module
echo "Copying module..."
scp "$SCRIPT_PATH/.././linux-mainline/drivers/iio/common/ssp_sensors/sensorhub.ko" "root@rinato:/lib/modules/$KERNEL_VERSION/kernel/drivers/iio/common/ssp_sensors/sensorhub.ko"
scp "$SCRIPT_PATH/.././linux-mainline/drivers/iio/common/ssp_sensors/ssp_iio.ko" "root@rinato:/lib/modules/$KERNEL_VERSION/kernel/drivers/iio/common/ssp_sensors/ssp_iio.ko"
scp "$SCRIPT_PATH/.././linux-mainline/drivers/iio/health/ssp_hrm_sensor.ko" "root@rinato:/lib/modules/$KERNEL_VERSION/kernel/drivers/iio/health/ssp_hrm_sensor.ko"
scp "$SCRIPT_PATH/.././linux-mainline/drivers/iio/health/ssp_hrm_sensor_raw.ko" "root@rinato:/lib/modules/$KERNEL_VERSION/kernel/drivers/iio/health/ssp_hrm_sensor_raw.ko"

# Reload module and dependents
echo "Unloading..."
ssh root@rinato modprobe -r ssp_hrm_sensor || true
ssh root@rinato modprobe -r ssp_hrm_sensor_raw || true
ssh root@rinato modprobe -r ssp_iio || true
ssh root@rinato modprobe -r sensorhub || true
echo "Loading..."
sudo depmod -a
ssh root@rinato modprobe sensorhub
ssh root@rinato modprobe ssp_iio
ssh root@rinato modprobe ssp_hrm_sensor
ssh root@rinato modprobe ssp_hrm_sensor_raw

# Observe debug output
ssh rinato dmesg -w
