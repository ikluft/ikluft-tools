Tools for Space Alerts
----------------------

This directory contains scripts I've written which monitor space-related alerts online. The common code among the scripts was pulled together into the AlertGizmo module. These can be run manually or from crontabs. (see example below)

- bin (script directory)
  - *[pull-nasa-neo.pl](bin/pull-nasa-neo.pl)* reads NASA JPL data on Near Earth Object (NEO) asteroid close approaches to Earth, within 2 lunar distances (LD) and makes a table of upcoming events and recent ones within 15 days.
     - language: Perl5🧅
     - dependencies: [curl](https://curl.se/), [Template Toolkit](http://www.template-toolkit.org/)
     - example template text: [close-approaches.tt](close-approaches.tt)
  - *[pull-swpc-alerts.pl](bin/pull-swpc-alerts.pl)* reads NOAA Space Weather Prediction Center (SWPC) alerts for solar flares and aurora
     - language: Perl5🧅
     - dependencies: [curl](https://curl.se/), [Template Toolkit](http://www.template-toolkit.org/)
     - example template text: [noaa-swpc-alerts.tt](noaa-swpc-alerts.tt)
- lib (library directory)
  - AlertGizmo.pm - base class for AlertGizmo feed monitors
  - AlertGizmo/Config.pm - configuration data for AlertGizmo classes
  - AlertGizmo/Neo.pm - AlertGizmo monitor for NASA JPL Near-Earth Object (NEO) close approach data
  - AlertGizmo/Swpc.pm - AlertGizmo monitor for NOAA Space Weather Prediction Center (SWPC) alerts, including aurora

To run these scripts from a crontab, first use 'crontab -l' to determine if you have one set up, and that the crontab command is installed. (If it isn't installed, Linux packages such as [cronie](https://github.com/cronie-crond/cronie) can perform [modern cron](https://en.wikipedia.org/wiki/Cron#Modern_versions) functions. If on a small embedded Linux system, [BusyBox](https://en.wikipedia.org/wiki/BusyBox) or [Toybox](https://en.wikipedia.org/wiki/Toybox) also provide a crontab command.)

When run in normal mode, the scripts pull new data from the network. When run in test mode with the --test flag on the command line, they use saved data from prior network accesses but do not make a new network access.

If you have a crontab already, preserve its contents by saving it to a file we'll call 'my-crontab' with this command:

    crontab -l > my-crontab

Otherwise create the 'my-crontab' file empty from scratch with a text editor.

Add these lines to the 'my-crontab' file, replacing "path/to/script" with your path where these scripts are installed and using your local time zone instead of US/Pacific (the author's local time zone).

    CRON_TZ=UTC

    # access NASA JPL NEO API 8 times per day and just after midnight UTC
    1 0 * * *       $HOME/path/to/script/pull-nasa-neo.pl --tz="US/Pacific"
    31~44 */3 * * * $HOME/path/to/script/pull-nasa-neo.pl --tz="US/Pacific"

    # access NOAA Space Weather Predition Center alerts every 2 hours
    11~24 */2 * * * $HOME/path/to/script/pull-swpc-alerts.pl --tz="US/Pacific"

Then install the crontab by running:

    crontab my-crontab

Ongoing experimentation
=======================

The SWPC alert script is derived from the NEO script. So they have some common code. Before making more similar scripts, it would be a good idea to make modules to combine their common features.

Also, an outage in Tom Taylor's Mastodon "Low Flying Rocks" bot led me to the conclusion I should expand these to be able to post on Mastodon. I was already inspired by [XKCD comic #2979 "Sky Alarm"](https://xkcd.com/2979/) to go in that direction.
[![XKCD comic #2979 "Sky Alarm"](https://imgs.xkcd.com/comics/sky_alarm.png)](https://xkcd.com/2979/)
