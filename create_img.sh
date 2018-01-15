#!/bin/bash

echo ""

if [[ $EUID -ne 0 ]]; then
   sudo $0
   exit 0
fi

DIR=$PWD
SRCDIR=${DIR}
DSTDIR=/media/rootfs

dd if=/dev/zero of=linux.img bs=64k count=3000

echo "Formatting Linux partition..."
mkfs.ext4 -L rootfs linux.img || exit 0
echo ""

echo "Mounting Linux partition..."
if [ ! -d ${DSTDIR} ]; then
   mkdir -p ${DSTDIR} || exit 0
fi
mount linux.img ${DSTDIR} || exit 0

echo "Copying main rootfs files..."
tar xfp ${SRCDIR}/rootfs.tar.gz --warning=no-timestamp -C ${DSTDIR} || exit 0

echo "Copying kernel modules rootfs files..."
tar xfp ${SRCDIR}/modules.tar.gz --strip-components=2 --warning=no-timestamp -C ${DSTDIR}/lib || exit 0

echo "Copying devices firmwares..."
mkdir -p ${DSTDIR}/lib/firmware || exit 0
tar xfp ${SRCDIR}/firmware.tar.gz --warning=no-timestamp -C ${DSTDIR}/lib/firmware || exit 0

echo "Copying additional modifications..."
if [ -d ${SRCDIR}/.addon ]; then
   [ -f ${SRCDIR}/addon.tar ] && rm -f ${SRCDIR}/addon.tar
          tar cvf ${SRCDIR}/addon.tar -C ${SRCDIR}/.addon .
fi
tar xfp ${SRCDIR}/addon.tar --warning=no-timestamp -C ${DSTDIR} || exit 0
mkdir -p ${DSTDIR}/media/fat || exit 0
#echo "/dev/mmcblk0p1 /media/fat auto defaults,sync,nofail 0 0" >>${DSTDIR}/etc/fstab
sed 's/getty/agetty/g' -i ${DSTDIR}/etc/inittab
sed 's/115200//g' -i ${DSTDIR}/etc/inittab
sed '/::sysinit:\/bin\/mount \-a/a ::sysinit:\/etc\/resync\ \&' -i ${DSTDIR}/etc/inittab
sed '/::sysinit:\/bin\/mount \-a/a ::sysinit:\/media\/fat\/MiSTer\ \&' -i ${DSTDIR}/etc/inittab
sed '/::sysinit:\/bin\/mount \-t proc proc \/proc/a ::sysinit:\/etc\/irqoncpu0' -i ${DSTDIR}/etc/inittab
mv ${DSTDIR}/etc/init.d/S40network ${DSTDIR}/etc/init.d/S90network
rm ${DSTDIR}/sbin/udhcpc
sed '/PATH/ s/$/:\/media\/fat\/linux:\./' -i ${DSTDIR}/etc/profile
mkdir -p ${DSTDIR}/media/rootfs || exit 0

cat >> ${DSTDIR}/etc/profile <<- __EOF__

export LC_ALL=en_US.UTF-8
resize >/dev/null
mount -o remount,rw /

__EOF__

echo "Fixing permissions..."
chown -R root:root ${DSTDIR} || exit 0
sync
sleep 3

echo "Unmounting Linux partition..."
umount ${DSTDIR} || exit 0

echo "Done!"
echo ""

