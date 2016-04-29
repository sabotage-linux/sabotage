#!/bin/sh
# use: setup-rootfs.sh [no args, uses $H/config]
# used for cross-compilation
# this prepares a chroot-like directory containing the root file system
 
export H="$PWD"
[ -z "$CONFIG" ] && CONFIG=./config
. "$CONFIG"

if [ -z "$R" ]; then
    printf -- "ERROR: invalid or no config file\n"
    exit 1
fi

# enable verbose printing, abort on error
set -e

mkdir -p "$K" "$C" "$S" "$R" "$LOGPATH"

cd "$R"
mkdir -p boot bin dev etc home lib mnt proc root share srv src sys tmp var
mkdir -p src/logs src/build var/log/sshd var/log/crond var/log/dmesg
mkdir -p var/empty var/service var/lib var/spool/cron/crontabs

# usr and sbin are a mistake
ln -sfn . usr
ln -sfn bin sbin

ln -sfn ../tmp var/tmp

chmod 775 src/build
chmod 1777 tmp
chmod 700 root

cp -r "$K"/etc/* "$R"/etc/
cp -r "$K"/boot/* "$R"/boot/
cp -r "$K"/share/* "$R"/share/
chmod 0600 "$R"/etc/shadow

cp "$K"/runsvdir-start "$R"/bin
cp "$K"/cryptmount "$R"/bin
cp "$K"/dhclient "$R"/bin

echo nameserver 8.8.8.8 > "$R"/etc/resolv.conf

cat << 'EOF' > "$R"/bin/la && chmod +x "$R"/bin/la
#!/bin/sh
ls -la "$@"
EOF

cat << 'EOF' > "$R"/bin/lat && chmod +x "$R"/bin/lat
#!/bin/sh
ls -lat $@
EOF

