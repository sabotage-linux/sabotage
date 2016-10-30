#!/bin/sh

# set to true if you want that wpa_supplicant gets restarted automatically
# on disconnect instead of doing crazy things
restart_service=false
# set to false if you want a static ip
# (and edit ip address settings further down)
do_dhcp=true
# set to true if you experience connection problems
do_throttle=false
throttle_speed=1M

if="$1"
state="$2"
essid="$3"

echo "$0: $if $state"
case "$state" in
RECALLED)
sleep 1
$do_throttle && iwconfig "$if" rate "$throttle_speed"
if $do_dhcp ; then
	dhclient "$if" || dhclient "$if";
else
	sn=192.168.1
	ifconfig "$if" "$sn".100 netmask 255.255.255.0
	route delete default
	route add default gw "$sn".1
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi
;;
CONNECTED)
printf "<<< Connected to '%s' >>>\n" "$essid"
"$0" "$1" RECALLED "$essid" &
;;
DISCONNECTED)
$restart_service && sv status wpa_supplicant | grep "^run:">/dev/null && {
# restart wpa_supplicant on disconnect iff the service is still up
# (disconnect may be triggered by user doing a sv d wpa_supplicant manually,
# so doing this here unconditionally would up the service again.
# why do we want a restart? there's a whole lot of logic of blacklisting,
# whitelisting, timeouts etc in wpa_supplicant that at the end of the day
# just gets into the way instead of helping.
sv d wpa_supplicant ; sv u wpa_supplicant
}

:
;;
esac
