#!/bin/bash
# Kora 0.3: HWE kernel, LightDM login, icon dock, light theme, LibreWolf on first run
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso; A=/home/claude/v03
mkdir -p $R/usr/share/kora/icons; cp $A/icons/*.png $R/usr/share/kora/icons/; cp $A/wallpaper-light.png $R/usr/share/kora/
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends linux-generic-hwe-24.04 lightdm lightdm-gtk-greeter xserver-xorg-core xserver-xorg-input-libinput gnome-themes-extra extrepo librsvg2-common
apt-get purge -y linux-generic linux-image-generic linux-headers-generic 'linux-image-6.8*' 'linux-modules-6.8*' 'linux-modules-extra-6.8*' || true
apt-get autoremove -y --purge
# login screen
mkdir -p /etc/lightdm/lightdm.conf.d /usr/share/wayland-sessions
printf '[Seat:*]\ngreeter-session=lightdm-gtk-greeter\nuser-session=kora\nautologin-user=kora\nautologin-session=kora\n' > /etc/lightdm/lightdm.conf.d/50-kora.conf
printf '[Desktop Entry]\nName=Kora\nExec=env WLR_RENDERER_ALLOW_SOFTWARE=1 labwc\nType=Application\n' > /usr/share/wayland-sessions/kora.desktop
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<'G'
[greeter]
background=/usr/share/kora/wallpaper.png
user-background=false
theme-name=Adwaita-dark
icon-theme-name=Papirus-Dark
font-name=Inter 11
default-user-image=/usr/share/kora/logo-256.png
indicators=~host;~spacer;~clock;~spacer;~layout;~power
clock-format=%a %d %b  %H:%M
position=50%,center 55%,center
G
ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
rm -f /etc/systemd/system/getty@tty1.service.d/a.conf
# installer: no autologin on installed system
grep -q 50-kora /etc/calamares/modules/shellprocess_before.conf || echo '- "-sed -i /^autologin/d /etc/lightdm/lightdm.conf.d/50-kora.conf"' >> /etc/calamares/modules/shellprocess_before.conf
grep -q image.install /etc/calamares/modules/shellprocess_before.conf || echo '- "-sed -i s/,.image#install.// /etc/skel/.config/waybar/dock.json"' >> /etc/calamares/modules/shellprocess_before.conf
# browser: LibreWolf on first run
cat > /usr/local/bin/kora-browser <<'S'
#!/bin/sh
command -v librewolf >/dev/null && exec librewolf "$@"
foot -e sh -c 'echo "Устанавливаю LibreWolf (нужен интернет)..."; sudo extrepo enable librewolf && sudo apt-get update && sudo apt-get install -y librewolf && (setsid librewolf &) || { echo "Не получилось — открываю Epiphany"; sleep 3; setsid epiphany-browser & }; sleep 1'
S
# theme toggle
cat > /usr/local/bin/kora-theme <<'S'
#!/bin/sh
C=~/.config/waybar; L=~/.config/labwc/autostart
if grep -q LIGHT $C/style.css; then cp $C/dark.css $C/style.css; w=wallpaper.png; d=1; else cp $C/light.css $C/style.css; w=wallpaper-light.png; d=0; fi
mkdir -p ~/.config/gtk-3.0; printf "[Settings]\ngtk-application-prefer-dark-theme=$d\n" > ~/.config/gtk-3.0/settings.ini
sed -i "s#^swaybg.*#swaybg -i /usr/share/kora/$w -m fill \&#" $L; pkill swaybg; setsid swaybg -i /usr/share/kora/$w -m fill >/dev/null 2>&1 &
pkill -USR2 waybar
S
chmod +x /usr/local/bin/kora-*
sed -i 's#^\*Установить\*) kora-install;;#&#; s#💿 Установить Kora OS\\n#🌓 Светлая / тёмная тема\\n💿 Установить Kora OS\\n#; s#\*Установить\*) kora-install;;#*тема*) kora-theme;; *Установить*) kora-install;;#' /usr/local/bin/kora-settings
for H in /home/kora /etc/skel; do C=$H/.config
sed -i '/exec labwc/d' $H/.bash_profile
I=/usr/share/kora/icons
cat > $C/waybar/dock.json <<J
{"position":"bottom","height":60,"margin-bottom":6,"name":"dock","modules-center":
["image#files","image#web","image#tor","image#office","image#tg","image#zoom","image#term","image#settings","image#install"],
"image#files":{"path":"$I/files.png","size":44,"on-click":"thunar","tooltip":false},
"image#web":{"path":"$I/web.png","size":44,"on-click":"kora-browser","tooltip":false},
"image#tor":{"path":"$I/tor.png","size":44,"on-click":"torbrowser-launcher","tooltip":false},
"image#office":{"path":"$I/office.png","size":44,"on-click":"libreoffice","tooltip":false},
"image#tg":{"path":"$I/tg.png","size":44,"on-click":"kora-telegram","tooltip":false},
"image#zoom":{"path":"$I/zoom.png","size":44,"on-click":"kora-zoom","tooltip":false},
"image#term":{"path":"$I/term.png","size":44,"on-click":"foot","tooltip":false},
"image#settings":{"path":"$I/settings.png","size":44,"on-click":"kora-settings","tooltip":false},
"image#install":{"path":"$I/install.png","size":44,"on-click":"kora-install","tooltip":false}}
J
DOCK='.dock .modules-center{background:BG;border-radius:18px;padding:2px 8px;border:1px solid BR}
.dock image{padding:4px 8px 8px 8px;border-radius:12px;transition:all 150ms ease}
.dock image:hover{padding:0 8px 12px 8px;background:HV}
#network,#pulseaudio,#battery,#tray,#custom-settings{padding:0 8px}'
{ echo '*{font-family:Inter,sans-serif;font-size:13px;color:#eee}
window#waybar{background:rgba(30,30,46,.75)}
window#waybar.dock{background:transparent}'; echo "$DOCK" | sed 's/BG/rgba(255,255,255,.15)/;s/BR/rgba(255,255,255,.12)/;s/HV/rgba(255,255,255,.18)/'; } > $C/waybar/dark.css
{ echo '/*LIGHT*/ *{font-family:Inter,sans-serif;font-size:13px;color:#1e1e2e}
window#waybar{background:rgba(250,250,255,.75)}
window#waybar.dock{background:transparent}'; echo "$DOCK" | sed 's/BG/rgba(255,255,255,.6)/;s/BR/rgba(0,0,0,.08)/;s/HV/rgba(0,0,0,.08)/'; } > $C/waybar/light.css
cp $C/waybar/dark.css $C/waybar/style.css
mkdir -p $C/gtk-3.0; printf '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-icon-theme-name=Papirus-Dark\n' > $C/gtk-3.0/settings.ini
done
chown -R kora:kora /home/kora
apt-get clean; rm -rf /var/lib/apt/lists/*
ls /boot
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
cp $(ls $R/boot/vmlinuz-* | tail -1) $I/casper/vmlinuz; cp $(ls $R/boot/initrd.img-* | tail -1) $I/casper/initrd
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
bash /home/claude/improve/mkiso.sh /home/claude/kora-os.iso
