#!/bin/bash

# 1.0 - Thu 01 Oct 2020 11:31:55 PM CEST - first version
# 1.1 - Mon 09 Nov 2020 06:34:05 PM CET - temporary directories in /tmp
# 1.2 - Sun 28 Mar 2021 11:18:46 AM CEST - add firmware switch

usage () {
	echo ""
	echo "Debian bootable external device with extra space"
	echo "================================================"
	echo ""
	echo "make a bootable device (in most cases a USB key) with three consecutive partitions:"
	echo "1) EFI partition for booting (100MB)"
	echo "2) ext4 partition for storing ISO images"
	echo "3) NTFS partition for storing any kind of user data"
	echo ""
	echo "This script support the following arguments:"
	echo ""
	echo -e "-h | --help \t\t\t This help"
	echo -e "-v | --verbose \t\t\t Verbose output"
	echo -e "-a | --arch {i386|amd64} \t\t [ Optional, default: amd64 ] \t Debian ditribution architecture to create" 
	echo -e "-s | --iso-space N \t\t\t [ Optional, default: 2 (GB) ] \t Space to reserve for ISO images"
	echo -e "-f | --with-firmware \t\t\t Include non-free firmware"
	echo -e "-b | --branch {stable|testing} \t [ Optional, default: stable ] \t Branch of Debian distribution"
	echo -e "-d | --device /dev/sd{a..z} \t\t [ Required ] \t Name of the device to erase and write into"
	echo ""
}

# is root?
if [[ $EUID -ne 0 ]]; then
    echo "Root privilege is required"
    exit 1
fi

# number of arguments required
if [ "$#" -lt "1" ]; then
	usage
	exit 1
fi

# variables default
ARCH=amd64
SPACE=2
FIRMWARE=N
BRANCH=stable
DEV=
VERBOSE=

# argument parsing

while [ "$1" != "" ]; do
	case "$1" in
		-h|--help)
			usage
			exit 1
			;;	
		-v|--verbose)
			VERBOSE="--verbose"
			shift 1
			;;	
		-a|--arch)
			if [ -n "$2" ]&&[ ${2:0:1} != "-" ]&&([ "$2" == "amd64" ]||[ "$2" == "i386" ]); then
				ARCH=$2
				shift 2
			else
				echo "Error: missing argument for $1"
				exit 1
			fi
			;;
		-f|--with-firmware)
			FIRMWARE=Y
			shift 1
			;;
		-b|--branch)
			if [ -n "$2" ]&&[ ${2:0:1} != "-" ]&&([ "$2" == "stable" ]||[ "$2" == "testing" ]); then
				BRANCH=$2
				shift 2
			else
				echo "Error: missing argument for $1"
				exit 1
			fi
			;;
		-d|--device)
			if [ -n "$2" ]&&[ ${2:0:1} != "-" ]&&[[ "$2" =~ /dev/sd[a-z] ]]; then
				DEV=$2
				shift 2
			else
				echo "Error: missing argument for $1"
				exit 1
			fi
			;;
		-s|--iso-space)
			if [ -n "$2" ]&&[ ${2:0:1} != "-" ]&&[[ "$2" =~ ^[0-9]*$ ]]; then
				SPACE=$2
				shift 2
			else
				echo "Error: missing argument for $1"
				exit 1
			fi
			;;
		*|-*|--*=)
			echo "Error: unsupported argument $1"
			usage
			exit 1
	esac
done

# verify the existence of the block device
if [ -b $DEV ]; then
	echo "OK: I found the device"
else
	echo "Error: device not found"
	exit 1
fi

# is the usb key large enough?
echo "Device size: " $(($(lsblk -bno SIZE $DEV | head -1)/(1024*1024*1024)))" GB"
echo "ISO space request: "$SPACE" GB"
if [ "$SPACE" -gt $(($(lsblk -bno SIZE $DEV | head -1)/(1024*1024*1024))) ]; then		
	echo "Error: The device $DEV is too small for the iso space request"
	exit 1
else
	echo "OK: The size of device $DEV is large enough"
fi

# are you insane?
echo ""
echo "############################################"
echo "#       --> INSANELY DANGEROUS! <---       #"
echo "# USE ONLY IF YOU KNOW WHAT ARE YOU DOING  #"
echo "# AN IMPROPER USE CAN DESTROY YOUR SYSTEM! #"
echo "############################################"

read -r -p "Are you sure? [Yy/Nn] " answer
case "$answer" in
	[Yy])
		echo "OK, you are insane"
	;;	
	[Nn])
		echo "Aborting"	
		exit 1
	;;
	*) 
		echo "Bad answer: aborting"	
		exit 1
esac	

# create temporary directory structure
#random_dir=$(date | md5sum)
#random_dir=${random_dir:0:32}
random_dir=$(mktemp -d)
EFI=$random_dir/EFI
DEBIAN=$random_dir/DEBIAN
ISO=$random_dir/ISO
mkdir $VERBOSE --parents $EFI $DEBIAN $ISO

# unmounting
umount $VERBOSE ${DEV}*

# partitioning

# GPT table
parted $DEV --script mktable gpt
# 100 MB EFI partition
parted --align optimal $DEV --script mkpart EFI fat32 1MB 100MB
parted $DEV --script set 1 esp on
sleep 1
mkfs.vfat -v -n EFI ${DEV}1
# ISO partition
parted --align optimal $DEV --script mkpart DEBIAN ext4 100MB ${SPACE}GB
parted $DEV --script set 2 esp on
sleep 1
mkfs.ext4 -v -m 0 -L DEBIAN -F ${DEV}2
# User data partition
# parted ${DEV} --script mkpart DATA fat32 ${SPACE}GB 100% # 4GB devices are obsolete
parted --align optimal $DEV --script mkpart DATA ntfs ${SPACE}GB 100%
parted $DEV --script set 3 msftdata on
sleep 1
# mkfs.vfat -n DATA ${DEV}3 # 4GB devices are obsolete
mkfs.ntfs --label DATA --fast $VERBOSE ${DEV}3
# volume summary
parted $DEV --script print 

# mounting
mount $VERBOSE ${DEV}1 $EFI
mount $VERBOSE ${DEV}2 $DEBIAN

# install bootloader
case "$ARCH" in
	amd64)
		grub-install $VERBOSE --removable --no-uefi-secure-boot --target=x86_64-efi --boot-directory=$DEBIAN/boot --efi-directory=$EFI $DEV
	;;
	i386)
		grub-install $VERBOSE --removable --no-uefi-secure-boot --target=i386-efi --boot-directory=$DEBIAN/boot --efi-directory=$EFI $DEV
	;;
	*)
		echo "Error: unsupported architecture $ARCH"
		exit 1
esac

# download hd-media components
mkdir $VERBOSE $DEBIAN/install.amd
wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/install.amd http://ftp.debian.org/debian/dists/$BRANCH/main/installer-$ARCH/current/images/hd-media/initrd.gz 
wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/install.amd http://ftp.debian.org/debian/dists/$BRANCH/main/installer-$ARCH/current/images/hd-media/vmlinuz

mkdir $VERBOSE $DEBIAN/install.amd/gtk
wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/install.amd/gtk http://ftp.debian.org/debian/dists/$BRANCH/main/installer-$ARCH/current/images/hd-media/gtk/initrd.gz 
wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/install.amd/gtk http://ftp.debian.org/debian/dists/$BRANCH/main/installer-$ARCH/current/images/hd-media/gtk/vmlinuz

# download bootable iso images
mkdir $VERBOSE $DEBIAN/isolinux
case "$BRANCH" in
	stable)
		# download installation iso
		case "$FIRMWARE" in
			N)
				wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/isolinux https://cdimage.debian.org/cdimage/release/current/$ARCH/iso-cd/debian-1{0..9}.{0..9}.0-$ARCH-netinst.iso
				# mount the iso to extract boot files
				mount $VERBOSE $DEBIAN/isolinux/debian-*-${ARCH}-netinst.iso $ISO
			;;
			Y)
				wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/isolinux https://cdimage.debian.org/cdimage/unofficial/non-free/images-including-firmware/current/$ARCH/iso-cd/firmware-1{0..9}.{0..9}.0-$ARCH-netinst.iso
				# mount the iso to extract boot files
				mount $VERBOSE $DEBIAN/isolinux/firmware-*-${ARCH}-netinst.iso $ISO
			;;
			*)
				echo "Error: unsupported firmware type"
				exit 1
		esac
		
	;;
	testing)
		# download installation iso
		case "$FIRMWARE" in
			N)
				wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/isolinux https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/$ARCH/iso-cd/debian-testing-amd64-netinst.iso
				# mount the iso to extract boot files
				mount $VERBOSE $DEBIAN/isolinux/debian-*-${ARCH}-netinst.iso $ISO
			;;
			Y)
				wget $VERBOSE --progress=bar --directory-prefix=$DEBIAN/isolinux https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/daily-builds/sid_d-i/current/$ARCH/iso-cd/firmware-testing-$ARCH-netinst.iso
				# mount the iso to extract boot files
				mount $VERBOSE $DEBIAN/isolinux/firmware-*-${ARCH}-netinst.iso $ISO
			;;
			*)
				echo "Error: unsupported firmware type"
				exit 1
		esac
	;;
	*)
		echo "Error: unsupported branch $BRANCH"
		exit 1
esac

# copy boot files in debian partition
case "$ARCH" in
	amd64)
		cp $VERBOSE --archive $ISO/boot/grub/x86_64-efi/grub.cfg $DEBIAN/boot/grub/x86_64-efi
	;;
	i386)
		cp $VERBOSE --archive $ISO/boot/grub/i386-efi/grub.cfg $DEBIAN/boot/grub/i386-efi
	;;
	*)
		echo "Error: unsupported architecture $ARCH"
		exit 1
esac
cp $VERBOSE --archive $ISO/isolinux/splash.png $DEBIAN/isolinux
cp $VERBOSE --archive $ISO/boot/grub/grub.cfg $DEBIAN/boot/grub
cp $VERBOSE --archive $ISO/boot/grub/font.pf2 $DEBIAN/boot/grub

# some graphics
mkdir $DEBIAN/boot/grub/theme
cp $VERBOSE --archive --recursive $ISO/boot/grub/theme/* $DEBIAN/boot/grub/theme

# cleaning
sync
umount $VERBOSE $EFI $ISO $DEBIAN
#rm --recursive $random_dir

# end	
exit 0

