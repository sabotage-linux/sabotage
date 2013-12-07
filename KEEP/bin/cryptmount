#!/bin/sh

SHORTOPTS="LMUc:fw:nqvho:O:"
DEPS="cryptsetup blkid mkswap mktemp"
UDEVRUNNING=0

LOGLEVEL=1
DRYRUN=0
WAITTIME=10
CRYPTTAB=/etc/crypttab
OPTIONS=
FILTER="!noauto"
FORCE=0

ct_print_usage() {
	cat <<__EOF__
usage: $0 [OPTIONS] [-L]
       $0 [OPTIONS] -M [NAME|DEVICE]
       $0 [OPTIONS] -M NAME DEVICE [KEY]
       $0 [OPTIONS] -U [NAME[,...]]

  List, map, and unmap encrypted volumes. The utility is a wrapper for
  cryptsetup which makes use of a crypttab file.

  actions:
    -L       list the names of volumes defined in crypttab, this is
             the default
    -M       map a volume defined in crypttab or defined on the command
             line. with no arguments, map all volumes without the noauto
             option
    -U       unmap volumes defined in crypttab. with no arguments, unmap
             all volumes without the noauto option

  options:
    -c FILE  set the crypttab location (default: /etc/crypttab)
    -f       force destructive operations even when a block device appears to
             contain data
    -w NUM   wait time (seconds) for a device if it is not already available
    -n       dry run
    -q       decrease verbosity
    -v       increase verbosity
    -h       print this message
    -o OPT[,...]
             options which are appened to the options defined in crypttab
             (they take precedence). specifying this multiple times is
             cumulative
    -O OPT[,...]
             filter used *only* when no volumes are given on the command
             line. an option may start with a ! to require that it must not
             be present. specifying this multiple times is cumulative

__EOF__
	exit $1
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
# Utilities                                                                    #
#                                                                              #

error() {
	[ $LOGLEVEL -ge 0 ] && printf "E: %s\n" "$*" >&2 || true
}

die() {
	printf "E: %s\n" "$*" >&2
	exit ${1:-1}
}

warn() {
	[ $LOGLEVEL -ge 1 ] && printf "W: %s\n" "$*" >&2 || true
}

msg() {
	[ $LOGLEVEL -ge 1 ] && printf "M: %s\n" "$*" >&2 || true
}

info() {
	[ $LOGLEVEL -ge 2 ] && printf "I: %s\n" "$*" >&2 || true
}

run() {
	[ $LOGLEVEL -ge 2 ] && printf "R: %s\n" "$*" >&2
	if [ $DRYRUN -eq 1 ]; then
		true
	else
		"$@"
	fi
}

trim() {
	local IFS=$' \t\n'
	echo -n $*
}

get_mount() {
	if type findmnt &> /dev/null ; then
		findmnt -cfmnoTARGET "$1"
	else
		cat /proc/self/mountinfo | \
		awk -v dev="$1" \
		'{ for(i=7;$i!="-";$i++); if($(i+2)==dev&&$4=="/"){print $5;r=1;exit}} END {exit !r}'
	fi
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
# Main functions                                                               #
#                                                                              #

ct_main() {

	local action

	set_action() {
		if [ -z $action ]; then
			action="$@"
		else
			error "only one of -L, -M, or -U may be given"
			ct_print_usage 1
		fi
	}

	while getopts ":$SHORTOPTS" opt ; do

		case $opt in
			L) set_action list;;
			M) set_action map;;
			U) set_action unmap;;
			c) CRYPTTAB="$OPTARG";;
			f) FORCE=1;;
			w) WAITTIME=${OPTARG//[!0-9]};;
			n) DRYRUN=1;;
			q) LOGLEVEL=$(( LOGLEVEL - 1 ));;
			v) LOGLEVEL=$(( LOGLEVEL + 1 ));;
			h) ct_print_usage 0;;
			o) OPTIONS="$OPTIONS,$OPTARG";;
			O) FILTER="$FILTER,$OPTARG";;
			:)
				error "option requires an argument -- '$OPTARG'"
				ct_print_usage 1
				;;
			?)
				error "invalid option -- '$OPTARG'"
				ct_print_usage 1
				;;
		esac

	done

	shift $(( OPTIND - 1 ))

	# Warn if any of the dependencies are missing
	for dep in $DEPS; do
		type $dep &> /dev/null || info "$dep not found, some functionality may fail"
	done

	# Check for UDEV
	if pidof udevd &>/dev/null; then
		UDEVRUNNING=1
		info "Detected udevd"
	else
		info "udevd not running, or unable to detect it: waiting for devices disabled"
	fi

	# Pre-parse OPTIONS, a little ugly, but it works
	preparse() {
		local args tmpfs
		if ! ct_parse_options $OPTIONS; then
			error "Invalid options string: $OPTIONS"
			exit 1
		fi
		OPTIONS="$args"
	}
	preparse

	if [ -z "$action" -o "$action" = "list" ]; then

		if [ $# -ne 0 ]; then
			warn "With -L, volumes given on the command line have no effect"
		fi

		list_func() { printf "%s\n" "$1"; }
		ct_read_crypttab list_func

	elif [ "$action" = "unmap" ]; then

		if [ $# -gt 0 ]; then
			[ "$FILTER" != "!noauto" ] && \
				info "Filters from -O are ignored in this mode"
			unset FILTER
		fi

		ct_main_unmap "$@"

	elif [ "$action" = "map" ]; then

		if [ $# -ne 0 ]; then
			[ "$FILTER" != "!noauto" ] && \
				info "Filters from -O are ignored in this mode"
			unset FILTER
		fi

		ct_main_map "$@"

	else

		error "Internal error: no action"
		false

	fi
}

ct_main_unmap() {

	if [ $# -eq 0 ]; then

		ct_read_crypttab ct_unmap

	else

		local vol ret=0

		for vol in "$@"; do
			ct_unmap "$vol" || ret=$(( ret+1 ))
		done

		return $ret

	fi
}

ct_main_map() {

	if [ $# -eq 0 ]; then

		ct_read_crypttab ct_map

	elif [ $# -eq 1 ]; then

		local vol _tmp="$1"

		find_func() {
			if [ "$1" = "$_tmp" -o "$2" = "$_tmp" ]; then
				printf "%s" "$*"
			else
				false
			fi
		}

		if vol="$(ct_read_crypttab -1 find_func)"; then
			ct_map $vol
		else
			error "Unable to find '$_tmp' in '$CRYPTTAB'"
			false
		fi

	elif [ $# -le 3 ]; then

		ct_map "$@"

	else

		error "Too many options given for -M"
		ct_print_usage 1

	fi
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
# Functions for iterating over crypttab                                        #
#                                                                              #

ct_read_crypttab() {

	if [ ! -f "$CRYPTTAB" -o ! -r "$CRYPTTAB" ]; then
		error "cannot read $CRYPTTAB"
		return 1
	fi

	local func="$@" line lineno=0 name dev key options ret=0 adhoc=0

	if [ "$1" = "-1" ]; then
		adhoc=1
		shift
		func="$@"
	fi

	while read -r name dev key options <&3; do

		lineno=$(( lineno + 1 ))
		[ -z "$name" ] || [ ${name:0:1} = "#" ] && continue

		# unescape devname and keyname
		name=$(printf '%b' "$name")
		dev=$(printf '%b' "$dev")
		key=$(printf '%b' "$key")

		if [ -z "$name" ]; then
			warn "$CRYPTTAB:$lineno: the name (first column) cannot be blank"
			continue
		elif [ -z "$dev" ]; then
			warn "$CRYPTTAB:$lineno: the device (second column) cannot be blank"
			continue
		fi

		case $key in
			-|none|"")
				key=-
				;;
			/dev/random|/dev/urandom|/dev/hw_random)
				options="$options,%random"
				;;
			ASK)
				info "$CRYPTTAB:$lineno: ASK is a deprecated key, please use '-' or 'none'"
				key=-
				;;
			SWAP)
				info "$CRYPTTAB:$lineno: SWAP is a deprecated key, please use '/dev/urandom' and the 'swap' option"
				key="/dev/urandom"
				options="$options,swap,%random"
				;;
			/*|UUID=*|PARTUUID=*|LABEL=*)
				:
				;;
			*)
				warn "$CRYPTTAB:$lineno: plain text keys are not supported"
				key=-
				;;
		esac

		if ct_check_filter $options; then
			if ! $func "$name" "$dev" "$key" $options; then
				ret=$(( ret + 1 ))
			elif [ $adhoc -eq 1 ]; then
				ret=0
				break
			fi
		fi

	done 3< "$CRYPTTAB"

	return $ret
}

ct_check_filter() {

	local IFS=$',' fltr opt

	for fltr in $FILTER; do
		fltr="$(trim $fltr)"
		[ -z "$fltr" ] && continue

		if [ "x${fltr:0:1}" != "x!" ]; then

			for opt in $*; do
				opt="$(trim $opt)"
				[ -z "$opt" ] && continue

				if [ "$fltr" = "$opt" -o "$fltr" = "${opt%%=*}" ]; then
					continue 2
				fi
			done

			return 1

		else

			for opt in $*; do
				opt="$(trim $opt)"
				[ -z "$opt" ] && continue

				if [ "$fltr" = "!$opt" -o "$fltr" = "!${opt%%=*}" ]; then
					return 1
				fi
			done

		fi

	done

	return 0
}

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                                                              #
#  Mapping, unmapping, finding stuff                                           #
#                                                                              #

ct_unmap() {
	local name="$1"
	if [ ! -e "/dev/mapper/$name" ]; then
		warn "Volume was not mapped (no '/dev/mapper/$name')"
	elif run cryptsetup remove "$name"; then
		info "$name unmapped"
	else
		error "failed to unmap $name"
		false
	fi
}

ct_map() {

	local name="$1" dev="$2" key="$3" args="" tmpfs
	local key_dev="" key_fstype="" key_mntpnt="" key_dev_umount=0
	shift 3

	if [ -e "/dev/mapper/$name" ]; then
		error "Volume is already mapped ('/dev/mapper/$name' exists')"
		return 1
	fi

	# this function sets the args and tmpfs variables
	if ! ct_parse_options "$@"; then
		error "Unable to parse options"
		return 1
	fi
	args="$args $OPTIONS"

	# resolve the encrypted device, can't do much without this
	if ! dev="$(ct_resolve_device "$dev")"; then
		error "device '$dev' not found"
		return 1
	fi

	# parse various key formats
	case "$key" in
		*:*:*)
			key_dev="${key%%:*}"
			key="${key#*:}"
			key_fstype="${key%%:*}"
			key="${key#*:}"
			case "$key_fstype" in
				*[!0-9]*)
					:;;
				*)
					warn "<dev>:<offset>:<length> is a deprecated key format. Please use"
					warn " the keyfile-offset and keyfile-size options instead. This"
					warn " format will *soon* be removed from cryptmount/crypttab!"
					opts="$opts --keyfile-offset=$key_fstype --keyfile-size=$key"
					key="$key_dev"
					unset key_fstype
					unset key_dev
			esac
			;;
		*:*)
			key_dev="${key%%:*}"
			key="${key#*:}"
			;;
		""|-)
			unset key_dev
			unset key
			;;
		*)
			unset key_dev
			;;
	esac

	# resolve any needed key device and mount if necessary
	if [ "$key_dev" ]; then

		if key_dev="$(ct_resolve_device "$key_dev")"; then

			if key_mntpnt="$(get_mount "$key_dev")"; then

				key="$key_mntpnt/$key"

			elif key_mntpnt="$(mktemp -d)"; then

				[ -n "$key_fstype" ] && key_fstype="-t $key_fstype"

				if run mount -r $key_fstype "$key_dev" "$key_mntpnt"; then
					key="$key_mntpnt/$key"
					key_dev_umount=1
				else
					error "unable to mount key device '$key_dev',"
					error " falling back on interactive password"
					unset key
				fi
			else
				error "unable to find or create mountpoint for key device,"
				error " falling back on interactive password"
				unset key
			fi
		else
			error "key device '$key_dev' not found"
			error " falling back on interactive password"
			unset key
		fi

	elif [ -n "$key" -a "$key" != "-" ]; then

		if ! key="$(ct_resolve_device "$key")"; then
			error "key '$key' not found"
			error " falling back on interactive password"
			unset key
		fi

	fi

	if [ "$key" ]; then
		key=--key-file="$key"
	fi

	local ret=0

	# the main event, run cryptsetup (and mkswap, mkfs if necessary)
	if cryptsetup isLuks "$dev"; then

		info "device '$dev' detected as LUKS"

		if run cryptsetup luksOpen $key $args "$dev" "$name"; then
			info "sucessfully mapped '$dev' to '/dev/mapper/$name'"
		else
			error "unable to map '$dev' to '/dev/mapper/$name'"
			ret=1
		fi

	else

		info "device '$dev' assumed to be plain"

		# cryptsetup 'create' can be destructive, don't do it if blkid can
		# identify the device type
		if [ $FORCE -ne 1 ] && blkid -p "$dev" &>/dev/null; then
			error "Refusing to call 'cryptsetup create' on device that might"
			error " have data. If you are sure this is what you want, use"
			error " the -f option"
			ret=1
		elif run cryptsetup create $key $args "$name" "$dev"; then
			info "sucessfully mapped '$dev' to '/dev/mapper/$name'"
			if [ "$tmpfs" = "swap" ]; then
				if run mkswap -f -L "$name" "/dev/mapper/$name"; then
					info "mkswap successful on '/dev/mapper/$name'"
				else
					error "mkswap failed for '/dev/mapper/$name'"
					ret=1
				fi
			elif [ "$tmpfs" ]; then
				if run mkfs -t "$tmpfs" "/dev/mapper/$name"; then
					info "mkfs successful on '/dev/mapper/$name'"
				else
					error "mkfs failed for '/dev/mapper/$name'"
					ret=1
				fi
			fi
		else
			error "unable to map '$dev' to '/dev/maper/name/$name'"
			ret=1
		fi

	fi

	# clean up after ourselves
	if [ $key_dev_umount -eq 1 ]; then
		if ! run umount "$key_dev"; then
			warn "unable to mount key device '$key_dev'"
		else
			run rmdir "$key_mntpnt"
		fi
	fi

	return $ret
}

ct_resolve_device() {

	local tmp="" device="$1" seconds=$WAITTIME tag tagval

	case "$device" in
		UUID=*|PARTUUID=*|LABEL=*)
			tmp="$(blkid -l -o device -t "$device")"
			if [ -z "$tmp" ]; then
				if [ $UDEVRUNNING -eq 1 ]; then
					tag="$(awk -v t="${device%%=*}" 'BEGIN { print tolower(t) }')"
					tagval="${device#*=}"
					device="/dev/disk/by-$tag/$tagval"
				fi
			else
				device="$tmp"
			fi
	esac

	if [ ! -e "$device" -a "${device:0:5}" = "/dev/" -a "$UDEVRUNNING" -eq 1 ]; then
		msg "Waiting $seconds seconds for '$device'..."
		until [ -e "$device" -o $seconds -eq 0 ]; do
			sleep 1
			seconds=$(( seconds - 1 ))
		done
	fi

	printf "%s" "$device"

	if [ -e "$device" ]; then
		info "resolve: found '$device'"
	else
		error "resolve: unable to find '$device'"
		return 1
	fi
}

ct_parse_options() {

	local IFS=',' optlst="$*" opt key val depr=0

	for opt in $optlst; do

		# separate key and value
		unset key val
		case "$opt" in
			"")
				continue;;
			-*)
				if [ $depr -eq 0 ]; then
					info "You are using a deprecated format for the options field. The entire"
					info " field will be passed directly to cryptsetup. Please use the more"
					info " standardized comma-deliminated options list instead. This format"
					info " will be removed in a future version of cryptmount/crypttab!"
					depr=1
				fi
				args="$args $opt"
				continue
				;;
			*=*)
				key="${opt%%=*}"
				val="${opt#*=}"
				[ "$key" = "$val" ] && unset val
				;;
			*)
				key="$opt";;
		esac

		case "$key" in
			swap)
				# set external variable
				tmpfs="swap"
				;;
			luks|plain)
				warn "Ignoring option $key, LUKS volumes are automatically detected"
				;;
			noauto|%*)
				:
				;;
			skip|precheck|check|checkargs|noearly|loud|keyscript)
				warn "Ignoring Debian specific option '$key'"
				;;
			tmp)
				# set an external variable
				[ -z "$val" ] && msg "Defaulting tmp to ext4"
				tmpfs="${val:-ext4}"
				;;
			size)
				args="$args --key-size $val"
				;;
			device-size)
				args="$args --size $val"
				;;
			none)
				args=
				;;
			*)
				if [ ${#key} -eq 1 ]; then
					args="$args -$key $val"
				else
					args="$args --$key $val"
				fi
				;;
		esac

	done

	return 0
}

#                                                                              #
# ---------------------------------------------------------------------------- #

ct_main "$@"

# vim: set ft=sh noet ts=2 sw=2 :
