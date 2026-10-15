#!/bin/bash
# boot-test.sh kora.iso — boots the ISO as a USB stick in QEMU (UEFI) and fails unless a desktop appears.
set -u
ISO=$1; D=$(mktemp -d); OVMF=/usr/share/OVMF/OVMF_CODE_4M.fd; [ -e $OVMF ] || OVMF=/usr/share/OVMF/OVMF_CODE.fd
VARS=/usr/share/OVMF/OVMF_VARS_4M.fd; [ -e $VARS ] || VARS=/usr/share/OVMF/OVMF_VARS.fd; cp $VARS $D/vars.fd
ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
qemu-system-x86_64 -machine q35,accel=$ACCEL -m 3G -smp 2 -display none -vga virtio \
  -drive if=pflash,format=raw,readonly=on,file=$OVMF -drive if=pflash,format=raw,file=$D/vars.fd \
  -device qemu-xhci -drive if=none,id=u,format=raw,file="$ISO",readonly=on -device usb-storage,drive=u,bootindex=0 \
  -monitor unix:$D/mon,server,nowait &
Q=$!; trap 'kill $Q 2>/dev/null' EXIT
for i in $(seq 1 60); do        # up to 15 min
  sleep 15; echo "screendump $D/s.ppm" | socat - unix-connect:$D/mon >/dev/null 2>&1
  R=$(python3 -I - $D/s.ppm <<'P'
import sys
try:
    d=open(sys.argv[1],'rb').read()
    h=d.split(b'\n',3); w,hh=map(int,h[1].split()); px=h[3]
    s=px[::3*997]; cols=len(set(s[i:i+3] for i in range(0,len(s)-2,3)))
    print(cols)
except Exception: print(0)
P
)
  echo "t=$((i*15))s distinct-colours=$R"
  [ "${R:-0}" -gt 400 ] && { cp $D/s.ppm boot-ok.ppm; echo BOOT OK; exit 0; }
done
cp $D/s.ppm boot-fail.ppm 2>/dev/null; echo "BOOT FAILED"; exit 1
