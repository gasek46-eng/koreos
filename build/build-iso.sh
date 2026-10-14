#!/bin/bash
# Builds Kora OS prototype live ISO (Ubuntu 24.04 base, labwc shell)
set -ex
W=/home/claude/kora; R=$W/root; I=$W/iso
apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools
rm -rf $W; mkdir -p $R $I/casper $I/boot/grub
debootstrap --components=main,universe,multiverse noble $R http://archive.ubuntu.com/ubuntu
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
cat > $R/etc/apt/sources.list <<'E'
deb http://archive.ubuntu.com/ubuntu noble main universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main universe multiverse
E
cp /home/claude/kora-install.sh $R/tmp/
chroot $R bash -ex <<'E'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends linux-image-generic casper systemd-sysv sudo \
  dbus-user-session libpam-systemd network-manager ca-certificates wget xwayland \
  labwc waybar wofi swaybg mako-notifier foot thunar fonts-inter fonts-noto-color-emoji \
  papirus-icon-theme pipewire pipewire-pulse wireplumber \
  libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-gtk3 \
  xz-utils torbrowser-launcher epiphany-browser
echo kora > /etc/hostname
useradd -m -s /bin/bash -G sudo kora; echo kora:kora | chpasswd
mkdir -p /etc/systemd/system/getty@tty1.service.d
printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin kora --noclear %%I $TERM\n' > /etc/systemd/system/getty@tty1.service.d/a.conf
cat > /usr/local/bin/kora-zoom <<'Z'
#!/bin/sh
command -v zoom >/dev/null && exec zoom
foot -e sh -c 'wget -O /tmp/z.deb https://zoom.us/client/latest/zoom_amd64.deb && sudo apt install -y /tmp/z.deb && zoom'
Z
cat > /usr/local/bin/kora-telegram <<'Z'
#!/bin/sh
[ -x ~/.local/Telegram/Telegram ] && exec ~/.local/Telegram/Telegram
foot -e sh -c 'mkdir -p ~/.local && wget -O- https://telegram.org/dl/desktop/linux | tar xJ -C ~/.local && ~/.local/Telegram/Telegram'
Z
chmod +x /usr/local/bin/kora-zoom /usr/local/bin/kora-telegram
# reuse configs from prototype script (skip its apt part)
sed -n '/^C=~/,$p' /tmp/kora-install.sh | sed -e 's/"librewolf"/"epiphany-browser"/' -e 's/"telegram-desktop"/"kora-telegram"/' -e 's/"on-click":"zoom"/"on-click":"kora-zoom"/' \
  -e 's#&& exec labwc#&& { export WLR_RENDERER_ALLOW_SOFTWARE=1; exec labwc; }#' > /tmp/cfg.sh
su - kora -c 'bash /tmp/cfg.sh'
apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/*
E
cp $R/boot/vmlinuz-* $I/casper/vmlinuz; cp $R/boot/initrd.img-* $I/casper/initrd
mksquashfs $R $I/casper/filesystem.squashfs -comp xz -e boot -noappend
cat > $I/boot/grub/grub.cfg <<'E'
set timeout=3
menuentry "Kora OS (live)" { linux /casper/vmlinuz boot=casper username=kora hostname=kora quiet; initrd /casper/initrd }
E
grub-mkrescue -o /home/claude/kora-os.iso $I -volid KORA
ls -lh /home/claude/kora-os.iso
