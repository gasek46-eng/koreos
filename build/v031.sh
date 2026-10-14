#!/bin/bash
# Kora 0.3.1: Wi-Fi/BT/GPU firmware + reliable USB live-media detection
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends linux-firmware-intel-wireless linux-firmware-intel-graphics linux-firmware-realtek \
  linux-firmware-qualcomm-wireless linux-firmware-mediatek linux-firmware-broadcom-wireless linux-firmware-amd-graphics wireless-regdb
update-initramfs -u -k all
apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/*.deb
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
cp $(ls $R/boot/initrd.img-* | tail -1) $I/casper/initrd
cat > $I/boot/grub/grub.cfg <<'G'
set timeout=3
menuentry "Kora OS" {
  linux /casper/vmlinuz boot=casper live-media=/dev/disk/by-label/KORA username=kora hostname=kora quiet splash
  initrd /casper/initrd
}
menuentry "Kora OS (безопасная графика / safe graphics)" {
  linux /casper/vmlinuz boot=casper live-media=/dev/disk/by-label/KORA username=kora hostname=kora nomodeset
  initrd /casper/initrd
}
menuentry "Kora OS (автопоиск носителя / auto-detect media)" {
  linux /casper/vmlinuz boot=casper username=kora hostname=kora quiet splash
  initrd /casper/initrd
}
G
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
bash /home/claude/improve/mkiso.sh /home/claude/kora-os-0.3.1.iso
cd /home/claude && sha256sum kora-os-0.3.1.iso > kora-os-0.3.1.iso.sha256
