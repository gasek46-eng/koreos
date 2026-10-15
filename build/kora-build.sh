#!/bin/bash
# Kora OS — one-command build from scratch.
#   sudo ./kora-build.sh [output.iso]
# Needs: Ubuntu/Debian host with debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools
set -euo pipefail
VERSION=${KORA_VERSION:-0.4}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-/var/tmp/kora-build}
OUT=${1:-$PWD/kora-os-$VERSION.iso}
SUITE=resolute                       # Ubuntu 26.04 LTS
MIRROR=http://archive.ubuntu.com/ubuntu
R=$WORK/root; I=$WORK/iso

PKGS=(
  # base, live, installer
  linux-generic casper systemd-sysv sudo dbus-user-session network-manager ca-certificates curl wget rfkill iw pciutils usbutils
  calamares qt6-wayland rsync gdisk parted btrfs-progs timeshift inotify-tools dosfstools grub-pc-bin grub-efi-amd64-bin grub2-common efibootmgr zram-tools
  plymouth plymouth-theme-spinner lightdm lightdm-gtk-greeter xserver-xorg-core xserver-xorg-input-libinput
  # desktop
  hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk labwc xwayland
  waybar wofi swaybg swaylock swayidle mako-notifier foot wlsunset grim slurp wl-clipboard libnotify-bin wdisplays
  pipewire pipewire-pulse wireplumber bluez blueman brightnessctl power-profiles-daemon upower
  # look
  fonts-inter fonts-noto-core fonts-noto-color-emoji fonts-materialdesignicons-webfont papirus-icon-theme breeze-cursor-theme
  gnome-themes-extra libglib2.0-bin dconf-gsettings-backend dconf-service
  # apps
  nautilus epiphany-browser torbrowser-launcher gnome-calculator gnome-text-editor file-roller mpv extrepo
  python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
  # graphics, firmware
  libgl1-mesa-dri libegl-mesa0 mesa-vulkan-drivers intel-media-va-driver i965-va-driver mesa-va-drivers wireless-regdb
  linux-firmware-intel-wireless linux-firmware-intel-graphics linux-firmware-realtek linux-firmware-qualcomm-wireless
  linux-firmware-mediatek linux-firmware-broadcom-wireless linux-firmware-amd-graphics
  # language
  language-pack-ru language-pack-gnome-ru locales
)
OPTIONAL=(grub-btrfs adw-gtk3 papers loupe evince eog)   # installed when available in the archive

log() { echo -e "\n\033[1;35m==> $*\033[0m"; }
mounts() { for d in dev dev/pts proc sys run; do mount --bind /$d $R/$d; done; }
umounts() { for d in run sys proc dev/pts dev; do umount -l $R/$d 2>/dev/null || true; done; }
trap umounts EXIT

[ -e /usr/share/debootstrap/scripts/$SUITE ] || ln -s gutsy /usr/share/debootstrap/scripts/$SUITE
log "1/6 Base system ($SUITE)"
rm -rf $WORK; mkdir -p $R $I/casper $I/boot/grub
debootstrap --components=main,restricted,universe,multiverse $SUITE $R $MIRROR
cat > $R/etc/apt/sources.list <<EOF
deb $MIRROR $SUITE main restricted universe multiverse
deb $MIRROR $SUITE-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $SUITE-security main restricted universe multiverse
EOF
rm -f $R/etc/apt/sources.list.d/*.sources 2>/dev/null || true
echo 'Acquire::Retries "10";' > $R/etc/apt/apt.conf.d/80retries
mounts

log "2/6 Packages"
chroot $R bash -euo pipefail -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update
for i in 1 2 3 4; do apt-get install -y --no-install-recommends ${PKGS[*]} && break; echo retry \$i; sleep 20; apt-get update || true; done
dpkg -s hyprland labwc casper >/dev/null
for p in ${OPTIONAL[*]}; do apt-get install -y --no-install-recommends \$p || true; done
"

log "3/6 Kora files"
cp -a $HERE/overlay/. $R/
chmod +x $R/usr/local/bin/*
echo "Kora OS $VERSION" > $R/etc/kora-release
cp $R/usr/share/kora/logo-256.png $R/usr/share/plymouth/themes/spinner/bgrt-fallback.png
python3 -c "from PIL import Image; Image.new('RGBA',(1,1)).save('$R/usr/share/plymouth/themes/spinner/watermark.png')" 2>/dev/null || true
mkdir -p $R/etc/calamares/branding/kora && cp $R/usr/share/kora/logo-256.png $R/etc/calamares/branding/kora/logo.png
cp $R/usr/share/kora/wallpapers/night.jpg $R/etc/calamares/branding/kora/slide.png

log "4/6 Configure"
chroot $R bash -euo pipefail <<'C'
export DEBIAN_FRONTEND=noninteractive
echo kora > /etc/hostname
sed -i 's/^# *ru_RU.UTF-8/ru_RU.UTF-8/' /etc/locale.gen; locale-gen ru_RU.UTF-8 en_US.UTF-8 >/dev/null
echo LANG=ru_RU.UTF-8 > /etc/default/locale
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime; echo Europe/Moscow > /etc/timezone
printf 'GRUB_DEFAULT=0\nGRUB_TIMEOUT=1\nGRUB_TIMEOUT_STYLE=hidden\nGRUB_DISTRIBUTOR="Kora OS"\nGRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3"\nGRUB_CMDLINE_LINUX=""\n' > /etc/default/grub
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Kora OS"/' /usr/lib/os-release; echo 'Kora OS \l' > /etc/issue
ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
systemctl enable kora-live-pass.service >/dev/null 2>&1 || true
# fast boot: drop services a desktop user does not need at startup
systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service apt-daily.timer apt-daily-upgrade.timer \
  motd-news.timer man-db.timer e2scrub_all.timer e2scrub_reap.service fstrim.timer ModemManager.service >/dev/null 2>&1 || true
chmod -x /etc/update-motd.d/* 2>/dev/null || true
# defaults for every new user (live user is created from /etc/skel at boot)
HOME=/etc/skel sh -c 'kora-theme night --noapply' || true
update-initramfs -u -k all
apt-get clean; rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/*
C
umounts

log "5/6 Squashfs"
cp $(ls $R/boot/vmlinuz-* | tail -1) $I/casper/vmlinuz; cp $(ls $R/boot/initrd.img-* | tail -1) $I/casper/initrd
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 19 -b 1M -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*'
P="boot=casper persistent noprompt noeject live-media=/dev/disk/by-label/KORA username=kora hostname=kora"
cat > $I/boot/grub/grub.cfg <<G
set timeout=2
menuentry "Kora OS" { linux /casper/vmlinuz $P quiet splash loglevel=3
  initrd /casper/initrd }
menuentry "Kora OS (безопасная графика / safe graphics)" { linux /casper/vmlinuz $P nomodeset
  initrd /casper/initrd }
menuentry "Kora OS (автопоиск носителя / auto-detect media)" { linux /casper/vmlinuz boot=casper noprompt noeject username=kora hostname=kora quiet splash
  initrd /casper/initrd }
G

log "6/6 Bootable ISO (UEFI + BIOS, USB + DVD)"
T=$(mktemp -d)
printf 'search --no-floppy --set=root --file /casper/vmlinuz\nset prefix=($root)/boot/grub\nconfigfile $prefix/grub.cfg\n' > $T/embed.cfg
M="part_gpt part_msdos iso9660 fat search search_fs_file normal configfile linux echo test all_video gfxterm"
grub-mkimage -O i386-pc-eltorito -o $T/eltorito.img -p /boot/grub -c $T/embed.cfg biosdisk $M
grub-mkimage -O x86_64-efi -o $T/BOOTX64.EFI -p /boot/grub -c $T/embed.cfg $M efi_gop efi_uga
mkdir -p $I/boot/grub/i386-pc; cp $T/eltorito.img $I/boot/grub/i386-pc/
mkfs.vfat -C $T/efi.img 4096 >/dev/null; mmd -i $T/efi.img ::/EFI ::/EFI/BOOT; mcopy -i $T/efi.img $T/BOOTX64.EFI ::/EFI/BOOT/
xorriso -as mkisofs -r -V KORA -J -joliet-long -l -o "$OUT" \
  --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img -partition_offset 16 --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b $T/efi.img -appended_part_as_gpt \
  -c boot.catalog -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot -e '--interval:appended_partition_2:::' -no-emul-boot $I
rm -rf $T
(cd "$(dirname "$OUT")" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")
log "Done: $OUT ($(du -h "$OUT" | cut -f1))"
