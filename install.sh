#!/bin/bash
# Kora shell on top of an existing Ubuntu 26.04 — no USB stick needed.
#   curl -fsSL https://raw.githubusercontent.com/gasek46-eng/koreos/main/install.sh | bash
# Adds a "Kora" session to the login screen; your current desktop stays available.
set -euo pipefail
REPO=${KORA_REPO:-https://github.com/gasek46-eng/koreos}
BRANCH=${KORA_BRANCH:-main}
say() { echo -e "\033[1;35mKora:\033[0m $*"; }

[ "$(id -u)" = 0 ] && { echo "Запускайте от обычного пользователя (sudo спросит пароль сам)."; exit 1; }
. /etc/os-release
case "$VERSION_ID" in 26.04) ;; *) say "проверено на Ubuntu 26.04, у вас $PRETTY_NAME — продолжаю на ваш риск"; sleep 3;; esac

say "устанавливаю пакеты (нужен пароль администратора)"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk labwc xwayland \
  waybar wofi swaybg swaylock swayidle mako-notifier foot wlsunset grim slurp wl-clipboard libnotify-bin wdisplays \
  pipewire pipewire-pulse wireplumber blueman brightnessctl power-profiles-daemon upower \
  fonts-inter fonts-noto-color-emoji fonts-materialdesignicons-webfont papirus-icon-theme breeze-cursor-theme gnome-themes-extra \
  libglib2.0-bin python3-gi gir1.2-gtk-4.0 gir1.2-adw-1 nautilus gnome-calculator gnome-text-editor file-roller mpv epiphany-browser extrepo git
sudo apt-get install -y --no-install-recommends adw-gtk3 2>/dev/null || true

say "скачиваю Kora"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git clone -q --depth 1 -b "$BRANCH" "$REPO" "$T/k"
O=$T/k/build/overlay

say "копирую файлы системы"
sudo cp -a $O/usr/local/bin/. /usr/local/bin/ && sudo chmod +x /usr/local/bin/kora-*
sudo rm -f /usr/local/bin/kora-postinstall /usr/local/bin/kora-install
sudo mkdir -p /usr/share/kora /usr/share/wayland-sessions
sudo cp -a $O/usr/share/kora/. /usr/share/kora/
sudo cp $O/usr/share/wayland-sessions/kora.desktop /usr/share/wayland-sessions/
sudo cp $O/etc/udev/rules.d/90-kora-backlight.rules /etc/udev/rules.d/ && sudo udevadm trigger -s backlight || true
sudo cp -n $O/etc/fonts/local.conf /etc/fonts/local.conf 2>/dev/null || true

say "настраиваю ваш профиль (старые настройки сохраню в ~/.config/kora-backup)"
B=~/.config/kora-backup/$(date +%Y%m%d-%H%M%S); mkdir -p "$B"
for d in hypr labwc waybar foot mako wofi; do [ -e ~/.config/$d ] && mv ~/.config/$d "$B/"; done
cp -a $O/etc/skel/.config/. ~/.config/
python3 - <<'P'
import json,os; p=os.path.expanduser('~/.config/waybar/dock.json'); j=json.load(open(p))
j['modules-center']=[m for m in j['modules-center'] if m!='image#install']; j.pop('image#install',None); json.dump(j,open(p,'w'),ensure_ascii=False,indent=1)
P
kora-theme night --noapply

say "готово! Выйдите из системы и на экране входа выберите сеанс «Kora» (значок шестерёнки или меню сеансов)."
say "вернуть прежний вид: выберите старый сеанс; ваши настройки лежат в $B"
