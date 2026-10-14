#!/bin/bash
# Kora OS prototype — run on Debian 13 minimal (x86_64) as normal user with sudo
set -e
sudo apt update
sudo apt install -y labwc waybar wofi swaybg mako-notifier foot thunar \
  fonts-inter papirus-icon-theme pipewire wireplumber network-manager \
  libreoffice-gtk3 telegram-desktop torbrowser-launcher extrepo wget
sudo extrepo enable librewolf && sudo apt update && sudo apt install -y librewolf
wget -qO /tmp/zoom.deb https://zoom.us/client/latest/zoom_amd64.deb && sudo apt install -y /tmp/zoom.deb || true

C=~/.config; mkdir -p $C/labwc $C/waybar $C/wofi

cat > $C/labwc/autostart <<'E'
swaybg -c '#1e1e2e' &
mako &
waybar -c ~/.config/waybar/top.json -s ~/.config/waybar/style.css &
waybar -c ~/.config/waybar/dock.json -s ~/.config/waybar/style.css &
E
cat > $C/labwc/rc.xml <<'E'
<?xml version="1.0"?><labwc_config>
<theme><name>Adwaita</name><cornerRadius>10</cornerRadius><font><name>Inter</name><size>10</size></font></theme>
<keyboard>
 <keybind key="W-space"><action name="Execute" command="wofi --show drun"/></keybind>
 <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
 <keybind key="W-q"><action name="Close"/></keybind>
</keyboard></labwc_config>
E
cat > $C/waybar/top.json <<'E'
{"position":"top","height":26,
"modules-left":["custom/logo","wlr/taskbar"],"modules-right":["network","pulseaudio","battery","clock"],
"custom/logo":{"format":"◆ Kora","on-click":"wofi --show drun"},
"clock":{"format":"{:%a %d %b  %H:%M}"}}
E
cat > $C/waybar/dock.json <<'E'
{"position":"bottom","height":52,"margin-bottom":6,"name":"dock","modules-center":
["custom/files","custom/web","custom/tor","custom/office","custom/tg","custom/zoom","custom/term"],
"custom/files":{"format":"📁","on-click":"thunar"},
"custom/web":{"format":"🌐","on-click":"librewolf"},
"custom/tor":{"format":"🧅","on-click":"torbrowser-launcher"},
"custom/office":{"format":"📄","on-click":"libreoffice"},
"custom/tg":{"format":"✈️","on-click":"telegram-desktop"},
"custom/zoom":{"format":"🎥","on-click":"zoom"},
"custom/term":{"format":"⌨️","on-click":"foot"}}
E
cat > $C/waybar/style.css <<'E'
*{font-family:Inter;font-size:13px;color:#eee}
window#waybar{background:rgba(30,30,46,.75)}
window#waybar.dock{background:transparent}
.dock .modules-center{background:rgba(255,255,255,.15);border-radius:16px;padding:0 8px}
.dock #custom-files,.dock #custom-web,.dock #custom-tor,.dock #custom-office,
.dock #custom-tg,.dock #custom-zoom,.dock #custom-term{font-size:26px;padding:0 10px}
E

grep -q labwc ~/.bash_profile 2>/dev/null || echo '[ "$(tty)" = /dev/tty1 ] && exec labwc' >> ~/.bash_profile
echo "Готово. Перезайдите на tty1."
