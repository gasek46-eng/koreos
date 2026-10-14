#!/bin/bash
# Kora 0.3.2: live login password, brightness permissions/device, silent shutdown
set -ex
R=/home/claude/kora/root; I=/home/claude/kora/iso
# live user password "kora" (casper blanks it at boot)
cat > $R/etc/systemd/system/kora-live-pass.service <<'S'
[Unit]
Description=Set Kora live user password
ConditionKernelCommandLine=boot=casper
Before=display-manager.service
After=local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'id kora >/dev/null 2>&1 && echo kora:kora | chpasswd; usermod -aG video,input kora 2>/dev/null || true'
[Install]
WantedBy=multi-user.target
S
ln -sf /etc/systemd/system/kora-live-pass.service $R/etc/systemd/system/multi-user.target.wants/kora-live-pass.service
# backlight writable by the logged-in user; prefer the native (raw) device
printf 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod 0666 /sys/class/backlight/%%k/brightness"\n' > $R/etc/udev/rules.d/90-kora-backlight.rules
cat > $R/usr/local/bin/brightnessctl <<'S'
#!/bin/sh
case " $* " in *" -d "*|*" -l "*|*" --list "*) exec /usr/bin/brightnessctl "$@";; esac
D=""; for t in raw firmware platform; do for d in /sys/class/backlight/*; do [ -e "$d/type" ] && [ "$(cat $d/type)" = $t ] && { D=$(basename $d); break 2; }; done; done
[ -n "$D" ] && exec /usr/bin/brightnessctl -d "$D" "$@"; exec /usr/bin/brightnessctl "$@"
S
chmod +x $R/usr/local/bin/brightnessctl
# waybar backlight module: same device
for H in $R/home/kora $R/etc/skel; do python3 - "$H/.config/waybar/top.json" <<'P'
import json,sys; p=sys.argv[1]; j=json.load(open(p)); j['backlight']['device']='intel_backlight'; json.dump(j,open(p,'w'),ensure_ascii=False,indent=1)
P
done
# no "remove medium" prompt at shutdown
sed -i 's#boot=casper #boot=casper noprompt noeject #' $I/boot/grub/grub.cfg
grep -c noprompt $I/boot/grub/grub.cfg
rm -f $I/casper/filesystem.squashfs
mksquashfs $R $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 15 -noappend -quiet -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'tmp/*'
bash /home/claude/improve/mkiso.sh /home/claude/kora-os-0.3.2.iso
cd /home/claude && sha256sum kora-os-0.3.2.iso > kora-os-0.3.2.iso.sha256
