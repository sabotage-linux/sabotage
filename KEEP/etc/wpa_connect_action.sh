#!/bin/sh

# set to false if you want a static ip
# (and edit ip address settings further down)
do_dhcp=true
# set to true if you experience connection problems
do_throttle=false

if="$1"
state="$2"
echo "$0: $if $state"
case "$state" in
CONNECTED)
if $do_dhcp ; then
	dhclient -nw "$if";
else
	sn=192.168.1
	ifconfig "$if" "$sn".100 netmask 255.255.255.0
	route delete default
	route add default gw "$sn".1
fi
$do_throttle && iwconfig "$if" rate 1M
;;
DISCONNECTED)
:
;;
esac
