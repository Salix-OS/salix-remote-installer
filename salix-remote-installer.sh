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
#          Cyrille Pontvieux <JRD~AT~salixos~dot~org>
#
# License: BSD Revised.


# Avoid errors made by localization
#
export LANG=C

#
# Release
#
REL='13.37'

#
# SourceForge base url
#
BURL="http://sourceforge.net/projects/salix/files"

#
# Salix flavors
#
XFCE="salix-xfce-${REL}.iso"
XFCE64="salix64-xfce-${REL}.iso"
KDE="salix-kde-${REL}.iso"
KDE64="salix64-kde-${REL}.iso"
LXDE="salix-lxde-${REL}.iso"
LXDE64="salix64-lxde-${REL}.iso"
FLUXBOX="salix-fluxbox-${REL}.iso"
FLUXBOX64="salix64-fluxbox-${REL}.iso"
RATPOISON="salix-ratpoison-${REL}.iso"
RATPOISON64="salix64-ratpoison-${REL}.iso"
MATE="salix-mate-${REL}.iso"
MATE64="salix64-mate-${REL}.iso"

#
# MD5SUM
#
XFCESUM='8a2b0c31803913e50e45b5c829564e9b'
XFCE64SUM='872a3f85595c8ceca017f798dc89aaf6'
KDESUM='c6f68f018c77d8ce159dcc2ca5670f6e'
KDE64SUM='dbadbf6251dbede98ba78510aef0aa5b'
LXDESUM='34741338167ad5dcbfe6a8257b4177aa'
LXDE64SUM='0415b596893dac5ec2dc56160a2f5b69'
FLUXBOXSUM='c39e2cb4eed3a9bc62658ec531a14163'
FLUXBOX64SUM='af41371664e85473d82acfe8e1376812'
RATPOISONSUM='c65f40822a6ad087e649b5623f7bf33e'
RATPOISON64SUM='0c41e72c19ae4e2df4778315e1b1006d'
MATESUM='f3d8f586b28155ba686a310d8c6f6b1e'
MATE64SUM='8077b73e8fdb95cfd90ccd09e67e5687'

#
# Check if we have all that is needed
#
check_root ()
{
    if [ $(id -u) != 0 ]; then
        echo "Please run this script as root"
        exit 1
    fi
}

check_softs ()
{
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
    if ! awk -W version > /dev/null; then
        echo "Please install awk first"
        exit 2
    fi
    if ! md5sum --version > /dev/null; then
        echo "Please install md5sum first"
        exit 2
    fi
}

#
# Die, so perlish ;)
#
die ()
{
    echo "$@"
    exit 1
}

#
# Check if RAM size is enough
#
check_ram ()
{
    # RAM should be at least >= 1Go (978284)
    RAM='977260'
    RAMSIZE=$(free | awk '/^Mem:/{print $2}')
    [ $RAMSIZE > $RAM ] || die \
        "RAM size: $RAMSIZE not enough to run this script safely, aborting."
    echo
    echo "RAM size checked (>= 1GB): $RAMSIZE KB"
    echo "RAM size: OK"
}

#
# Let the user choose the Salix flavor he wants
#
choose_iso ()
{
    echo
    echo "Please choose the Salix flavor you want to install:"
    echo
    echo "1:  Xfce"
    echo "2:  Xfce (64bits)"
    echo "3:  KDE"
    echo "4:  KDE (64bits)"
    echo "5:  LXDE"
    echo "6:  LXDE (64bits)"
    echo "7:  Fluxbox"
    echo "8:  Fluxbox (64bits)"
    echo "9:  Ratpoison"
    echo "10: Ratpoison (64bits)"
    echo "11: MATE"
    echo "12: MATE (64bits)"
    echo
    echo "Pick up a number [1-12]: "
    read CHOICE
    case $CHOICE in
        1)
            ISO=$XFCE
            ISOSUM=$XFCESUM
            ;;
        2)
            ISO=$XFCE64
            ISOSUM=$XFCE64SUM
            ;;
        3)
            ISO=$KDE
            ISOSUM=$KDESUM
            ;;
        4)
            ISO=$KDE64
            ISOSUM=$KDE64SUM
            ;;
        5)
            ISO=$LXDE
            ISOSUM=$LXDESUM
            ;;
        6)
            ISO=$LXDE64
            ISOSUM=$LXDE64SUM
            ;;
        7)
            ISO=$FLUXBOX
            ISOSUM=$FLUXBOXSUM
            ;;
        8)
            ISO=$FLUXBOX64
            ISOSUM=$FLUXBOX64SUM
            ;;
        9)
            ISO=$RATPOISON
            ISOSUM=$RATPOISONSUM
            ;;
        10)
            ISO=$RATPOISON64
            ISOSUM=$RATPOISON64SUM
            ;;
        11)
            ISO=$MATE
            ISOSUM=$MATESUM
            ;;
        12)
            ISO=$MATE64
            ISOSUM=$MATE64SUM
            ;;
         *)
            die "You should have choosen between 1-12, aborting..."
    esac
    echo -n "You have choosen to download $ISO, (y)es/(n)o ?"; read REPLY
    [ "$REPLY" = "y" ] || die "Aborting..."
}

#
# Download to a tmpfs folder and integrity check
#
download_iso ()
{
    # DOWNLOAD URL
    DURL="${BURL}/${ISO}"
    # get the ISO size
    SIZE=$(wget --spider $DURL 2>&1 | awk '/^Length:/{print $2}')
    # tmp dir size is ISO size + 100MB (50 is too short)
    tmp=$(mktemp -d)
    TMPSIZE=$(($SIZE + 100 * 1024 * 1024))
    echo "Switching to the tmp dir."
    mount -t tmpfs -o size=$TMPSIZE none $tmp
    cd $tmp
    echo "Downloading $DURL ..."
    wget -c "$DURL" -O salix.iso
}
check_integrity ()
{
    echo "Checking ISO file integrity, please wait ..."
    CHECK=$(md5sum salix.iso 2>&1 | awk '{print $1}')
    if [ "$CHECK" = "$ISOSUM" ]; then
       echo "Check: OK"
    else
       cd ..
       umount $tmp
       rmdir $tmp
       die "The ISO file is corrupted, aborting."
    fi
}

#
# Mount the ISO & Install
#
install_salix ()
{
    mkdir iso-loop initrd-loop
    # loop-mount it
    mount -o ro,loop salix.iso iso-loop

    # more checks
    echo "Mounting ISO..."
    if [ $? -ne 0 ]; then
        echo "This is not a ISO file: $DURL"
        cd /
        umount $tmp
        rmdir $tmp
        exit 3
    fi

    if [ ! -d iso-loop/salix ]; then
        echo "This is not a salix ISO: $DURL"
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
    # ISO content available within the initrd: specify /salix in the installer, using "from disk"
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
    echo "Installation will begin once you press <Enter>."
    echo "Select the installation from a pre-mounted dir and specify /salix directory.."
    read JUNK
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
}

#
# main function
#
main ()
{
    check_root
    check_softs
    check_ram
    choose_iso
    download_iso
    check_integrity
    install_salix "s@"
}
main "s@"

