#!/bin/sh
# call this in case you encountered a build problem during stage0, which you fixed.
# this will continue where you left.
# in case you modified pkg/ or KEEP/ you'll have to copy it to $S/

# this var is usually set by build-stage; omitting it results in build error of stage0_finish
export H="$PWD"
. "$H"/config
CONFIG="$H"/config BUTCHDB="$R"/var/lib/butch.db "$R"/bin/butch install stage0
