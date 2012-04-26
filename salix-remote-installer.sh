#!/bin/sh
#
# salix-remote-installer.sh
#
# This script will install your choosen Salix flavor from your running system
# to another partition.
# You don't have to boot the installer, all is done in a tmpfs dir.
# (useful on a online server)
#
# Authors: Frédéric Galusik <fredg~AT~salixos~dot~org>
#	   Cyrille Pontvieux <jrd~AT~salixos~dot~org>
#
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation,
# advertising materials, and other materials related to such
# distribution and use acknowledge that the software was developed
# by the <organization>.  The name of the
# University may not be used to endorse or promote products derived
# from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

ISOURL='http://sourceforge.net/projects/salix/files/13.37/salix-xfce-13.37.iso/download'
if [ $(id -u) != 0 ]; then
  echo "Please run this script as root"
  exit 1
fi
if ! wget --version > /dev/null; then
  echo "Please install wget first"
  exit 2
fi
if ! zcat --version > /dev/null; then
  echo "Please install zcat first"
  exit 2
fi
if ! cpio --version > /dev/null; then
  echo "Please install cpio first"
  exit 2
fi
if ! sed --version > /dev/null; then
  echo "Please install sed first"
  exit 2
fi
if ! grep --version > /dev/null; then
  echo "Please install grep first"
  exit 2
fi
tmp=$(mktemp -d)
# prepare about 700MB of mounted memory
mount -t tmpfs -o size=750000000 none $tmp
cd $tmp
# download ISO
wget "$ISOURL" -O salix.iso
mkdir iso-loop initrd-loop
# loop-mount it
mount -o ro salix.iso iso-loop
if [ $? -ne 0 ]; then
  echo "This is not a ISO file: $ISOURL"
  cd /
  umount $tmp
  rmdir $tmp
  exit 3
fi
if [ ! -d iso-loop/salix ]; then
  echo "This is not a salix ISO: $ISOURL"
  umount iso-loop
  cd /
  umount $tmp
  rmdir $tmp
  exit 4
fi
# extract initrd
zcat iso-loop/isolinux/initrd.img > initrd
cd initrd-loop
cpio -i < ../initrd
# ISO avaiable from withing initrd: specify /salix in the installer, using "from disk"
mkdir salix
mount -o bind ../iso-loop salix
mount -t proc none proc
# get the cmdline and append what arguments you want, for example "noudev"
cp /proc/cmdline cmdline
while [ -n "$1" ]; do
  echo -n " $1" >> cmdline
  shift
done
SLACK_KERNEL=$(grep '^default' salix/isolinux/isolinux.cfg|sed 's/[^ ]* //')
echo -n " SLACK_KERNEL=$SLACK_KERNEL" >> cmdline
# do some modification to the initrd sh script
sed -i '
  s:^\(.*nologin.*\):#\1:;
  s:^\(.*swapon.*\):#\1:;
  s:/proc/cmdline:/cmdline:;
  s:^\(.*SeTnet.*\):#\1:;
  s:^\(.*rc\.dropbear.*\):#\1:;
  ' etc/rc.d/rc.S
# launch the installation
chroot . /etc/rc.d/rc.S
# if end of installation
chroot . /sbin/umount -a
umount salix
umount sys
umount proc
cd ..
umount iso-loop
cd /
umount -l $tmp
rmdir $tmp
