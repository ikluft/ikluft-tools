#!/bin/sh
# collect Android device info over ADB connection
# This is for use on Linux or other Unix-like systems. You must have ADB, and may (or may not) need root access
# on your desktop/laptop system to run ADB. It requires developer access on the tablet, but not root.
#
# Copyright 2021 by Ian Kluft
# released as Open Source Software under the GNU General Public License Version 3.
# See https://www.gnu.org/licenses/gpl.txt
#
# Current source code for this script can be found at
# https://github.com/ikluft/ikluft-tools/blob/master/scripts/android-deviceinfo.sh

# function to exit with an error message
die()
{
	# print an error and exit
	echo $@ >&2
	exit 1
}

# print script action
echo Android device info collector

# find ADB
adb=$(which adb 2>/dev/null)
if [ -z "$adb" ]
then
	die "adb is required to be installed in order to run this script - not found in PATH"
fi
echo "adb found at $adb"
$adb start-server \
	|| die "adb server must be started (as root) before running this script"
if [ $($adb devices | fgrep -v 'List of devices' | grep -v '^$' | wc -l) -eq 0 ]
then
	die "adb does not detect any connected Android devices"
fi

# get device brand and model for output file prefixes
brand=$($adb shell getprop ro.product.brand)
model=$($adb shell getprop ro.product.name)
if [ -z "$brand" -o -z "$model" ]
then
	die "could not read device brand or model"
fi
echo "device found: brand=$brand model=$model"

# collect various system data into separate files
devdir="${XDG_DATA_HOME:-${HOME}/.local/share}/deviceinfo/$brand-$model"
mkdir -p $devdir || die "failed to create device info directory at $devdir"
echo "saving data files in $devdir"
echo collecting uname data
$adb shell uname -a > "$devdir/$brand-$model-uname" || die "uname failed"
echo collecting cpuinfo data
$adb shell cat /proc/cpuinfo > "$devdir/$brand-$model-cpuinfo" || die "cpuinfo failed"
echo collecting dumpsys data
$adb shell dumpsys > "$devdir/$brand-$model-dumpsys" || die "dumpsys failed"
echo collecting getprop data
$adb shell getprop > "$devdir/$brand-$model-getprop" || die "getprop failed"
echo collecting system settings data
$adb shell settings list system > "$devdir/$brand-$model-settings-system" || die "system settings list failed"
echo collecting secure settings data
$adb shell settings list secure > "$devdir/$brand-$model-settings-secure" || die "secure settings list failed"
echo collecting global settings data
$adb shell settings list global > "$devdir/$brand-$model-settings-global" || die "global settings list failed"
echo collecting window manager data
{
	$adb shell wm size || die "window manager size failed"
	$adb shell wm density || die "window manager density failed"
} > "$devdir/$brand-$model-windowmanager"

echo done
