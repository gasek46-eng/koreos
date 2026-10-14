#!/bin/bash
# Kora: fast boot + Calamares installer + settings menu (run after build-iso.sh, brand.sh)
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends calamares qtwayland5 rsync dosfstools grub-pc-bin grub-efi-amd64-bin grub2-common efibootmgr \
  pavucontrol wdisplays blueman network-manager-gnome brightnessctl zstd zram-tools polkitd
# fast boot
systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service apt-daily.timer apt-daily-upgrade.timer motd-news.timer man-db.timer e2scrub_all.timer fstrim.timer || true
printf 'GRUB_DEFAULT=0\nGRUB_TIMEOUT=2\nGRUB_DISTRIBUTOR="Kora OS"\nGRUB_CMDLINE_LINUX_DEFAULT="quiet splash"\nGRUB_CMDLINE_LINUX=""\n' > /etc/default/grub
# settings menu
cat > /usr/local/bin/kora-settings <<'S'
#!/bin/sh
c=$(printf '📶 Wi-Fi и сеть\n🔊 Звук\n🖥 Экран\n🔵 Bluetooth\n☀ Ярче\n🌙 Темнее\n🖼 Обои\n💿 Установить Kora OS\n🔄 Перезагрузить\n⏻ Выключить' | wofi --dmenu -i -p Настройки)
case "$c" in
*Wi-Fi*) foot -e nmtui-connect;; *Звук*) pavucontrol;; *Экран*) wdisplays;; *Bluetooth*) blueman-manager;;
*Ярче*) brightnessctl s +10%;; *Темнее*) brightnessctl s 10%-;;
*Обои*) f=$(ls /usr/share/kora/wallpaper*.png ~/Изображения/*.* ~/Pictures/*.* 2>/dev/null | wofi --dmenu -p Обои) && { pkill swaybg; sed -i "s#^swaybg.*#swaybg -i '$f' -m fill \&#" ~/.config/labwc/autostart; swaybg -i "$f" -m fill & };;
*Установить*) kora-install;; *Перезагрузить*) systemctl reboot;; *Выключить*) systemctl poweroff;;
esac
S
cat > /usr/local/bin/kora-install <<'S'
#!/bin/sh
[ -e /cdrom/casper ] || { notify-send "Kora OS уже установлена"; exit; }
exec sudo -E env QT_QPA_PLATFORM='wayland;xcb' calamares
S
chmod +x /usr/local/bin/kora-*
printf '[Desktop Entry]\nName=Настройки\nExec=kora-settings\nIcon=preferences-system\nType=Application\n' > /usr/share/applications/kora-settings.desktop
printf '[Desktop Entry]\nName=Установить Kora OS\nExec=kora-install\nIcon=system-software-install\nType=Application\n' > /usr/share/applications/kora-install.desktop
# calamares config
mkdir -p /etc/calamares/modules /etc/calamares/branding/kora
cp /usr/share/kora/logo-256.png /etc/calamares/branding/kora/logo.png
cp /usr/share/kora/wallpaper.png /etc/calamares/branding/kora/slide.png
cat > /etc/calamares/settings.conf <<'Y'
modules-search: [ local ]
instances:
- { id: before, module: shellprocess, config: shellprocess_before.conf }
sequence:
- show: [welcome, locale, keyboard, partition, users, summary]
- exec: [partition, mount, unpackfs, machineid, fstab, locale, keyboard, localecfg, shellprocess@before, users, networkcfg, hwclock, initramfscfg, initramfs, grubcfg, bootloader, umount]
- show: [finished]
branding: kora
prompt-install: true
dont-chroot: false
Y
cat > /etc/calamares/branding/kora/branding.desc <<'Y'
---
componentName: kora
welcomeStyleCalamares: false
strings: { productName: "Kora OS", shortProductName: Kora, version: "0.1", shortVersion: "0.1", versionedName: "Kora OS 0.1", shortVersionedName: "Kora 0.1", bootloaderEntryName: Kora }
images: { productLogo: logo.png, productIcon: logo.png, productWelcome: logo.png }
slideshow: [ slide.png ]
style: { SidebarBackground: "#1e1e2e", SidebarText: "#ffffff", SidebarTextCurrent: "#22d3ee", SidebarBackgroundCurrent: "#2a2a3e" }
Y
M=/etc/calamares/modules
printf 'unpack:\n- { source: /cdrom/casper/filesystem.squashfs, sourcefs: squashfs, destination: "" }\n' > $M/unpackfs.conf
printf 'dontChroot: false\ntimeout: 600\nscript:\n- "-userdel -r kora"\n- "-rm -f /etc/systemd/system/getty@tty1.service.d/a.conf /etc/sudoers.d/casper"\n- "-dpkg -P casper"\n' > $M/shellprocess_before.conf
printf 'defaultGroups: [sudo, audio, video]\nautologinGroup: autologin\nsudoersGroup: sudo\nsetRootPassword: false\ndoAutologin: false\n' > $M/users.conf
printf 'region: "Europe"\nzone: "Moscow"\n' > $M/locale.conf
printf 'requirements:\n  requiredStorage: 8\n  requiredRam: 1.0\n  check: [storage, ram, root]\n  required: [storage, ram, root]\nshowSupportUrl: false\n' > $M/welcome.conf
printf 'efiBootLoader: grub\nkernelSearchPath: /boot\ngrubInstall: grub-install\ngrubMkconfig: grub-mkconfig\ngrubCfg: /boot/grub/grub.cfg\ngrubProbe: grub-probe\nefiBootMgr: efibootmgr\ninstallEFIFallback: true\nefiBootloaderId: kora\n' > $M/bootloader.conf
true # default module configs copied from calamares 3.3.5 source on host
# user configs
H=/home/kora; C=$H/.config
grep -q nm-applet $C/labwc/autostart || printf 'nm-applet --indicator &\nblueman-applet &\n' >> $C/labwc/autostart
cat > $C/waybar/top.json <<'J'
{"position":"top","height":26,
"modules-left":["image#logo","custom/logo","wlr/taskbar"],"modules-right":["tray","network","pulseaudio","battery","custom/settings","custom/clock"],
"image#logo":{"path":"/usr/share/kora/logo-36.png","size":18,"on-click":"wofi --show drun"},
"custom/logo":{"format":"Kora","on-click":"wofi --show drun"},
"tray":{"spacing":6},
"network":{"format-wifi":"📶 {essid}","format-ethernet":"🌐","format-disconnected":"⚠ нет сети","on-click":"foot -e nmtui-connect"},
"pulseaudio":{"format":"🔊 {volume}%","format-muted":"🔇","on-click":"pavucontrol","on-click-right":"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"},
"battery":{"format":"🔋 {capacity}%"},
"custom/settings":{"format":"⚙","tooltip":false,"on-click":"kora-settings"},
"custom/clock":{"exec":"LC_TIME=ru_RU.UTF-8 date +'%a %d %b  %H:%M'","interval":20}}
J
cat > $C/waybar/dock.json <<'J'
{"position":"bottom","height":52,"margin-bottom":6,"name":"dock","modules-center":
["custom/files","custom/web","custom/tor","custom/office","custom/tg","custom/zoom","custom/term","custom/settings","custom/install"],
"custom/files":{"format":"📁","on-click":"thunar"},
"custom/web":{"format":"🌐","on-click":"epiphany-browser"},
"custom/tor":{"format":"🧅","on-click":"torbrowser-launcher"},
"custom/office":{"format":"📄","on-click":"libreoffice"},
"custom/tg":{"format":"✈️","on-click":"kora-telegram"},
"custom/zoom":{"format":"🎥","on-click":"kora-zoom"},
"custom/term":{"format":"⌨️","on-click":"foot"},
"custom/settings":{"format":"⚙️","on-click":"kora-settings"},
"custom/install":{"exec":"echo 💿","exec-if":"test -e /cdrom/casper","interval":"once","tooltip-format":"Установить Kora OS","on-click":"kora-install"}}
J
cat > $C/waybar/style.css <<'J'
*{font-family:Inter,sans-serif;font-size:13px;color:#eee}
window#waybar{background:rgba(30,30,46,.75)}
window#waybar.dock{background:transparent}
.dock .modules-center{background:rgba(255,255,255,.15);border-radius:16px;padding:0 8px}
window#waybar.dock label{font-size:26px;padding:0 10px}
#network,#pulseaudio,#battery,#tray,#custom-settings{padding:0 8px}
J
chown -R kora:kora $H
cp -a $C $H/.bash_profile $H/.hushlogin /etc/skel/
update-initramfs -u -k all
apt-get clean; rm -rf /var/lib/apt/lists/*
ls /etc/grub.d | head -3
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
cp $R/boot/initrd.img-* $I/casper/initrd
printf 'set timeout=3\nmenuentry "Kora OS" { linux /casper/vmlinuz boot=casper username=kora hostname=kora quiet splash; initrd /casper/initrd }\n' > $I/boot/grub/grub.cfg
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
grub-mkrescue -o /home/claude/kora-os.iso $I -volid KORA
ls -lh /home/claude/kora-os.iso
