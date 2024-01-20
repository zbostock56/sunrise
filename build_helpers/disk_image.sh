#!/bin/bash

# Exit if any part of build returns non-zero exit code
set -e

TARGET=$1
SIZE=$2
STAGE1_STAGE2_LOCATION_OFFSET=408
DISK_SECTOR_COUNT=$(( (${SIZE} + 511 ) / 512 ))
DISK_PART1_BEGIN=2048
DISK_PART1_END=$(( ${DISK_SECTOR_COUNT} - 1 ))

# Generate .raw file
echo "Generating disk image ${TARGET} (${DISK_SECTOR_COUNT} sectors)"
dd if=/dev/zero of=$TARGET bs=512 count=${DISK_SECTOR_COUNT} >/dev/null

# Create partition table
echo "Creating partition table"
parted -s $TARGET mklabel msdos
parted -s $TARGET mkpart primary ${DISK_PART1_BEGIN}s ${DISK_PART1_END}s
parted -s $TARGET set 1 boot on

STAGE2_SIZE=$(stat -c%s ${BUILD_DIR}/stage2.bin)
echo ${STAGE2_SIZE}
STAGE2_SECTORS=$(( ( ${STAGE2_SIZE} + 511) / 512 ))
echo ${STAGE2_SECTORS}

if [ ${STAGE2_SECTORS} \> $(( ${DISK_PART1_BEGIN} - 1)) ]; then
    echo "stage2 sized too large!"
    exit 2
fi 

dd if=${BUILD_DIR}/stage2.bin of=$TARGET conv=notrunc bs=512 seek=1

# Create loopback device
DEVICE=$(sudo losetup -fP --show ${TARGET})
echo "Created loopback device: ${DEVICE}"
TARGET_PARTITION="${DEVICE}p1"

# Create file system
echo "Formatting ${TARGET_PARTITION}..."
sudo mkfs.fat -n "NBOS" $TARGET_PARTITION >/dev/null

# Install bootloader
echo "Installing bootloader on ${TARGET_PARTITION}"
sudo dd if=${BUILD_DIR}/stage1.bin of=$TARGET_PARTITION conv=notrunc bs=1 count=3 2>&1 >/dev/null
sudo dd if=${BUILD_DIR}/stage1.bin of=$TARGET_PARTITION conv=notrunc bs=1 seek=90 skip=90 2>&1 >/dev/null

# Write LBA address of stage2 to bootloader
sudo echo "01 00 00 00" | xxd -r -p | sudo dd of=$TARGET_PARTITION conv=notrunc bs=1 seek=$STAGE1_STAGE2_LOCATION_OFFSET
sudo printf "%x" ${STAGE2_SECTORS} | sudo xxd -r -p | sudo dd of=$TARGET_PARTITION conv=notrunc bs=1 seek=$(( $STAGE1_STAGE2_LOCATION_OFFSET + 4 ))

# copy files
echo "Copying files to ${TARGET_PARTITION} (mounted on /tmp/nbos)..."
sudo mkdir -p /tmp/nbos
sudo mount ${TARGET_PARTITION} /tmp/nbos
sudo cp ${BUILD_DIR}/kernel.bin /tmp/nbos
#cp test.txt /tmp/nbos
#mkdir /tmp/nbos/test
#cp test.txt /tmp/nbos/test
sudo umount /tmp/nbos

# destroy loopback device
sudo losetup -d ${DEVICE}