#!/bin/bash
# Kora 0.3.1 (part 2): desktop themes, brightness slider, media keys
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso; A=/home/claude/v03
cp $A/wall-*.png $R/usr/share/kora/
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update; apt-get install -y --no-install-recommends python3-gi gir1.2-gtk-3.0
cat > /usr/local/bin/kora-theme <<'S'
#!/bin/sh
T="night:Ночь (тёмная)
day:День (светлая)
ocean:Океан
forest:Лес
sunset:Закат
graphite:Графит"
n=$1
[ -z "$n" ] && { sel=$(echo "$T" | cut -d: -f2 | wofi --dmenu -i -p "Тема оформления") || exit 0; n=$(echo "$T" | grep ":$sel\$" | cut -d: -f1); }
case $n in
night) BAR="30,30,46"; FG="#eeeeee"; DOCK="255,255,255,.15"; HV="255,255,255,.18"; DARK=1;;
day) BAR="250,250,255"; FG="#1e1e2e"; DOCK="255,255,255,.6"; HV="0,0,0,.08"; DARK=0;;
ocean) BAR="10,40,70"; FG="#e6f4ff"; DOCK="120,190,255,.18"; HV="120,190,255,.25"; DARK=1;;
forest) BAR="18,44,32"; FG="#e8f5ec"; DOCK="140,220,170,.16"; HV="140,220,170,.25"; DARK=1;;
sunset) BAR="70,30,60"; FG="#fff0f5"; DOCK="255,170,200,.18"; HV="255,170,200,.28"; DARK=1;;
graphite) BAR="40,41,46"; FG="#f0f0f0"; DOCK="255,255,255,.12"; HV="255,255,255,.2"; DARK=1;;
*) exit 1;;
esac
C=~/.config; mkdir -p $C/kora $C/gtk-3.0; echo $n > $C/kora/theme
cat > $C/waybar/style.css <<CSS
*{font-family:Inter,sans-serif;font-size:13px;color:$FG}
window#waybar{background:rgba($BAR,.78)}
window#waybar.dock{background:transparent}
.dock .modules-center{background:rgba($DOCK);border-radius:18px;padding:2px 8px;border:1px solid rgba($HV)}
.dock image{padding:4px 8px 8px 8px;border-radius:12px;transition:all 150ms ease}
.dock image:hover{padding:0 8px 12px 8px;background:rgba($HV)}
#network,#pulseaudio,#battery,#backlight,#tray,#custom-settings{padding:0 8px}
CSS
I=Papirus; [ $DARK = 1 ] && I=Papirus-Dark
printf "[Settings]\ngtk-application-prefer-dark-theme=$DARK\ngtk-icon-theme-name=$I\n" > $C/gtk-3.0/settings.ini
W=/usr/share/kora/wall-$n.png
sed -i "s#^swaybg.*#swaybg -i $W -m fill \&#" $C/labwc/autostart
[ -n "$KORA_NOAPPLY" ] && exit 0
pkill swaybg; setsid swaybg -i $W -m fill >/dev/null 2>&1 &
pkill -x waybar; sleep 0.3; for b in top dock; do setsid waybar -c $C/waybar/$b.json -s $C/waybar/style.css >/dev/null 2>&1 & done
S
cat > /usr/local/bin/kora-brightness <<'S'
#!/usr/bin/env python3
import gi, subprocess
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
def get():
    try:
        c = int(subprocess.check_output(['brightnessctl', 'g'])); m = int(subprocess.check_output(['brightnessctl', 'm']))
        return c * 100 / m
    except Exception:
        return 50
w = Gtk.Window(title='Яркость экрана'); w.set_default_size(380, 70); w.set_border_width(16)
b = Gtk.Box(spacing=12); b.pack_start(Gtk.Label(label='☀'), False, False, 0)
s = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 5, 100, 1); s.set_value(get()); s.set_hexpand(True)
s.connect('value-changed', lambda x: subprocess.run(['brightnessctl', '-q', 's', f'{int(x.get_value())}%']))
b.pack_start(s, True, True, 0); w.add(b); w.connect('destroy', Gtk.main_quit); w.show_all(); Gtk.main()
S
cat > /usr/local/bin/kora-settings <<'S'
#!/bin/sh
c=$(printf '📶 Wi-Fi и сеть\n🔊 Звук\n☀ Яркость экрана\n🎨 Темы оформления\n🖼 Обои\n🖥 Экран\n🔵 Bluetooth\n💿 Установить Kora OS\n🔄 Перезагрузить\n⏻ Выключить' | wofi --dmenu -i -p Настройки)
case "$c" in
*Wi-Fi*) foot -e nmtui-connect;; *Звук*) pavucontrol;; *Яркость*) kora-brightness;; *Темы*) kora-theme;;
*Экран*) wdisplays;; *Bluetooth*) blueman-manager;;
*Обои*) f=$(ls /usr/share/kora/wall-*.png ~/Изображения/*.* ~/Pictures/*.* 2>/dev/null | wofi --dmenu -p Обои) && { pkill swaybg; sed -i "s#^swaybg.*#swaybg -i '$f' -m fill \&#" ~/.config/labwc/autostart; setsid swaybg -i "$f" -m fill >/dev/null 2>&1 & };;
*Установить*) kora-install;; *Перезагрузить*) systemctl reboot;; *Выключить*) systemctl poweroff;;
esac
S
chmod +x /usr/local/bin/kora-*
for H in /home/kora /etc/skel; do C=$H/.config
python3 - "$C/waybar/top.json" <<'P'
import json,sys
p=sys.argv[1]; j=json.load(open(p)); r=j['modules-right']
if 'backlight' not in r: r.insert(r.index('battery'),'backlight')
j['backlight']={"format":"☀ {percent}%","on-click":"kora-brightness","on-scroll-up":"brightnessctl -q s +5%","on-scroll-down":"brightnessctl -q s 5%-","tooltip":False}
json.dump(j,open(p,'w'),ensure_ascii=False,indent=1)
P
cat > $C/labwc/rc.xml <<'X'
<?xml version="1.0"?><labwc_config>
<theme><name>Adwaita</name><cornerRadius>10</cornerRadius><font><name>Inter</name><size>10</size></font></theme>
<keyboard>
 <keybind key="W-space"><action name="Execute" command="wofi --show drun"/></keybind>
 <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
 <keybind key="W-q"><action name="Close"/></keybind>
 <keybind key="XF86MonBrightnessUp"><action name="Execute" command="brightnessctl -q s +5%"/></keybind>
 <keybind key="XF86MonBrightnessDown"><action name="Execute" command="brightnessctl -q s 5%-"/></keybind>
 <keybind key="XF86AudioRaiseVolume"><action name="Execute" command="wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"/></keybind>
 <keybind key="XF86AudioLowerVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"/></keybind>
 <keybind key="XF86AudioMute"><action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"/></keybind>
</keyboard></labwc_config>
X
HOME=$H KORA_NOAPPLY=1 kora-theme night
done
chown -R kora:kora /home/kora
apt-get clean; rm -rf /var/lib/apt/lists/*
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
bash /home/claude/improve/mkiso.sh /home/claude/kora-os-0.3.1.iso
cd /home/claude && sha256sum kora-os-0.3.1.iso > kora-os-0.3.1.iso.sha256
# --- panel supervisor (added after testing) ---
R=/home/claude/kora/root
printf '#!/bin/sh\nwhile :; do waybar -c ~/.config/waybar/$1.json -s ~/.config/waybar/style.css >/dev/null 2>&1; sleep 0.5; done\n' > $R/usr/local/bin/kora-panel; chmod +x $R/usr/local/bin/kora-panel
for H in $R/home/kora $R/etc/skel; do sed -i -e '/waybar.*top.json/c\kora-panel top &' -e '/waybar.*dock.json/c\kora-panel dock &' $H/.config/labwc/autostart; done
sed -i 's#^pkill -x waybar; sleep 0.3; for b in top dock.*#pkill -x waybar#' $R/usr/local/bin/kora-theme
