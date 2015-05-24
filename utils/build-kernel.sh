#!/bin/sh
# use: utils/build-kernel.sh [no args]
# build a grsecurity-patched kernel (https://grsecurity.net/) and
# a vanilla kernel, adding both to boot menu.
 
if ENABLE_GRSEC=1 butch rebuild kernel ; then
mv /boot/vmlinuz /boot/vmlinuz-grsec
mv /boot/System.map /boot/System.map-grsec
cat << EOF > /boot/extlinux.conf
PROMPT 1
TIMEOUT 100
DEFAULT sabotage

LABEL sabotage
        KERNEL vmlinuz
        APPEND root=/dev/sda1 rw vga=ask

LABEL sabotage-grsec
        KERNEL vmlinuz-grsec
        APPEND root=/dev/sda1 rw vga=ask

LABEL rescue
        KERNEL vmlinuz
        APPEND root=/dev/sda1 rw

EOF
butch rebuild kernel
fi
