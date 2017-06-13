#!/bin/bash

echo ""

if [[ $EUID -ne 0 ]]; then
   echo "This script requires root rights. Quiting..."
   echo ""
   exit 0
fi

if [ -z $1 ]; then
   echo "No SD device specified"
   exit 0
fi

if [ ! -e "$1" ]; then
   echo "Couldn't find SD card"
   exit 0
fi

read -p "Do you wish to partition this SD card? " yn
case $yn in
   [Yy]* )
           echo ""
           echo "Unmounting some partitions (errors are ok here)..."
           umount ${1}
           umount ${1}1
           umount ${1}2
           umount ${1}3
           echo ""
           echo "Erasing of first 64MB of card..."
           dd if=/dev/zero of=$1 bs=1M count=64 || exit 0

           echo "Partitioning..."
           (sfdisk $1 <<-__END__
              502M,+,0xB
              2M,500M,0x83
              1M,1M,0xA2
__END__
) || exit 0
	  sleep 3
          ./copy_to_sd.sh $1
       ;;
   * ) ;;
esac

