#!/bin/sh
# (C) 2016 rofl0r, licensed under the MIT license.
# the wave sound chunk was created with milkytracker's instrument editor
# and is licensed under the CC0 license.

write_silence() {
	local c="$1"
	while test $c -gt 16 ; do
		echo -ne "\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f\x7f"
		c=$(($c - 16))
	done
	while test $c -gt 0 ; do
		echo -ne "\x7f"
		c=$(($c - 1))
	done
}

write_chunk() {
echo -ne "\x7F\x7E\x7F\x7E\x7F\x7E\x7E\x7C\x7B\x7A\x79\x7A\x7B\x7D\x7F\x82"
echo -ne "\x85\x87\x88\x88\x87\x85\x81\x7D\x78\x74\x71\x6F\x70\x72\x76\x7C"
echo -ne "\x82\x89\x8E\x92\x94\x92\x8E\x88\x81\x78\x70\x6A\x66\x64\x67\x6C"
echo -ne "\x74\x7D\x88\x91\x99\x9D\x9E\x9B\x94\x8A\x7E\x72\x67\x5F\x5B\x5B"
echo -ne "\x5F\x68\x74\x81\x8F\x9B\xA4\xA9\xA8\xA2\x97\x88\x79\x69\x5C\x53"
echo -ne "\x4F\x51\x59\x66\x76\x88\x99\xA7\xB0\xB3\xB0\xA6\x97\x85\x71\x5F"
echo -ne "\x50\x47\x45\x49\x55\x67\x7B\x90\xA4\xB4\xBD\xBE\xB6\xA7\x94\x7F"
echo -ne "\x69\x58\x4A\x44\x46\x4E\x5B\x6E\x82\x95\xA5\xB0\xB5\xB2\xAA\x9C"
echo -ne "\x8B\x79\x68\x5A\x51\x4E\x51\x59\x66\x76\x86\x95\xA2\xA9\xAA\xA7"
echo -ne "\x9F\x92\x84\x75\x68\x5E\x59\x58\x5C\x64\x6F\x7C\x88\x93\x9C\xA0"
echo -ne "\xA0\x9C\x95\x8A\x7F\x74\x6B\x65\x61\x62\x66\x6D\x76\x80\x88\x90"
echo -ne "\x95\x97\x96\x92\x8C\x84\x7C\x76\x70\x6C\x6B\x6D\x70\x75\x7B\x81"
echo -ne "\x86\x8A\x8C\x8D\x8B\x89\x85\x80\x7C\x79\x76\x75\x75\x76\x79\x7B"
echo -ne "\x7E\x80\x82\x83\x83\x83\x82\x81\x7F\x7F\x7E\x7F\x7F\x7E\x7F"
}
bswap() {
	awk -v a="$1" \
	'BEGIN{print substr(a,7,2) substr(a,5,2) substr(a,3,2) substr(a,1,2);exit}'
}
escape_hex_word() {
	awk -v a="$1" \
	'BEGIN{print "\\x" substr(a,1,2) "\\x" substr(a,3,2) "\\x" substr(a,5,2) "\\x" substr(a,7,2);exit}'
}
write_hex_word() {
	echo -ne $(escape_hex_word $1)
}
write_word_le() {
	local h=$(printf "%08x" "$1")
	h=$(bswap $h)
	write_hex_word $h
}
write_header() {
	local sz="$1"
	echo -ne "RIFF"
	write_word_le $(($sz + 36))
	echo -ne "WAVEfmt "
	echo -ne "\x10\x00\x00\x00\x01\x00\x01\x00\xAB\x20\x00\x00\xAB\x20\x00\x00"
	echo -ne "\x01\x00\x08\x00data"
	write_word_le $sz
}
gen_wave() {
	local chunksz=223
	local chunkrep=10
	local sil=10
	local reps=1
	local dsize=$(($reps * ($chunksz * ($chunkrep + $sil))))
	local i=0
	write_header $dsize
	while test $i -lt $reps ; do
		local j=0
		while test $j -lt $chunkrep ; do
			write_chunk
			j=$(($j + 1))
		done
		write_silence $(($chunksz * $sil))
		i=$(($i + 1))
	done
}

gen_tune() {
	tmp=$(mktemp -u).wav
	gen_wave > "$tmp"
}
play_tune() {
	aplay "$tmp">/dev/null 2>&1
}
clear_tune() {
	rm "$tmp"
}
usage() {
cat << EOF >&2
sabotage alarmclock v1.0 (C) 2016 rofl0r
----------------------------------------
usage: $0 [--st=N] [--rep=N] hh:mm

will play an alarm tune using aplay at the specified time
(in european format i.e. hour values between 00 and 24).
if hour or minute are less than 10, a leading zero is required
(i.e. 08:05 rather than 8:5).

optional arguments:
--st  to adjust the sleep time in seconds between clock checks (default: $st)
--rep to adjust the number of times the sound is played        (default: $rep)

examples:
$0 --rep=10 --st=5 09:00
$0 18:25

make sure to activate your speakers and set the volume using alsamixer.
you can test the audio effect and volume with
$0 --test

current time: $(date "+%T (%Z)")
EOF
exit 1
}

st=29
rep=60

for p ; do
	case "$p" in
	--test)  gen_tune ; play_tune ; clear_tune ; exit 0 ;;
	--st=[0-9]*)  st=$(printf "%s" "$p"|cut -d "=" -f 2) ;;
	--rep=[0-9]*) rep=$(printf "%s" "$p"|cut -d "=" -f 2) ;;
	[0-2][0-9]:[0-5][0-9]) atime="$p" ;;
	*) usage ;;
	esac
done

[ -z "$atime" ] && usage

type aplay>/dev/null || \
{ echo "error: aplay not found. install alsa-utils." ; exit 1 ; }

ah=$(echo $atime | cut -d ":" -f 1)
am=$(echo $atime | cut -d ":" -f 2)

while : ; do
	ch=$(date +%H)
	cm=$(date +%M)
	if test x$ch = x$ah -a x$am = x$cm ; then
		gen_tune
		i="$rep"
		while test $i -gt 0 ; do
			play_tune
			i=$(($i - 1))
		done
		clear_tune
		return 0
	fi
	sleep $st
done
