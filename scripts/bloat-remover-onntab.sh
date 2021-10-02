#!/bin/sh
# bloatware app remover for Onn Android tablets (based on apps I found on a 2020-model 10.1" tablet)
#
# Copyright 2021 by Ian Kluft
# released as Open Source Software under the GNU General Public License Version 3.
# See https://www.gnu.org/licenses/gpl.txt
#
# Current source code for this script can be found at
# https://github.com/ikluft/ikluft-tools/blob/master/scripts/bloat-remover-onntab.sh
#
# Before use, modify this to fit your needs. No guarantees! Review thoroughly because it uninstalls apps!
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

# initialize list of apps uninstalled
zapped=""

# uninstall bloatware apps - review this list to make sure it fits your needs
# Warning: You can easily disable your device by uninstalling system apps.
# Don't uninstall anything you don't understand.
for delapp in $zap_list
do
	apps=$($adb shell pm list packages $delapp | sed 's/^package://')
	for app in $apps
	do
		zapped+=" $app"
		$adb shell pm uninstall --user 0 $app
	done
done

# report results
if [ -z "$zapped" ]
then
	echo "no bloatware apps found - no action taken"
else
	echo "removed bloatware apps:$zapped"
fi
