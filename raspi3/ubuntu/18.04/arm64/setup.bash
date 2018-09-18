#!/bin/bash
# Construct a arm64+raspi2 installer.

# https://www.raspberrypi.org/forums/viewtopic.php?t=220079
# https://lb.raspberrypi.org/forums/viewtopic.php?t=215438
# https://wiki.ubuntu.com/ARM/RaspberryPi#Building_Raspberry_Pi_3_images

# set -e

source setup.env
build_root=`pwd`


mkdir -p $cache_dir

rm -rf $target_dir
rm -rf $scratch_dir

mkdir -p $target_dir
mkdir -p $scratch_dir

cd $cache_dir

# Download the iso
wget -N "http://cdimage.ubuntu.com/ubuntu/releases/$release/release/$iso_name"
# Extract the files from the iso to a directory server-raspi3
7z x -o$target_dir "$iso_name"

# Download the latest pi bootloader files
wget -N "http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/$raspberrypi_bootloader"
dpkg-deb -x $raspberrypi_bootloader /tmp/raspberrypi_bootloader
# Copy the bootloader files
cp /tmp/raspberrypi_bootloader/boot/* $target_dir

# The cmdline.txt, config.txt preseed files, (adjust as necessary)
cp -r $build_root/resources/* $target_dir


# Download wifi firmware
mkdir -p $cache_dir/wifi-firmware
cd $cache_dir/wifi-firmware
# Pi 3B
wget -N "https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43430-sdio.bin"
wget -N "https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43430-sdio.txt"
# Pi 3B+
wget -N "https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.bin"
wget -N "https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.clm_blob"
wget -N "https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm/brcmfmac43455-sdio.txt"
cp -r $cache_dir/wifi-firmware $target_dir/preseed/raspberry


# Download raspi2 kernel debs (these probably should be saved in pool)
mkdir -p $cache_dir/kernel-debs
mkdir -p $scratch_dir/pi-kernel
cd $cache_dir/kernel-debs
for i in "${linux_packages[@]}"
do
	 wget -N "http://ports.ubuntu.com/ubuntu-ports/pool/universe/l/linux-raspi2/$i";
	 # Extract vmlinuz-raspi2 and dtb files
	 dpkg-deb -x $i $scratch_dir/pi-kernel
done

version=$(ls $scratch_dir/pi-kernel/boot/vmlinuz*)
version=${version##*/}
version=${version#"vmlinuz-"}
echo version=$version

mkdir -p $target_dir/dtb
cp -r $scratch_dir/pi-kernel/lib/firmware/$version/device-tree/broadcom $target_dir/dtb
cp -r $scratch_dir/pi-kernel/boot/vmlinuz-$version $target_dir/install/vmlinuz-raspi2

# Create raspi2 initrd
zcat -k $target_dir/install/initrd.gz > $target_dir/install/initrd-raspi2

# Prepare to include wifi-firmware in initrd
mkdir -p $scratch_dir/pi-kernel/lib/firmware/brcm/
chmod 755 $scratch_dir/pi-kernel/lib/firmware/brcm/
cp $target_dir/preseed/raspberry/wifi-firmware/*sdio* $scratch_dir/pi-kernel/lib/firmware/brcm/
chmod 644 $scratch_dir/pi-kernel/lib/firmware/brcm/*

# evbug spams the logs, get rid
rm $scratch_dir/pi-kernel/lib/modules/$version/kernel/drivers/input/evbug.ko || true

# Generate modules.dep etc files
cd $target_dir
depmod -a -b $scratch_dir/pi-kernel -F $scratch_dir/pi-kernel/boot/System.map-$version $version

# # Remove unneeded files
rm -r $scratch_dir/pi-kernel/lib/modules/$version/initrd || true
rm -r $scratch_dir/pi-kernel/boot
rm -r $scratch_dir/pi-kernel/usr
rm -r $scratch_dir/pi-kernel/lib/firmware/$version

# Add raspi2 modules/firmware to the initrd and compress
find $scratch_dir/pi-kernel/.  | sed 's,^/tmp/scratch/pi-kernel\/,,g'| cpio -D $scratch_dir/pi-kernel -R +0:+0 -H newc -o -A -F $target_dir/install/initrd-raspi2
gzip $target_dir/install/initrd-raspi2

echo "Finished!"
echo "Copy all files (including the hidden .disk folder) in the server-raspi3 folder to a fat formatted usb drive."
