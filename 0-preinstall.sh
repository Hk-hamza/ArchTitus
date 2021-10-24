#!/usr/bin/env bash


echo "-------------------------------------------------"
echo "Setting up mirrors for optimal download          "
echo "-------------------------------------------------"
iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm pacman-contrib terminus-font
setfont ter-v22b
sed -i 's/^#Para/Para/' /etc/pacman.conf
pacman -S --noconfirm reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -e "                                                                                                                                                           ";
echo -e "                                                                                                                                                           ";
echo -e "HHHHHHHHH     HHHHHHHHHKKKKKKKKK    KKKKKKK                    AAA               RRRRRRRRRRRRRRRRR                CCCCCCCCCCCCC     HHHHHHHHH     HHHHHHHHH";
echo -e "H:::::::H     H:::::::HK:::::::K    K:::::K                   A:::A              R::::::::::::::::R            CCC::::::::::::C     H:::::::H     H:::::::H";
echo -e "H:::::::H     H:::::::HK:::::::K    K:::::K                  A:::::A             R::::::RRRRRR:::::R         CC:::::::::::::::C     H:::::::H     H:::::::H";
echo -e "HH::::::H     H::::::HHK:::::::K   K::::::K                 A:::::::A            RR:::::R     R:::::R       C:::::CCCCCCCC::::C     HH::::::H     H::::::HH";
echo -e "  H:::::H     H:::::H  KK::::::K  K:::::KKK                A:::::::::A             R::::R     R:::::R      C:::::C       CCCCCC       H:::::H     H:::::H  ";
echo -e "  H:::::H     H:::::H    K:::::K K:::::K                  A:::::A:::::A            R::::R     R:::::R     C:::::C                     H:::::H     H:::::H  ";
echo -e "  H::::::HHHHH::::::H    K::::::K:::::K                  A:::::A A:::::A           R::::RRRRRR:::::R      C:::::C                     H::::::HHHHH::::::H  ";
echo -e "  H:::::::::::::::::H    K:::::::::::K                  A:::::A   A:::::A          R:::::::::::::RR       C:::::C                     H:::::::::::::::::H  ";
echo -e "  H:::::::::::::::::H    K:::::::::::K                 A:::::A     A:::::A         R::::RRRRRR:::::R      C:::::C                     H:::::::::::::::::H  ";
echo -e "  H::::::HHHHH::::::H    K::::::K:::::K               A:::::AAAAAAAAA:::::A        R::::R     R:::::R     C:::::C                     H::::::HHHHH::::::H  ";
echo -e "  H:::::H     H:::::H    K:::::K K:::::K             A:::::::::::::::::::::A       R::::R     R:::::R     C:::::C                     H:::::H     H:::::H  ";
echo -e "  H:::::H     H:::::H  KK::::::K  K:::::KKK         A:::::AAAAAAAAAAAAA:::::A      R::::R     R:::::R      C:::::C       CCCCCC       H:::::H     H:::::H  ";
echo -e "HH::::::H     H::::::HHK:::::::K   K::::::K        A:::::A             A:::::A   RR:::::R     R:::::R       C:::::CCCCCCCC::::C     HH::::::H     H::::::HH";
echo -e "H:::::::H     H:::::::HK:::::::K    K:::::K       A:::::A               A:::::A  R::::::R     R:::::R        CC:::::::::::::::C     H:::::::H     H:::::::H";
echo -e "H:::::::H     H:::::::HK:::::::K    K:::::K      A:::::A                 A:::::A R::::::R     R:::::R          CCC::::::::::::C     H:::::::H     H:::::::H";
echo -e "HHHHHHHHH     HHHHHHHHHKKKKKKKKK    KKKKKKK     AAAAAAA                   AAAAAAARRRRRRRR     RRRRRRR             CCCCCCCCCCCCC     HHHHHHHHH     HHHHHHHHH";

reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt


echo -e "\nInstalling prereqs...\n$HR"
pacman -S --noconfirm gptfdisk btrfs-progs

echo "-------------------------------------------------"
echo "-------select your disk to format----------------"
echo "-------------------------------------------------"
lsblk
echo "Please enter disk to work on: (example /dev/sda)"
read DISK
echo "THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK"
read -p "are you sure you want to continue (Y/N):" formatdisk
case $formatdisk in

y|Y|yes|Yes|YES)
echo "--------------------------------------"
echo -e "\nFormatting disk...\n$HR"
echo "--------------------------------------"

# disk prep
sgdisk -Z ${DISK} # zap all on disk
#dd if=/dev/zero of=${DISK} bs=1M count=200 conv=fdatasync status=progress
sgdisk -a 2048 -o ${DISK} # new gpt disk 2048 alignment

# create partitions
sgdisk -n 1:0:+1000M ${DISK} # partition 1 (UEFI SYS), default start block, 512MB
sgdisk -n 2:0:0     ${DISK} # partition 2 (Root), default start, remaining

# set partition types
sgdisk -t 1:ef00 ${DISK}
sgdisk -t 2:8300 ${DISK}

# label partitions
sgdisk -c 1:"UEFISYS" ${DISK}
sgdisk -c 2:"ROOT" ${DISK}

# make filesystems
echo -e "\nCreating Filesystems...\n$HR"
if [[ ${DISK} =~ "nvme" ]]; then
mkfs.vfat -F32 -n "UEFISYS" "${DISK}p1"
mkfs.btrfs -L "ROOT" "${DISK}p2" -f
mount -t btrfs "${DISK}p2" /mnt
else
mkfs.vfat -F32 -n "UEFISYS" "${DISK}1"
mkfs.btrfs -L "ROOT" "${DISK}2" -f
mount -t btrfs "${DISK}2" /mnt
fi
ls /mnt | xargs btrfs subvolume delete
btrfs subvolume create /mnt/@
umount /mnt
;;
esac

# mount target
mount -t btrfs -o subvol=@ -L ROOT /mnt
mkdir /mnt/boot
mkdir /mnt/boot/efi
mount -t vfat -L UEFISYS /mnt/boot/

echo "--------------------------------------"
echo "-- Arch Install on Main Drive       --"
echo "--------------------------------------"
pacstrap /mnt base base-devel linux linux-firmware vim nano sudo archlinux-keyring wget libnewt --noconfirm --needed
genfstab -U /mnt >> /mnt/etc/fstab
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
echo "--------------------------------------"
echo "-- Bootloader Systemd Installation  --"
echo "--------------------------------------"
bootctl install --esp-path=/mnt/boot
[ ! -d "/mnt/boot/loader/entries" ] && mkdir -p /mnt/boot/loader/entries
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux  
linux /vmlinuz-linux  
initrd  /initramfs-linux.img  
options root=LABEL=ROOT rw rootflags=subvol=@
EOF
cp -R ~/ArchTitus /mnt/root/
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
echo "--------------------------------------"
echo "--   SYSTEM READY FOR 0-setup       --"
echo "--------------------------------------"
