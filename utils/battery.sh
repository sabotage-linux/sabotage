#!/bin/sh
curr=$(cat /sys/class/power_supply/battery/charge_now)
full=$(cat /sys/class/power_supply/battery/charge_full)
printf "charge: %d%% (%d/%d)\n" $(($curr / ($full / 100))) "$curr" "$full"

