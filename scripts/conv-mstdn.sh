#!/bin/bash
# reduce the size of an MP4 video file for upload to Mastodon
#
# Copyright 2022-2023 by Ian Kluft
# released as Open Source Software under the GNU General Public License Version 3.
# See https://www.gnu.org/licenses/gpl.txt
#
# Current source code for this script can be found at
# https://github.com/ikluft/ikluft-tools/blob/master/scripts/conv-mstdn.sh

# loop through files on command line
for infile in "$@"
do
    outfile="$(basename "$infile" .mp4).mstdn.mp4"
    echo "converting $infile to $outfile"
    ffmpeg -i "$infile" -y -map 0:v -map 0:a -c:v libx264 -c:a copy -s 1280x720 -fs "40800KB" -vtag avc1 -crf 24 "$outfile" < /dev/null
done
