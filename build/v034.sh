#!/bin/bash
# Kora 0.3.1 (part 4): calculator swap, GNOME app translations, dark/light for GTK4 apps
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso
for d in dev dev/pts proc sys; do mount --bind /$d $R/$d; done
trap 'for d in dev/pts dev proc sys; do umount -l $R/$d || true; done' EXIT
chroot $R bash -ex <<'C'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get purge -y galculator
apt-get install -y --no-install-recommends gnome-calculator language-pack-gnome-ru libglib2.0-bin dconf-gsettings-backend dconf-service
sed -i 's#^\[ -n "\$KORA_NOAPPLY" \] \&\& exit 0#S=default; [ $DARK = 1 ] \&\& S=prefer-dark; gsettings set org.gnome.desktop.interface color-scheme $S 2>/dev/null; gsettings set org.gnome.desktop.interface gtk-theme $G 2>/dev/null; gsettings set org.gnome.desktop.interface icon-theme $I 2>/dev/null; gsettings set org.gnome.desktop.interface cursor-theme breeze_cursors 2>/dev/null\n[ -n "$KORA_NOAPPLY" ] \&\& exit 0#' /usr/local/bin/kora-theme
grep -q 'kora-theme $(cat' /home/kora/.config/labwc/autostart || for H in /home/kora /etc/skel; do sed -i '1i KORA_NOAPPLY=1 kora-theme $(cat ~/.config/kora/theme 2>/dev/null || echo night)' $H/.config/labwc/autostart; done
chown -R kora:kora /home/kora
apt-get clean; rm -rf /var/lib/apt/lists/*
C
for d in dev/pts dev proc sys; do umount -l $R/$d; done; trap - EXIT
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
bash /home/claude/improve/mkiso.sh /home/claude/kora-os-0.3.1.iso
cd /home/claude && sha256sum kora-os-0.3.1.iso > kora-os-0.3.1.iso.sha256
