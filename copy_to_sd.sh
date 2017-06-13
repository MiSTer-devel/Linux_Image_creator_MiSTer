#!/bin/bash

DIR=$PWD
SRCDIR=${DIR}
DSTDIR=/media/rootfs

if [[ $EUID -ne 0 ]]; then
   echo "This script requires root rights. Quiting..."
   echo ""
   exit 0
fi

if [ -z $1 ]; then
   echo "No SD device specified"
   exit 0
fi

if [ ! -e $1 ] || [ ! -e ${1}3 ] || [ ! -e ${1}2 ] || [ ! -e ${1}1 ] ; then
   echo "Specified device doesn't look like correct SD card"
   exit 0
fi

echo ""
echo "Unmounting some partitions (errors are ok here)..."
umount ${DSTDIR}

echo "Formatting Linux partition..."
mkfs.ext4 -L rootfs ${1}2 || exit 0
echo ""

echo "Copying U-Boot loader..."
dd if=${SRCDIR}/u-boot-with-spl.sfp of=${1}3

echo "Mounting Linux partition..."
if [ ! -d ${DSTDIR} ]; then
   mkdir -p ${DSTDIR} || exit 0
fi
mount ${1}2 ${DSTDIR} || exit 0

echo "Copying main rootfs files..."
tar xfp ${SRCDIR}/rootfs.tar.gz --warning=no-timestamp -C ${DSTDIR} || exit 0

echo "Copying kernel modules rootfs files..."
tar xfp ${SRCDIR}/modules.tar.gz --strip-components=2 --warning=no-timestamp -C ${DSTDIR}/lib || exit 0

echo "Copying devices firmwares..."
mkdir -p ${DSTDIR}/lib/firmware || exit 0
tar xfp ${SRCDIR}/firmware.tar.gz --warning=no-timestamp -C ${DSTDIR}/lib/firmware || exit 0

echo "Copying additional modifications..."
cp -f -r ${SRCDIR}/addon/* ${DSTDIR} || exit 0
mkdir -p ${DSTDIR}/media/fat || exit 0
echo "/dev/mmcblk0p1 /media/fat auto defaults,sync,nofail 0 0" >>${DSTDIR}/etc/fstab
sed 's/getty/agetty/g' -i ${DSTDIR}/etc/inittab
sed 's/115200//g' -i ${DSTDIR}/etc/inittab
sed '/::sysinit:\/bin\/mount \-a/a ::sysinit:\/etc\/resync\ \&' -i ${DSTDIR}/etc/inittab
sed '/::sysinit:\/bin\/mount \-a/a ::sysinit:\/media\/fat\/MiSTer\ \&' -i ${DSTDIR}/etc/inittab
sed '/PATH/ s/$/:\/media\/fat/' -i ${DSTDIR}/etc/profile
cat >> ${DSTDIR}/etc/profile <<- __EOF__

export LC_ALL=en_US.UTF-8
resize >/dev/null
mount -o remount,rw /

__EOF__

echo "Copying kernel..."
mkdir -p ${DSTDIR}/boot || exit 0
cp -f -r ${SRCDIR}/zImage ${DSTDIR}/boot/zImage || exit 0
cp -f -r ${SRCDIR}/socfpga.dtb ${DSTDIR}/boot/socfpga.dtb || exit 0

echo "Fixing permissions..."
chown -R root:root ${DSTDIR} || exit 0
sync

echo "Unmounting Linux partition..."
umount ${DSTDIR} || exit 0

echo "Done!"
echo ""

