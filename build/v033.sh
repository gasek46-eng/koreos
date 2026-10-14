#!/bin/bash
# Kora 0.3.1 (part 3): apps, Wi-Fi menu, lock, screenshots, night light, volume, snapping, graphics polish
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends evince eog mpv galculator xarchiver swaylock swayidle grim slurp wlsunset wl-clipboard libnotify-bin \
  materia-gtk-theme breeze-cursor-theme libgl1-mesa-dri libegl-mesa0 intel-media-va-driver i965-va-driver mesa-va-drivers
# fonts
cat > /etc/fonts/local.conf <<'X'
<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><match target="font">
<edit name="antialias" mode="assign"><bool>true</bool></edit><edit name="hinting" mode="assign"><bool>true</bool></edit>
<edit name="hintstyle" mode="assign"><const>hintslight</const></edit><edit name="rgba" mode="assign"><const>rgb</const></edit>
<edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit></match></fontconfig>
X
B=/usr/local/bin
cat > $B/kora-wifi <<'S'
#!/bin/sh
n() { notify-send -i network-wireless "Wi-Fi" "$1"; }
st=$(nmcli radio wifi)
L=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null | awk -F: '$2!=""{printf "%s %s  %s%%%s\n",($1=="*"?"✔":"  "),$2,$3,($4!=""?"  🔒":"")}' | sort -u -k1,1r)
T=$( [ "$st" = enabled ] && echo "⏻ Выключить Wi-Fi" || echo "⏻ Включить Wi-Fi")
c=$(printf '%s\n%s\n⚙ Расширенные настройки' "$L" "$T" | sed '/^$/d' | wofi --dmenu -i -p "Wi-Fi") || exit 0
case "$c" in
*"Выключить Wi-Fi") nmcli radio wifi off; n "Выключен";; *"Включить Wi-Fi") nmcli radio wifi on; n "Включён";;
*"Расширенные"*) nm-connection-editor;;
*) s=$(echo "$c" | sed -E 's/^(✔|  ) //; s/  [0-9]+%.*$//')
   if nmcli -t -f NAME con show | grep -qx "$s"; then nmcli con up id "$s" >/dev/null && n "Подключено: $s" || n "Не удалось: $s"
   elif echo "$c" | grep -q 🔒; then p=$(wofi --dmenu --password -p "Пароль для $s" </dev/null) || exit 0
        nmcli dev wifi connect "$s" password "$p" >/dev/null 2>&1 && n "Подключено: $s" || n "Неверный пароль или ошибка: $s"
   else nmcli dev wifi connect "$s" >/dev/null 2>&1 && n "Подключено: $s" || n "Не удалось: $s"; fi;;
esac
S
cat > $B/kora-volume <<'S'
#!/usr/bin/env python3
import gi, subprocess, re
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
def get():
    try: return float(re.findall(r'[\d.]+', subprocess.check_output(['wpctl','get-volume','@DEFAULT_AUDIO_SINK@']).decode())[0]) * 100
    except Exception: return 50
w = Gtk.Window(title='Громкость'); w.set_default_size(380, 70); w.set_border_width(16)
b = Gtk.Box(spacing=12); b.pack_start(Gtk.Label(label='🔊'), False, False, 0)
s = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1); s.set_value(get()); s.set_hexpand(True)
s.connect('value-changed', lambda x: subprocess.run(['wpctl','set-volume','@DEFAULT_AUDIO_SINK@', f'{x.get_value()/100:.2f}']))
b.pack_start(s, True, True, 0); w.add(b); w.connect('destroy', Gtk.main_quit); w.show_all(); Gtk.main()
S
cat > $B/kora-lock <<'S'
#!/bin/sh
W=$(grep -o '/usr/share/kora/wall-[a-z]*.png' ~/.config/labwc/autostart | head -1); [ -n "$W" ] || W=/usr/share/kora/wall-night.png
exec swaylock -f -i "$W" -s fill --indicator-radius 80 --inside-color 1e1e2ecc --ring-color 7c5cffff --key-hl-color 22d3eeff --text-color ffffffff
S
cat > $B/kora-shot <<'S'
#!/bin/sh
D=$(xdg-user-dir PICTURES 2>/dev/null); [ -d "$D" ] || D=~/Изображения; mkdir -p "$D"; F="$D/Скриншот $(date '+%Y-%m-%d %H-%M-%S').png"
if [ "$1" = area ]; then g=$(slurp) || exit 0; grim -g "$g" "$F"; else grim "$F"; fi
wl-copy < "$F"; notify-send -i "$F" "Скриншот сохранён" "$(basename "$F") — и скопирован в буфер"
S
cat > $B/kora-nightlight <<'S'
#!/bin/sh
if pgrep -x wlsunset >/dev/null; then pkill -x wlsunset; rm -f ~/.config/kora/night; notify-send "Ночной режим" "Выключен"
else setsid wlsunset -t 4000 -T 6500 -S 07:00 -s 20:00 >/dev/null 2>&1 & touch ~/.config/kora/night; notify-send "Ночной режим" "Включён: тёплый экран с 20:00 до 7:00"; fi
S
cat > $B/kora-settings <<'S'
#!/bin/sh
c=$(printf '📶 Wi-Fi и сеть\n🔊 Громкость\n☀ Яркость экрана\n🌙 Ночной режим вкл/выкл\n🎨 Темы оформления\n🖼 Обои\n🖥 Экран\n🔵 Bluetooth\n📸 Скриншот области\n🔒 Заблокировать\n💿 Установить Kora OS\n🔄 Перезагрузить\n⏻ Выключить' | wofi --dmenu -i -p Настройки)
case "$c" in
*Wi-Fi*) kora-wifi;; *Громкость*) kora-volume;; *Яркость*) kora-brightness;; *Ночной*) kora-nightlight;; *Темы*) kora-theme;;
*Экран*) wdisplays;; *Bluetooth*) blueman-manager;; *Скриншот*) kora-shot area;; *Заблокировать*) kora-lock;;
*Обои*) f=$(ls /usr/share/kora/wall-*.png ~/Изображения/*.* ~/Pictures/*.* 2>/dev/null | wofi --dmenu -p Обои) && { pkill swaybg; sed -i "s#^swaybg.*#swaybg -i '$f' -m fill \&#" ~/.config/labwc/autostart; setsid swaybg -i "$f" -m fill >/dev/null 2>&1 & };;
*Установить*) kora-install;; *Перезагрузить*) systemctl reboot;; *Выключить*) systemctl poweroff;;
esac
S
# theme engine: add GTK theme, window titlebars, terminal colors
python3 - <<'P'
p='/usr/local/bin/kora-theme'; s=open(p).read()
s=s.replace('night) BAR="30,30,46"; FG="#eeeeee"','night) TB="1e1e2e"; TT="eeeeee"; TERM="1e1e2e"; BAR="30,30,46"; FG="#eeeeee"')
s=s.replace('day) BAR="250,250,255"; FG="#1e1e2e"','day) TB="f2f2f7"; TT="1e1e2e"; TERM="fafafc"; BAR="250,250,255"; FG="#1e1e2e"')
s=s.replace('ocean) BAR="10,40,70"; FG="#e6f4ff"','ocean) TB="0f2f4f"; TT="e6f4ff"; TERM="0b2238"; BAR="10,40,70"; FG="#e6f4ff"')
s=s.replace('forest) BAR="18,44,32"; FG="#e8f5ec"','forest) TB="16382a"; TT="e8f5ec"; TERM="10261c"; BAR="18,44,32"; FG="#e8f5ec"')
s=s.replace('sunset) BAR="70,30,60"; FG="#fff0f5"','sunset) TB="4a2240"; TT="fff0f5"; TERM="2e1528"; BAR="70,30,60"; FG="#fff0f5"')
s=s.replace('graphite) BAR="40,41,46"; FG="#f0f0f0"','graphite) TB="2c2d32"; TT="f0f0f0"; TERM="1f2024"; BAR="40,41,46"; FG="#f0f0f0"')
s=s.replace('I=Papirus; [ $DARK = 1 ] && I=Papirus-Dark\nprintf "[Settings]\\ngtk-application-prefer-dark-theme=$DARK\\ngtk-icon-theme-name=$I\\n" > $C/gtk-3.0/settings.ini',
'''I=Papirus; G=Materia-light-compact; [ $DARK = 1 ] && { I=Papirus-Dark; G=Materia-dark-compact; }
printf "[Settings]\\ngtk-theme-name=$G\\ngtk-application-prefer-dark-theme=$DARK\\ngtk-icon-theme-name=$I\\ngtk-cursor-theme-name=breeze_cursors\\ngtk-font-name=Inter 10\\n" > $C/gtk-3.0/settings.ini
K=~/.local/share/themes/Kora/openbox-3; mkdir -p $K $C/foot
cat > $K/themerc <<TH
border.width: 1
padding.height: 6
window.label.text.justify: center
window.active.border.color: #$TB
window.inactive.border.color: #$TB
window.active.title.bg.color: #$TB
window.inactive.title.bg.color: #$TB
window.active.label.text.color: #$TT
window.inactive.label.text.color: #${TT}99
window.active.button.unpressed.image.color: #$TT
window.inactive.button.unpressed.image.color: #${TT}99
menu.items.bg.color: #$TB
menu.items.text.color: #$TT
menu.items.active.bg.color: #7c5cff
menu.items.active.text.color: #ffffff
osd.bg.color: #$TB
osd.label.text.color: #$TT
TH
printf "[main]\\nfont=monospace:size=11\\npad=10x8\\n[colors]\\nalpha=0.95\\nbackground=$TERM\\nforeground=$TT\\n" > $C/foot/foot.ini''')
s=s.replace('pkill -x waybar','labwc --reconfigure 2>/dev/null; pkill -x waybar')
open(p,'w').write(s)
P
chmod +x $B/kora-*
for H in /home/kora /etc/skel; do C=$H/.config
python3 - "$C/waybar/top.json" <<'P'
import json,sys
p=sys.argv[1]; j=json.load(open(p))
j['network']['on-click']='kora-wifi'
j['pulseaudio'].update({'on-click':'kora-volume','on-click-middle':'pavucontrol','on-scroll-up':'wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+','on-scroll-down':'wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-'})
json.dump(j,open(p,'w'),ensure_ascii=False,indent=1)
P
python3 - "$C/labwc/rc.xml" <<'P'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace('<name>Adwaita</name>','<name>Kora</name>')
add='''
 <keybind key="W-l"><action name="Execute" command="kora-lock"/></keybind>
 <keybind key="Print"><action name="Execute" command="kora-shot"/></keybind>
 <keybind key="S-Print"><action name="Execute" command="kora-shot area"/></keybind>
 <keybind key="W-Left"><action name="SnapToEdge" direction="left"/></keybind>
 <keybind key="W-Right"><action name="SnapToEdge" direction="right"/></keybind>
 <keybind key="W-Up"><action name="ToggleMaximize"/></keybind>
 <keybind key="W-Down"><action name="Iconify"/></keybind>
</keyboard>'''
if 'kora-lock' not in s: s=s.replace('\n</keyboard>',add,1)
open(p,'w').write(s)
P
grep -q swayidle $C/labwc/autostart || printf '[ -e /cdrom/casper ] || swayidle -w timeout 300 kora-lock before-sleep kora-lock &\n[ -e ~/.config/kora/night ] && wlsunset -t 4000 -T 6500 -S 07:00 -s 20:00 &\n' >> $C/labwc/autostart
grep -q XCURSOR $C/labwc/environment || printf 'XCURSOR_THEME=breeze_cursors\nXCURSOR_SIZE=24\n' >> $C/labwc/environment
mkdir -p $C/mpv; printf 'hwdec=auto-safe\nvo=gpu\n' > $C/mpv/mpv.conf
cat > $C/mimeapps.list <<'M'
[Default Applications]
application/pdf=org.gnome.Evince.desktop
image/png=org.gnome.eog.desktop
image/jpeg=org.gnome.eog.desktop
image/webp=org.gnome.eog.desktop
image/gif=org.gnome.eog.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
audio/mpeg=mpv.desktop
audio/x-wav=mpv.desktop
application/zip=xarchiver.desktop
application/x-7z-compressed=xarchiver.desktop
application/x-tar=xarchiver.desktop
M
HOME=$H KORA_NOAPPLY=1 kora-theme night
done
chown -R kora:kora /home/kora
apt-get clean; rm -rf /var/lib/apt/lists/*
ls /usr/share/icons | grep -i breeze; ls /usr/share/themes | grep -i materia | head -3
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
bash /home/claude/improve/mkiso.sh /home/claude/kora-os-0.3.1.iso
cd /home/claude && sha256sum kora-os-0.3.1.iso > kora-os-0.3.1.iso.sha256
