#!/bin/bash
# Kora branding + Russian: run after build-iso.sh (as root)
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso; A=/home/claude/brand
apt-get install -y -q librsvg2-bin python3-pil >/dev/null
rsvg-convert -w 256 $A/logo.svg > $A/logo-256.png; rsvg-convert -w 36 $A/logo.svg > $A/logo-36.png
python3 - <<'P'
from PIL import Image
W,H=1920,1080; bg=Image.new('RGB',(W,H))
for y in range(H):
  t=y/H; c=tuple(int(a+(b-a)*t) for a,b in zip((36,33,58),(14,14,24)))
  bg.paste(c,(0,y,W,y+1))
l=Image.open('/home/claude/brand/logo-256.png').convert('RGBA').resize((160,160))
l.putalpha(l.getchannel('A').point(lambda v:int(v*.9)))
bg.paste(l,((W-160)//2,(H-160)//2-40),l); bg.save('/home/claude/brand/wallpaper.png')
P
mkdir -p $R/usr/share/kora; cp $A/*.png $A/logo.svg $R/usr/share/kora/
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update; apt-get install -y --no-install-recommends language-pack-ru libreoffice-l10n-ru hunspell-ru plymouth plymouth-theme-spinner
echo LANG=ru_RU.UTF-8 > /etc/default/locale
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime; echo Europe/Moscow > /etc/timezone
T=/usr/share/plymouth/themes/spinner; cp /usr/share/kora/logo-256.png $T/bgrt-fallback.png
cp /usr/share/kora/blank.png $T/watermark.png
printf '[Unit]\nAfter=plymouth-quit-wait.service\n[Service]\nExecStartPre=-/usr/bin/plymouth quit\n' > /etc/systemd/system/getty@tty1.service.d/b.conf
echo 'Kora OS \l' > /etc/issue; sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Kora OS"/' /usr/lib/os-release
update-initramfs -u -k all
H=/home/kora; C=$H/.config
printf "XKB_DEFAULT_LAYOUT=us,ru\nXKB_DEFAULT_OPTIONS=grp:alt_shift_toggle\nLANG=ru_RU.UTF-8\n" > $C/labwc/environment
sed -i "s#^swaybg.*#swaybg -i /usr/share/kora/wallpaper.png -m fill \&#" $C/labwc/autostart
cat > $C/waybar/top.json <<J
{"position":"top","height":26,
"modules-left":["image#logo","custom/logo","wlr/taskbar"],"modules-right":["network","pulseaudio","battery","custom/clock"],
"image#logo":{"path":"/usr/share/kora/logo-36.png","size":18,"on-click":"wofi --show drun"},
"custom/logo":{"format":"Kora","on-click":"wofi --show drun"},
"custom/clock":{"exec":"LC_TIME=ru_RU.UTF-8 date +'%a %d %b  %H:%M'","interval":20}}
J
touch $H/.hushlogin; chown -R kora:kora $H; sed -i 's#&& export WLR_RENDERER_ALLOW_SOFTWARE=1; exec labwc#\&\& { export WLR_RENDERER_ALLOW_SOFTWARE=1; exec labwc; }#' $H/.bash_profile
chmod -x /etc/update-motd.d/*; apt-get clean; rm -rf /var/lib/apt/lists/*
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
cp $R/boot/initrd.img-* $I/casper/initrd
printf 'set timeout=3\nmenuentry "Kora OS" { linux /casper/vmlinuz boot=casper username=kora hostname=kora locale=ru_RU.UTF-8 quiet splash; initrd /casper/initrd }\n' > $I/boot/grub/grub.cfg
rm -f $I/casper/filesystem.squashfs; mksquashfs $R $I/casper/filesystem.squashfs -comp xz -noappend -quiet -wildcards -e 'boot' 'proc/*' 'sys/*' 'dev/*'
grub-mkrescue -o /home/claude/kora-os.iso $I -volid KORA
