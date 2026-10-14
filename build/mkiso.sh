#!/bin/bash
# Build USB/DVD-bootable hybrid ISO (Ubuntu-style layout: sda1 = ISO9660, sda2 = EFI)
set -e
I=/home/claude/kora/iso; T=$(mktemp -d); OUT=${1:-/home/claude/kora-os.iso}
cat > $T/embed.cfg <<'G'
search --no-floppy --set=root --file /casper/vmlinuz
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
G
M="part_gpt part_msdos iso9660 fat search search_fs_file normal configfile linux echo test all_video gfxterm"
grub-mkimage -O i386-pc-eltorito -o $T/eltorito.img -p /boot/grub -c $T/embed.cfg biosdisk $M
grub-mkimage -O x86_64-efi -o $T/BOOTX64.EFI -p /boot/grub -c $T/embed.cfg $M efi_gop efi_uga
mkdir -p $I/boot/grub/i386-pc; cp $T/eltorito.img $I/boot/grub/i386-pc/
mkfs.vfat -C $T/efi.img 4096 >/dev/null; mmd -i $T/efi.img ::/EFI ::/EFI/BOOT; mcopy -i $T/efi.img $T/BOOTX64.EFI ::/EFI/BOOT/
xorriso -as mkisofs -r -V KORA -J -joliet-long -l -o $OUT \
  --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img -partition_offset 16 --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b $T/efi.img -appended_part_as_gpt \
  -c boot.catalog -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot -e '--interval:appended_partition_2:::' -no-emul-boot $I 2>&1 | tail -1
rm -rf $T; ls -lh $OUT
