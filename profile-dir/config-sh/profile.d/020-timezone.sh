#!/bin/sh
# 020-timezone.sh - included by .profile

# TZ should be set by GUI login environment, but wouldn't be present for a console login or container
# set a default time zone if it wasn't set by login environment
# if necessary, comment/uncomment else-clauselines when traveling
if [ -z "$TZ" ]
then
	ZONE=$(/bin/readlink /etc/localtime | /bin/sed 's/^.*zoneinfo\///')
	if [ -n "$ZONE" ]
	then
		export TZ=$ZONE
	else
		export TZ=US/Pacific
		#export TZ=US/Arizona
		#export TZ=US/Mountain
		#export TZ=US/Central
		#export TZ=US/Eastern
		#export TZ=Pacific/Auckland
		#export TZ=Australia/Sydney
	fi
fi
