#!/bin/sh
# TODO: setuprw: copy files to a temporary place to install new packages and
#                  create new squashfs (something like do_chroot, but copy instead
#                  of mounting the squashfs
#       chroot: install_chroot
#                echo "/tmp/boot/squash-tool install $dev $size $rwfs $imgsize" | do_chroot
#       release: make a squash without running prereqs (make chroot rw)
#       src at install is by default missing tarballs and build dirs, make this configurable
#       fix infinite symlink loops in filesystem so copyrw doesn't need to dereference symlinks

sigs="SIGTERM SIGHUP SIGINT SIGQUIT SIGKILL SIGABRT SIGTSTP SIGTTIN SIGTTOU SIGEXIT ERR"
remove=""
mounts=""
loops=""
cryptlst=""

#transforms a string to hex
toelem() {
  local arg="${1:-}"
  [ -z "$arg" ] && return 1
  echo -n $arg |od -A n -t x1 |sed 's/ /_/g' |tr -d '\n'
}

#from hex back to string
fromelem() {
  local arg="${1:-}"
  [ -z "$arg" ] && return 1
  echo -e "$(echo -n $arg |sed -r 's,_,\\x,g')"
}

#space separated list of hex encoded string
push() {
  local list="${1:-}"
  local elem="${2:-}"
  [ -z "$elem" ] && return 1
  echo "$(toelem $elem) $list"
}

pop() { #TODO: if not element?
  local list="${1:-}"
  [ -z "$list" ] && return 1
  local elem="${2:-}"
  [ -z "$elem" ] && return 1
  local e="$(toelem $elem)"
  echo "$list" |sed -r "s,(^| )$e(|:|[^ ]+)?(\$| ),\3,"
}

last() {
  local list="${1:-}"
  fromelem $(echo "$list" |sed -r 's,(^|.* )([^ ]+)$,\2,g')
}

#lists for cleaning up on error/trap/finish
push_remove() {
  local elem="${1:-}"
  [ -z "$elem" ] && return 1
  remove=$(push "$remove" "$elem")
}

pop_remove() {
  local elem="${1:-}"
  [ -z "$elem" ] && return 1
  rm -rf "$elem"
  remove=$(pop "$remove" "$elem")
}

last_remove() {
  last "$remove"
}

push_mounts() {
  local elem="${1:-}"
  [ -z "$elem" ] && return 1
  mounts=$(push "$mounts" "$elem")
}

pop_mounts() {
  local elem="${1:-}"
  [ -z "$elem" ] && return 1
  sync
  if ! umount $elem; then
    if ! umount -f $elem; then
      if ! umount -l $elem; then
        mounts=$(pop "$mounts" "$elem")
        mounts=$(push "$mounts" "$elem")
        reloop
        return 1
      fi
    fi
  fi
  mounts=$(pop "$mounts" "$elem")
  reloop
}

last_mounts() {
  last "$mounts"
}

push_loops() {
  local lo="${1:-}"
  [ -z "$lo" ] && return 1
  local path="${2:-}"
  [ -z "$path" ] && return 1
  loops=$(push "$loops" "$lo|:|$path")
  sync
}

reloop() {
  local lo=""
  for lo in $loops; do
    local dev=$(fromelem "$lo" |sed 's,|:|.*,,g')
    local img=$(fromelem "$lo" |sed 's,.*|:|,,g')
    if ! losetup |grep -q "$dev"; then
      losetup "$dev" "$img"
      partx -d "$dev"
      partx -a "$dev"
      echo "Had to reloop $dev for $img"
    fi
  done
}

pop_loops() {
  local lo="${1:-}"
  [ -z "$lo" ] && return 1
  sync
  partx -d "$lo"
  losetup -d "$lo"
  loops=$(pop "$loops" "$lo")
}

last_loops() {
  last "$loops" |sed 's,|:|.*,,g'
}

push_crypt() {
  local elem="${1:-}"
  [ -z "$elem" ] && return 1
  cryptlst=$(push "$cryptlst" "$elem")
}

pop_crypt() {
  local elem="${1:-}"
  [ -z "$elem" ] && return 1
  if ! cryptsetup luksClose $elem; then
    if ! cryptsetup luksClose $elem; then
      cryptlst=$(pop "$cryptlst" "$elem")
      return 1
    fi
  fi
  cryptlst=$(pop "$cryptlst" "$elem")
}

last_crypt() {
  last "$cryptlst"
}

cleanup() {
  set +o errexit
  for sig in $sigs; do
    trap - $sig &>/dev/null
  done
  set +o pipefail
  set +o nounset
  while [ ! -z "$(last_mounts)" ]; do
    local e="$(last_mounts)"
    pop_mounts "$e" || pop_mounts "$e" || mounts=$(pop "$mounts" "$e")
  done
  while [ ! -z "$(last_crypt)" ]; do
    local e="$(last_crypt)"
    pop_crypt "$e"
  done
  while [ ! -z "$(last_loops)" ]; do
    local e="$(last_loops)"
    pop_loops "$e"
  done
  while [ ! -z "$(last_remove)" ]; do
    local e="$(last_remove)"
    pop_remove "$e"
  done
}

fail() {
  echo "Failure, cleaning up..."
  cleanup
  echo "$@"
  if [ -e /proc/sys/kernel/grsecurity ]; then
    echo 'If the script behaves weirdly or fails for no apparent reason'
    echo 'Make sure you disable chroot restrictions while the script is running'
    echo '(check dmesg for grsec errors)'
    echo 'quickfix: cd /proc/sys/kernel/grsecurity'
    echo '  for i in chroot_deny_*; do echo 0 > $i; done'
    echo '  echo 0 > chroot_restrict_nice'
  fi
  exit 1
}

usage() {
  echo "Usage: $0 chroot boot_dir"
  echo "Usage: $0 tarball dst.tar.xz (source|)"
  echo "Usage: $0 install device_path fat_size (n|rw_type [key_part])"
  echo "Usage: $0 install image_path fat_size (n|rw_type image_size [key_part])"
  echo "  rw_type can be btrfs; only rw is encrypted"
  echo "Usage: $0 in_chroot (install|tarball)..."
  echo "Usage: $0 mkinitramfs dst_initramfs"
  echo "Usage: $0 srctar dst.tar.xz do_tar_build (source_root|)"
  echo "  do_tar_build: whether to include tarballs and build dirs. defaults to no."
  echo "Usage: $0 update source_dir (boot_partition|boot_device) [key_part]"
  cleanup
  exit 1
}

setuptraps() {
  for sig in $sigs; do
    trap "fail Trapped signal $sig" $sig &>/dev/null
  done
  set -o pipefail
  set -o errexit
  set -o nounset
}

mksubvol() {
  local dev="${1:-}"
  local subname="${2:-}"
  local tmp="$(mktemp -d)"
  push_remove "$tmp"
  mount "$dev" "$tmp"
  push_mounts "$tmp"
  if [ ! -d "$tmp"/"$subname" ]; then
    btrfs subvolume create "$tmp"/"$subname"
  fi
  pop_mounts "$tmp"
  pop_remove "$tmp"
}

handle_fdisk() { #TODO: this is fugly. bug in busybox?
  local dev="${1:-}"
  [ -z "$dev" ] && return 1
  local fail=0
  local tmp="$(mktemp)"
  push_remove "$tmp"
  fdisk "$dev" 2> "$tmp" > /dev/null || fail=1
  if [ $fail -eq 1 ]; then
    if [ "$(cat $tmp |wc -l)" = "1" ]; then
      if egrep -q '^fdisk: WARNING: rereading partition table failed, kernel still uses old table: Invalid argument$' "$tmp"; then
        fail=0
      fi
    fi
  fi
  pop_remove "$tmp"
  return $fail
}

getuuid() {
  local part="${1:-}"
  [ -z "$part" ] && return 1
  blkid $part |sed -r 's,.*UUID="([^"]+)".*,\1,g'
}

runprereqs() {
  local src="${1:-}"
  if [ -z "${src}" ]; then
    src="/"
  elif [ "$(dirname ${src})" = "/" ]; then
    src="/"
  elif [ ! -d "${src}" ]; then
    return 1
  else
    mount -t proc procfs "${src}"/proc
    push_mounts "${src}"/proc
    mount -t sysfs sysfs "${src}"/sys
    push_mounts "${src}"/sys
    mount --bind /bin "${src}"/bin
    push_mounts "${src}"/bin
  fi
  (
    cd "${src}"
    for i in etc/service/*/run; do
      if [ ! -e "$(dirname $i)"/down ]; then
        chroot . /$i --prereqs || fail "Failed to run prereqs for $i"
      fi
    done
  )
  if [ "$src" != "/" ]; then
    pop_mounts "${src}"/bin
    pop_mounts "${src}"/sys
    pop_mounts "${src}"/proc
  fi
}

mktar_src() {
  local dst="${1:-}"
  [ -z "$dst" ] && return 1
  local dobuild="${2:-}"
  local src="${3:-}"
  if [ -z "${src}" ]; then
    src="/"
  elif [ ! -d "${src}" ]; then
    return 1
  fi
  local exclude='./tarballs/ ./build/'
  local tmp="$(mktemp)"
  push_remove "$tmp"
  if [ "$dobuild" != "yes" ]; then
    for e in $exclude; do
      echo "$e" >> "$tmp"
    done
  fi
  tar cJf "$dst" -X "$tmp" -C "${src}"/src .
  pop_remove "$tmp"
}

mksquash() {
  local dst="${1:-}"
  [ -z "$dst" ] && return 1
  local src="${2:-}"
  if [ -z "${src}" ]; then
    src="/"
  elif [ ! -d "${src}" ]; then
    return 1
  fi
  local exclude="proc sys dev boot tmp var/tmp src"
  rm -f "$dst"
  runprereqs "${src}"
  mkdir -p "${src}"/var/run "${src}"/rw
  set -f
  (
    cd "${src}"
    mksquashfs . "$dst" \
      -p 'bin/su m 4755 root root' -wildcards \
      -e $(echo $exclude |sed -r "s,([^ ]+),\1/**,g")
  )
  set +f
}

mkinitramfs() {
  local dst="${1:-}"
  [ -z "$dst" ] && return 1
  local src="${2:-}"
  if [ -z "${src}" ]; then
    src="/"
  elif [ ! -d "${src}" ]; then
    return 1
  fi
  local tmp=$(mktemp -d)
  push_remove $tmp
  (
    cd "$tmp"
    mkdir -p initramfs/bin initramfs/boot initramfs/newroot \
        initramfs/sbin initramfs/proc initramfs/sys initramfs/etc \
        initramfs/lib/modules initramfs/dev
    cp -L "${src}"/lib/libc.so initramfs/lib
    cp -L "${src}"/lib/ld-musl-x86_64.so.* initramfs/lib
    cp -L "${src}"/lib/libcryptsetup.* initramfs/lib
    cp -L "${src}"/lib/libpopt.* initramfs/lib
    cp -L "${src}"/lib/libdevmapper.* initramfs/lib
    cp -L "${src}"/lib/libssl.* initramfs/lib
    cp -L "${src}"/lib/libcrypto.* initramfs/lib
    cp -L "${src}"/opt/busybox/bin/busybox initramfs/bin
    ( cd initramfs/bin; ln -s busybox sh )
    mknod -m 622 initramfs/dev/console c 5 1
    mknod -m 622 initramfs/dev/tty0 c 4 0

    cp -L "${src}"/bin/fsck* initramfs/bin
    cp -L "${src}"/src/KEEP/initramfs.init initramfs/init
    cp -L -f "${src}"/etc/mdev.conf initramfs/etc/mdev.conf
    cp -L -f "${src}"/etc/passwd initramfs/etc/passwd
    cp -L -f "${src}"/etc/group initramfs/etc/group
    cp -L -f "${src}"/etc/fstab initramfs/etc/fstab
    cp -L "${src}"/bin/btrfs.static initramfs/bin/btrfs
    cp -L "${src}"/bin/mkfs.btrfs.static initramfs/bin/mkfs.btrfs
    cp -L "${src}"/bin/btrfs-zero-log.static initramfs/bin/btrfs-zero-log
    cp -L "${src}"/bin/cryptsetup initramfs/bin/cryptsetup
    if [ -e "${src}"/lib/modules/"$(uname -r)" ]; then
#FIXME: this is fugly
      mkdir -p initramfs/lib/modules/"$(uname -r)"
      (
        cd "${src}"/lib/modules/"$(uname -r)"
        for md in *; do
          if [ "$md" != "source" ]; then
            if [ "$md" != "build" ]; then
              echo "$md"
            fi
          fi
        done
      ) |while read md; do
        cp -L -a "${src}"/lib/modules/"$(uname -r)"/"$md" initramfs/lib/modules/"$(uname -r)"
      done
    elif [ "$(ls -1 ${src}/lib/modules |wc -l)" = "1" ]; then
      moddir="${src}"/lib/modules/*
      mkdir -p initramfs/"$moddir"
      (
        cd $moddir
        for md in *; do
          if [ "$md" != "source" ]; then
            if [ "$md" != "build" ]; then
              echo "$md"
            fi
          fi
        done
      ) |while read md; do
        cp -L -a $moddir/"$md" initramfs/"$moddir"
      done
    fi
    chmod +x initramfs/init
    cd initramfs
    find . | cpio -H newc -o > "$dst"
  )
  pop_remove "$tmp"
}

mkinitramfsgz() {
  local dst="${1:-}"
  [ -z "$dst" ] && return 1
  local src="${2:-}"
  if [ -z "${src}" ]; then
    src="/"
  elif [ ! -d "${src}" ]; then
    return 1
  fi
  local tmp="$(mktemp)"
  push_remove "$tmp"
  mkinitramfs "$tmp" "${src}"
  gzip --stdout "$tmp" > "$dst"
  pop_remove "$tmp"
}

mksyslinuxcfg() {
  local dst="${1:-}"
  [ -z "$dst" ] && return 1
  local bootmedia="${2:-}"
  local kuuid="${3:-}"
  local part=""
  local part_id=""
  if [ -z "$bootmedia" ]; then
    part="/dev/sda1"
  elif [ -b "$bootmedia"p1 ]; then
    part_id=$(getuuid ${bootmedia}p1)
  elif [ -b "$bootmedia" ]; then
    part_id=$(getuuid ${bootmedia})
  fi
  if [ -z "$part" ]; then
    if [ -z "$part_id" ]; then
      if [ ! -z "$bootmedia" ]; then
        part="$bootmedia"
      else
        return 1
      fi
    fi
  fi
  (
    echo "UI menu.c32"
    echo "PROMPT 0"
    echo "TIMEOUT 100"
    echo "DEFAULT default"
    for initramfs in /boot/*.cpio.gz; do
      fs=$(basename $initramfs)
      kernel=$(echo $fs |sed -r "s,\.cpio\.gz,,g")
      if [ ! -e /boot/"$kernel" ]; then
        continue
      fi
      echo "LABEL $kernel"
      echo "      MENU LABEL $kernel"
      echo "      KERNEL /$kernel"
      echo "      INITRD /$kernel.cpio.gz"
      local append="      APPEND"
      if [ -z "$part_id" ]; then
        append="$append boot=$part"
      else
        append="$append boot=UUID=$part_id"
      fi
      if [ -z "$kuuid" ]; then
        append="$append sqsh_root=$kernel.sqsh.img quiet"
      else
        append="$append sqsh_root=$kernel.sqsh.img keysdev=$kuuid quiet"
      fi
      echo "$append"
    done
  ) > $dst
}

copy_syslinux() {
  local menumods="menu.c32 libutil.c32"
  for i in ldlinux.c32 $menumods; do
    cp /lib/syslinux/bios/$i /boot
  done
  if [ -d /lib/syslinux/efi64 ]; then
    mkdir -p /boot/EFI/BOOT
    for i in ldlinux.e64 $menumods; do
      cp /lib/syslinux/efi64/$i /boot/EFI/BOOT
    done
    cp /lib/syslinux/efi64/syslinux.efi /boot/EFI/BOOT/bootx64.efi
  elif [ -d /lib/syslinux/efi32 ]; then
    mkdir -p /boot/EFI/BOOT
    for i in ldlinux.e32 $menumods; do
      cp /lib/syslinux/efi32/$i /boot/EFI/BOOT
    done
    cp /lib/syslinux/efi32/syslinux.efi /boot/EFI/BOOT/bootia32.efi
  fi
  if [ -e /boot/EFI/BOOT/ ]; then
    echo "INCLUDE /syslinux.cfg" > /boot/EFI/BOOT/syslinux.cfg
  fi
}

cryptpart() {
  local part="${1:-}"
  local keysdir="${2:-}"
  local dmname="${3:-}"
  [ -z "$dmname" ] && return 1
  [ -d "$keysdir" ] || return 1
  [ -b "$part" ] || return 1
  local keyfile="$keysdir"/LuksKey
  for i in $(seq 0 7); do
    dd if=/dev/urandom of="$keyfile"$i bs=1024 count=4
  done
  cryptsetup luksFormat -q --key-file="$keyfile"0 -c aes-xts-plain64 -s 512 -h sha512 -i 10000 --use-random -S 0 $part || return 1
#this makes the partition more robust
  for i in $(seq 1 7); do
    cryptsetup luksAddKey -q --key-file="$keyfile"0 -S $i $part "${keyfile}${i}" || return 1
  done
  local partid=$(getuuid $part)
  for i in $(seq 0 7); do
    mv "$keysdir"/LuksKey$i "$keysdir"/"$partid"_LuksKey$i
  done
  keyfile="$keysdir"/"$partid"_LuksKey0
  cryptsetup luksHeaderBackup $part --header-backup-file "$keysdir"/"$partid"_luksHeaderBackup
  cryptsetup luksOpen -q --key-file=$keyfile -S 0 $part $dmname || return 1
  [ -b /dev/mapper/"$dmname" ] || return 1
}

wipeptable() {
  local dev="${1:-}"
  [ -z "$dev" ] && return 1
  (
    echo "o"
    echo "w"
  ) | handle_fdisk "$dev" || fail "Failed to wipe partition table on device $dev"
  sync
  partx -d "$dev"
  return 0
}

addpart() {
  local dev="${1:-}"
  [ -z "$dev" ] && return 1
  local type="${2:-}"
  [ -z "$type" ] && return 1
  local boot="${3:-}"
  local size="${4:-}"
  local label="${5:-}"
  local keysdir="${6:-}"
  local dmname="${7:-}"
  local partnum=$(($(fdisk -l $dev |egrep ^$dev |wc -l)+1))
  (
    echo "n"
    echo "p"
    echo "$partnum"
    echo ""
    if [ -z "$size" ]; then
      echo ""
    else
      echo "+$size"
    fi
    echo "t"
    if [ "$partnum" != 1 ]; then
      echo "$partnum"
    fi
    case "$type" in
      "vfat") echo "b";;
      "btrfs") echo "83";;
      "crypt") echo "fd";;
    esac
    if [ "$boot" = "boot" ]; then
      echo "a"
      echo "$partnum"
    fi
    echo "w"
  ) | handle_fdisk "$dev" || fail "Failed to create partition #$partnum device $dev"
  sync
  sleep 2
  if ! partx -a "$dev"; then
    partx -d "$dev"
    partx -a "$dev"
  fi
  sleep 2
  if [ -b "$dev""$partnum" ]; then
    local p="$dev""$partnum"
  elif [ -b "$dev"p"$partnum" ]; then
    local p="$dev"p"$partnum"
  else
    return 1
  fi
  case "$type" in
    "vfat") mkfs."$type" "$p" &> /dev/null || fail "Failed to create fs $type on $p"
            [ -z "$label" ] && label="sbtg-boot"
            dosfslabel "$p" "$label";;
    "btrfs") [ -z "$label" ] && label="sbtg-rw"
             mkfs."$type" -f -L "$label" "$p";;
    "crypt") cryptpart "$p" "$keysdir" "$dmname" || fail "Can not set up encryption"
             [ -z "$label" ] && label="sbtg-rw"
             mkfs.btrfs -f -L "$label" /dev/mapper/"$dmname";;
  esac
  local uuid="$(getuuid ${p})"
  echo "$uuid"
  sync
}

installboot() {
  local src="${1:-}"
  local fatpart="${2:-}"
  local kuuid="${3:-}"
  [ -z "$fatpart" ] && return 1
  local bdir=""
  local tmp="$(mktemp -d)"
  push_remove $tmp
  local dev=$(echo $fatpart |sed 's,[0-9]$,,g')
  if [ ! -b "$dev" ]; then
    dev=$(echo "$dev" |sed 's,.$,,g')
    if [ ! -b "$dev" ]; then
      return 1
    fi
  fi
  local bootuuid=$(getuuid $fatpart)
  local rwpart=$(findfs "LABEL=${bootuuid}-rw" || echo -n '')
  mkdir -p "$tmp"/mount/boot "$tmp"/mount/bootstore
  if ! mount -t vfat "$fatpart" "$tmp"/mount/boot; then
    bdir=$(egrep "^$fatpart " /proc/mounts |awk '{print $2}')
    mount -o remount,rw "$bdir"
    mount --bind "$bdir" "$tmp"/mount/boot
  fi
  push_mounts "$tmp"/mount/boot
  cp -a "$src"/default "$tmp"/mount/boot
  if [ -e "$src"/default.cpio.gz ]; then
    cp -a "$src"/default.cpio.gz "$tmp"/mount/boot
  fi
  if [ ! -e "$tmp"/mount/boot/default ]; then
    cp /boot/vmlinuz "$tmp"/mount/boot/default || return 1
  fi
  pop_mounts "$tmp"/mount/boot
  if [ ! -z "$bdir" ]; then
    mount -o remount,ro $bdir
  fi
  dd conv=notrunc if=/lib/syslinux/bios/mbr.bin of="$dev" || return 1
  sync
  if [ ! -z "$bdir" ]; then
    mount -o remount,rw $bdir
    case "$bdir" in
      /boot|/boot/) ;;
      *)
        mount --bind "$bdir" /boot
        push_mounts /boot
        ;;
    esac
  else
    mount -t vfat "$fatpart" /boot || return 1
    push_mounts /boot
  fi
  copy_syslinux || return 1
  syslinux -i "$fatpart" || return 1
  if [ ! -e /boot/default.cpio.gz ]; then
    mkinitramfsgz /boot/default.cpio.gz || return 1
  fi
  local sqshdst=/boot
  if [ ! -z "$bdir" ]; then
    if [ -d "$bdir"/store ]; then
      sqshdst="$bdir"/store
    fi
  else
    if [ ! -z "$rwpart" ]; then
      mksubvol "$rwpart" sabotage
      mksubvol "$rwpart" sabotage/bootstore
      mount -o subvol=sabotage/bootstore "$rwpart" "$tmp"/mount/bootstore
      push_mounts "$tmp"/mount/bootstore
      sqshdst="$tmp"/mount/bootstore
    fi
  fi
  if [ ! -e "$sqshdst"/default.sqsh.img ]; then
    mksquash "$sqshdst"/default.sqsh.img || return 1
  fi
  if [ ! -e "$sqshdst"/src.tar.xz ]; then
    mktar_src "$sqshdst"/src.tar.xz || return 1
  fi
  rm -f /boot/syslinux.cfg
  mksyslinuxcfg /boot/syslinux.cfg "$fatpart" "$kuuid"
  sync
  mkdir -p /boot/store
  if [ ! -z "$bdir" ]; then
    mount -o remount,ro $bdir
    case "$bdir" in
      /boot|/boot/) ;;
      *)
        pop_mounts /boot
        ;;
    esac
  else
    pop_mounts /boot
  fi
  (
    echo 1
    echo 1
    echo y
  ) | dosfsck -a -r "$fatpart" || true
  dosfsck -a -r "$fatpart" || return 1
  sync
  if [ -z "$bdir" ]; then
    if [ ! -z "$rwpart" ]; then
      pop_mounts "$tmp"/mount/bootstore
    fi
  fi
  pop_remove "$tmp"
}

copyrw() {
  local part="${1:-}"
  [ -z "$part" ] && return 1
  local type="${2:-}"
  [ -z "$type" ] && return 1
  local tmp="$(mktemp -d)"
  push_remove "$tmp"
  local varw=""
  mkdir -p "$tmp"/mount/rw "$tmp"/mount/bootstore
  mksubvol "$part" sabotage
  mksubvol "$part" sabotage/rw-overlay
  mount -t "$type" -o subvol=sabotage/rw-overlay "$part" "$tmp"/mount/rw || return 1
  push_mounts "$tmp"/mount/rw
  mount -t "$type" -o subvol=sabotage/bootstore "$part" "$tmp"/mount/bootstore || return 1
  push_mounts "$tmp"/mount/bootstore
  mkdir -p "$tmp"/mount/squash
  mount -o loop -t squashfs "$tmp"/mount/bootstore/default.sqsh.img "$tmp"/mount/squash || return 1
  push_mounts "$tmp"/mount/squash
  cat /etc/fstab |while read fs mtpt type opt rest; do
    if echo "$opt" |grep -q "bind"; then
      fs=$(echo $fs |sed 's,^/rw/,,')
      if [ "$mtpt" = "/var" ]; then
        varw="$fs"
      fi
      if [ "$mtpt" = "/src" ]; then
        mkdir -p "$tmp"/mount/rw/"$fs"
        tar xf "$tmp"/mount/bootstore/src.tar.xz -C "$tmp"/mount/rw/"$fs"
      elif [ -d "$tmp"/mount/squash/"$mtpt" ]; then
        mkdir -p "$tmp"/mount/rw/"$fs"
        tar c -h -C "$tmp"/mount/squash/"$mtpt"/ . \
            |tar x -C "$tmp"/mount/rw/"$fs"
      elif [ -f "$tmp"/mount/squash/"$mtpt" ]; then
        mkdir -p "$tmp"/mount/rw/"$(dirname $fs)"
        cp -aL "$tmp"/mount/squash/"$mtpt" "$tmp"/mount/rw/"$fs"
      else
        mkdir -p "$tmp"/mount/rw/"$fs"
      fi
    fi
  done
  if [ ! -z "$varw" ]; then
    mkdir -p "$tmp"/mount/rw/$varw/spool/cron/crontabs "$tmp"/mount/rw/$varw/service "$tmp"/mount/rw/$varw/log "$tmp"/mount/rw/$varw/empty
    (
      cd "$tmp"/mount/squash/etc/service
    	for i in * ; do
    		mkdir -p "$tmp"/mount/rw/$varw/log/$i
    	done
    )
  fi
  sync
  pop_mounts "$tmp"/mount/squash
  pop_mounts "$tmp"/mount/rw
  pop_mounts "$tmp"/mount/bootstore
  pop_remove "$tmp"
}

mkimage_loop() {
  local img="${1:-}"
  [ -z "$img" ] && return 1
  local size="${2:-}"
  [ -z "$size" ] && return 1
  if ! dd if=/dev/zero of="$img" bs=1 count=0 seek="$size"; then
    fail "Could not create $img image"
  fi
  local lo="$(losetup -f)"
  losetup "$lo" "$img" || fail "Could not setup loop for $img image"
  echo "$lo"
}

do_install() {
  local dev="${1:-}"
  [ -z "$dev" ] && return 1
  local bsize="${2:-}"
  [ -z "$bsize" ] && return 1
  local rwfs="${3:-}"
  [ -z "$rwfs" ] && return 1
  local cryptkdev="${4:-}"
  local kuuid=""
  local tmp="$(mktemp -d)"
  push_remove "$tmp"
  wipeptable "$dev" || fail "Failed to wipe partition table of $dev"
  local uuid=$(addpart "$dev" vfat boot "$bsize" || fail "Failed to add fat partition boot of size $bsize to $dev")
  if [ -n "$cryptkdev" ]; then
    [ ! -x /bin/cryptsetup ] && fail 'Please install cryptsetup'
    kuuid=$(getuuid $cryptkdev)
    mkdir $tmp/kdir
    mount "$cryptkdev" "$tmp"/kdir
    push_mounts "$tmp"/kdir
    local cruuid=$(addpart "$dev" "crypt" '' '' "${uuid}-rw" "$tmp"/kdir sbtgrw || fail "Failed to add encrypted $rwfs partition rw to $dev")
    push_crypt "sbtgrw"
  elif [ "$rwfs" != "n" ]; then
    local rwuuid=$(addpart "$dev" "$rwfs" '' '' "${uuid}-rw" || fail "Failed to add $rwfs partition rw to $dev")
  fi

  if [ -b "$dev"1 ]; then
    boot_part="$dev"1
    rw_part="$dev"2
  elif [ -b "$dev"p1 ]; then
    boot_part="$dev"p1
    rw_part="$dev"p2
  else
    fail "Could not find boot partition"
  fi
  if [ -n "$cryptkdev" ]; then
    rw_part="/dev/mapper/sbtgrw"
  fi
  installboot /boot "$boot_part" "$kuuid" || fail "Failed to install boot partition $boot_part."
  if [ "$rwfs" != "n" ]; then
    if [ -b "$rw_part" ]; then
      mount -t vfat "$boot_part" /boot || return 1
      push_mounts /boot
      copyrw "$rw_part" "$rwfs" || fail "Failed to install rw partition $rw_part."
      pop_mounts /boot
    fi
  fi
}

installer() {
  local dev="${1:-}"
  [ -z "$dev" ] && usage
  local boot_size="${2:-}"
  [ -z "$boot_size" ] && usage
  local rwfs="${3:-}"
  [ -z "$rwfs" ] && usage
  size="${4:-}"
  local cryptkdev="${5:-}"

  if [ ! -b "$dev" ]; then
    if [ "$rwfs" = "n" ]; then
      size="$boot_size"
    else
      [ -z "$size" ] && usage
    fi
    img="$dev"
    dev=$(mkimage_loop "$img" "$size")
    push_loops "$dev" "$img"
  else
    cryptkdev="${4:-}"
  fi

  do_install "$dev" "$boot_size" "$rwfs" "$cryptkdev"
}

mkboottar() {
  local dst="${1:-}"
  [ -z "$dst" ] && return 1
  local src="${2:-}"
  if [ -z "${src}" ]; then
    src="/"
  elif [ ! -d "${src}" ]; then
    return 1
  fi
  local tmp="$(mktemp -d)"
  push_remove "$tmp"
  cp -a "${src}"/boot/System.map "$tmp"
  if [ ! -e "$tmp"/default.sqsh.img ]; then
    mksquash "$tmp"/default.sqsh.img "${src}"
  fi
  if [ ! -e "$tmp"/default.cpio.gz ]; then
    mkinitramfsgz "$tmp"/default.cpio.gz "${src}"
  fi
  if [ ! -e "$tmp"/default ]; then
    cp "${src}"/boot/vmlinuz "$tmp"/default
  fi
  if [ ! -e "$tmp"/syslinux.cfg ]; then
    mksyslinuxcfg  "$tmp"/syslinux.cfg
  fi
  mktar_src "$tmp"/src.tar.xz no "${src}"
  cp "$0" "$tmp"
  tar czf $dst -C "$tmp" .
  pop_remove "$tmp"
}

do_chroot() {
  local boot_dir="${1:-}"
  [ -z "$boot_dir" ] && return 1
  [ -e "$boot_dir"/default.sqsh.img ] || return 1
  local tmp="$(mktemp -d)"
  push_remove "$tmp"

  mount -o loop,ro -t squashfs "$boot_dir"/default.sqsh.img "$tmp"
  push_mounts "$tmp"

  mount -t proc procfs "$tmp"/proc
  push_mounts "$tmp"/proc

  mount -t sysfs sysfs "$tmp"/sys
  push_mounts "$tmp"/sys

  mount --bind /dev "$tmp"/dev
  push_mounts "$tmp"/dev

  mount -t tmpfs tmpfs "$tmp"/tmp
  push_mounts "$tmp"/tmp


  mkdir "$tmp"/tmp/boot
  push_remove "$tmp"/tmp/boot
  mount --bind "$boot_dir" "$tmp"/tmp/boot
  push_mounts "$tmp"/tmp/boot

  local tempboot="$(mktemp -d)"
  push_remove "$tempboot"
  mount --bind "$tempboot" "$tmp"/boot
  push_mounts "$tmp"/boot
  cp "$tmp"/tmp/boot/default "$tmp"/boot
  cp "$tmp"/tmp/boot/System.map "$tmp"/boot
  
  local srctmp="$(mktemp -d)"
  push_remove "$srctmp"

  mount --bind "$srctmp" "$tmp"/src
  push_mounts "$tmp"/src
  tar xf "$boot_dir"/src.tar.xz -C "$srctmp"

  echo "You are now in the chroot of the $boot_dir/default.sqsh.img image"
  echo "$boot_dir is /tmp/boot"
  chroot "$tmp" /bin/sh
  for mtpt in "$tmp"/dev "$tmp"/sys "$tmp"/proc "$tmp"/boot "$tmp"/tmp/boot "$tmp"/tmp "$tmp"/src; do
    pop_mounts "$mtpt"
  done
  pop_remove "$tmp"/tmp/boot
  pop_mounts "$tmp"
  pop_remove "$tempboot"
  pop_remove "$srctmp"
  pop_remove "$tmp"
}

in_chroot() {
  local boot="${1:-}"
  [ -z "$boot" ] && return 1
  shift
  local func="${1:-}"
  [ -z "$func" ] && return 1
  shift
  local out="${1:-}"
  [ -z "$out" ] && return 1
  shift
  local args="$@"
  local tmpout=/tmp/boot/"$(basename $out)"
  [ "$func" == "chroot" ] && return 1
  if [ -z "$args" ]; then
    echo "/tmp/boot/squash-tool $func $tmpout" | do_chroot "$boot"
  else
    echo "/tmp/boot/squash-tool $func $tmpout $args" | do_chroot "$boot"
  fi
  mv "$boot"/"$tmpout" "$out"
}

update() {
  local src="${1:-}"
  [ -z "$src" ] && return 1
  local bootdev="${2:-}"
  [ -z "$bootdev" ] && return 1
  local cryptkdev="${3:-}"
  local kuuid=""
  if [ -n "$cryptkdev" ]; then
    kuuid=$(getuuid $cryptkdev)
  fi
  local umount=true
  if [ -b "$bootdev" ]; then
    local bootdir="$(mktemp -d)"
    push_remove "$bootdir"
    local bootuuid=$(getuuid $bootdev)
    local rwpart=$(findfs "LABEL=${bootuuid}-rw" || echo -n '')
    mount "$bootdev" "$bootdir"
    push_mounts "$bootdir"
    if [ ! -z "$rwpart" ]; then
      mount -o subvol=sabotage/bootstore "$rwpart" "$bootdir"/store
      push_mounts "$bootdir"/store
    fi
  elif [ -d "$bootdev" ]; then
    local umount=false
    local bootdir="$(echo $bootdev |sed 's,/$,,g')"
    bootdev=$(egrep "^[^ ]+ +$bootdir/? " /proc/mounts |awk '{print $1}')
    local bootuuid=$(getuuid $bootdev)
    local rwpart=$(findfs "LABEL=${bootuuid}-rw" || echo -n '')
    mount -o remount,rw $bootdir
  else
    return 1
  fi
  if [ ! -z "$rwpart" ]; then
    mksubvol "$rwpart" /sabotage/prev
    local tmp=$(mktemp -d)
    push_remove "$tmp"
    mount -o subvol=sabotage "$rwpart" "$tmp"
    push_mounts "$tmp"
    if [ -e "$tmp"/bootstore ]; then
      btrfs subvolume delete "$tmp"/prev/bootstore || true
      btrfs subvolume snapshot "$tmp"/bootstore "$tmp"/prev/bootstore
    fi
    if [ -e "$tmp"/rw-overlay ]; then
      btrfs subvolume delete "$tmp"/prev/rw-overlay || true
      btrfs subvolume snapshot "$tmp"/bootstore "$tmp"/prev/rw-overlay
    fi
    pop_mounts "$tmp"
    pop_remove "$tmp"
  fi
  (
    cd "$bootdir"
    mv default old
    cp "$src"/default default
    mv default.cpio.gz old.cpio.gz
    cp "$src"/default.cpio.gz default.cpio.gz
    if [ ! -z "$rwpart" ]; then
      cd "$bootdir"/store
    fi
    mv default.sqsh.img old.sqsh.img
    mv src.tar.xz oldsrc.tar.xz
    if [ -d "$src"/store ]; then
      cp "$src"/store/default.sqsh.img default.sqsh.img
      cp "$src"/store/src.tar.xz src.tar.xz
    else
      cp "$src"/default.sqsh.img default.sqsh.img
      cp "$src"/src.tar.xz src.tar.xz
    fi
  )
  if $umount; then
    if [ ! -z "$rwpart" ]; then
      pop_mounts "$bootdir"/store
    fi
    pop_mounts "$bootdir"
    pop_remove "$bootdir"
  else
    mount -o remount,ro $bootdir
  fi
  installboot "$src" "$bootdev" "$kuuid"
  copyrw "$rwpart" btrfs
}


setuptraps
[ "$(id -u)" = "0" ] || fail "must be root"

[ "$(readlink /bin/sh)" = "dash" ] && \
  echo "this script is incompatible with dash. "\
       "Please use bash or busybox (dpkg-reconfigure dash)" && \
  exit 1

func="${1:-}"
[ -z "$func" ] && usage
shift

if [ "$func" = "chroot" ]; then
  type chroot || fail "Install chroot on host"
  bootdir="${1:-}"
  [ -z "$bootdir" ] && usage
  do_chroot "$bootdir"
  cleanup
  exit 0
fi

[ -e /src ] || fail "must run in sabotage (with source) environment"

([ ! -f /boot/vmlinuz ] && [ ! -f /boot/default ] )&& fail "Please install a kernel"
[ ! -x /bin/partx ] && fail 'Please install partx'
[ ! -x /bin/syslinux ] && fail 'Please install syslinux6'
[ ! -x /bin/mksquashfs ] && fail 'Please install squashfs-tools'
[ ! -x /bin/mkfs.vfat ] && fail 'Please install dosfstools'
[ ! -x /bin/blkid ] && fail 'Please install libblkid'
[ ! -x /bin/cpio ] && fail 'Please install cpio'

case "$func" in
  "install") installer "$@";; #TODO: efibootmgr
  "tarball") mkboottar "$@";;
  "in_chroot") in_chroot "$@";;
  "mkinitramfs") mkinitramfs "$@";;
  "update") update "$@";;
  "srctar") mktar_src "$@";;
  *) usage;;
esac

cleanup
