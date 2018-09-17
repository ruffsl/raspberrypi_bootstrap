#!/bin/bash
# Construct a arm64+raspi2 installer.

# set -e

source setup.env
build_root=`pwd`

# Download the iso
wget -N "http://cdimage.ubuntu.com/ubuntu/releases/$release/release/$iso_name"

# Extract the files from the iso to a directory server-raspi3
7z x -oserver-raspi3 "$iso_name"

# Download the latest pi bootloader files
wget -N "http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/$raspberrypi_bootloader"
dpkg-deb -x $raspberrypi_bootloader /tmp/pi-bootloader

cd server-raspi3

# Copy the bootloader files
cp /tmp/pi-bootloader/boot/* .

# The cmdline.txt (adjust as necessary)
cp $build_root/resources/cmdline.txt .

# The config.txt
cp $build_root/resources/config.txt .

# Run 'unix2dos config.txt' if you want it readable in windows

# Create preseed files
mkdir -p preseed
cd preseed
cp $build_root/resources/preseed/pi.seed .


mkdir -p raspberry
cd raspberry


cp $build_root/resources/preseed/raspberry/pi_recipe .

cp $build_root/resources/preseed/raspberry/pi_partman_command .

cp $build_root/resources/preseed/raspberry/pi_late_command .

# Download wifi firmware
mkdir -p wifi-firmware
cd wifi-firmware
# Pi 3B
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43430-sdio.bin
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43430-sdio.txt
# Pi 3B+
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.bin
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.clm_blob
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.txt

# Download raspi2 kernel debs (these probably should be saved in pool)
cd ..
mkdir -p kernel-debs
cd kernel-debs

for i in "${linux_packages[@]}"
do
	 wget -N "http://ports.ubuntu.com/ubuntu-ports/pool/universe/l/linux-raspi2/$i";
	 # Extract vmlinuz-raspi2 and dtb files
	 dpkg-deb -x $1 /tmp/pi-kernel
done

# dpkg-deb -x *.deb /tmp/pi-kernel
cd ../../../
version="$(ls /tmp/pi-kernel/boot/vmlinuz* | sed 's,^\/tmp\/pi-kernel\/boot\/vmlinuz-,,g')"
cp /tmp/pi-kernel/lib/firmware/$version/device-tree/broadcom/bcm2710*.dtb .
cp /tmp/pi-kernel/boot/vmlinuz-$version install/vmlinuz-raspi2

# Create raspi2 initrd
zcat -k install/initrd.gz > install/initrd-raspi2

# Prepare to include wifi-firmware in initrd
mkdir -p /tmp/pi-kernel/lib/firmware/brcm/
chmod 755 /tmp/pi-kernel/lib/firmware/brcm/
cp preseed/raspberry/wifi-firmware/*sdio* /tmp/pi-kernel/lib/firmware/brcm/
chmod 644 /tmp/pi-kernel/lib/firmware/brcm/*

# evbug spams the logs, get rid
rm /tmp/pi-kernel/lib/modules/$version/kernel/drivers/input/evbug.ko || true

# Generate modules.dep etc files
depmod -a -b /tmp/pi-kernel -F /tmp/pi-kernel/boot/System.map-$version $version

# Remove unneeded files
rm -r /tmp/pi-kernel/lib/modules/$version/initrd || true
rm -r /tmp/pi-kernel/boot
rm -r /tmp/pi-kernel/usr
rm -r /tmp/pi-kernel/lib/firmware/$version

# Add raspi2 modules/firmware to the initrd and compress
find /tmp/pi-kernel/.  | sed 's,^/tmp/pi-kernel\/,,g'| cpio -D /tmp/pi-kernel -R +0:+0 -H newc -o -A -F install/initrd-raspi2
gzip install/initrd-raspi2

echo "Finished!"
echo "Copy all files (including the hidden .disk folder) in the server-raspi3 folder to a fat formatted usb drive."
