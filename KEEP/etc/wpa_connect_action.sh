#!/bin/sh

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
fi
;;
CONNECTED)
printf "<<< Connected to '%s' >>>\n" "$essid"
"$0" "$1" RECALLED "$essid" &
;;
DISCONNECTED)
:
;;
esac
