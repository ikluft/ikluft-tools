#!/bin/sh
# bloatware app remover for Onn Android tablets (based on apps I found on a 2020-model 10.1" tablet)
#
# bloat-remover-onntab.sh is a script to remove bloatware apps from an Onn (Walmart) Android tablet. This worked for
# a 2020-model 10.1 inch tablet. Review and modify the script as needed for your own use. This is for use on Linux
# or other Unix-like systems. You must have ADB, and may (or may not) need root access on your desktop/laptop system
# to run ADB. It requires developer access on the tablet, but not root. Of course, since it uninstalls apps, I have
# to re-emphasize what is already the case from the GPLv3 license that you use it at your own risk. I posted it
# because I see people asking online. Warning: you can easily disable your device by removing system apps. Don't
# remove anything you don't understand. You have been warned.
#
# Copyright 2021 by Ian Kluft
# released as Open Source Software under the GNU General Public License Version 3.
# See https://www.gnu.org/licenses/gpl.txt
#
# Current source code for this script can be found at
# https://github.com/ikluft/ikluft-tools/blob/master/scripts/bloat-remover-onntab.sh
#
# Before use, modify this to fit your needs. zap_list contains keywords which will uninstall apps which contain them.
# WARNING: No guarantees! Review this thoroughly because it uninstalls apps!  You can easily disable your device if
# you uninstall system apps.  Don't uninstall anything you don't understand.
zap_list="com.example walmart sams vudu kids mediahome.launcher com.hcn.wm.wmapps facebook instagram"

# function to exit with an error message
die()
{
	# print an error and exit
	echo $@ >&2
	exit 1
}

# print script action
echo Bloat-app remover for Onn tablet

# find ADB
adb=$(which adb 2>/dev/null)
[ -z "$adb" ] \
	&& die "adb is required to be installed in order to run this script - not found in PATH"
echo "adb found at $adb"
$adb start-server \
	|| die "adb server must be started (as root) before running this script"
[ $($adb devices | fgrep -v 'List of devices' | grep -v '^$' | wc -l) -eq 0 ] \
	&& die "adb does not detect any connected Android devices"

# verify ADB target is an Onn tablet - otherwise zap_list is a mismatch for the device
brand=$($adb shell getprop ro.product.brand)
if [ "$brand" != "onn" ]
then
	die "This script is initially for Onn tablets - submit a patch or contact the author to collaborate on expansion"
fi

# initialize list of apps found and uninstalled
zap_target=""
zap_ok=""
zap_fail=""

# find bloatware apps as defined in $zap_list above
for delapp in $zap_list
do
	apps=$($adb shell pm list packages $delapp | sed 's/^package://')
	for app in $apps
	do
		zap_target+=" $app"
	done
done

# prompt user to uninstall
if [ -z "$zap_target" ]
then
	echo "no bloatware apps found - no action to take"
	exit 0
fi
echo "bloatware apps found:$zap_target"
echo "confirm uninstall (y/n)?"
read confirm
if [ "$confirm" != "y" -a "$confirm" != "Y" -a "$confirm" != "yes" -a "$confirm" != "YES" -a "$confirm" != "Yes" ]
then
	echo "uninstall aborted"
	exit 0
fi

# uninstall bloatware apps
for zap in $zap_target
do
	echo "uninstalling $zap"
	if $adb shell pm uninstall --user 0 "$zap"
	then
		zap_ok+=" $zap"
	else
		zap_fail+=" $zap"
	fi
done

# report results
if [ "$zap_ok" ]
then
	echo "removed bloatware apps:$zap_ok"
fi
if [ "$zap_fail" ]
then
	echo "failed to remove:$zap_fail"
fi
