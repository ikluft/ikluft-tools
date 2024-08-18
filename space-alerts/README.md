This directory contains scripts I've written which monitor space-related alerts online. These can be run manually or from crontabs.

- *[pull-nasa-neo.pl](pull-nasa-neo.pl)* reads NASA JPL data on Near Earth Object (NEO) asteroid close approaches to Earth, within 2 lunar distances (LD) and makes a table of upcoming events and recent ones within 15 days.
  - language: Perl5🐪
  - dependencies: [curl](https://curl.se/), [Template Toolkit](http://www.template-toolkit.org/)
  - example template text: [close-approaches.tt](close-approaches.tt)
- *[pull-nasa-neo.pl](pull-nasa-neo.pl)* reads NOAA Space Weather Prediction Center (SWPC) alerts for solar flares and aurora
  - language: Perl5🐪
  - dependencies: [curl](https://curl.se/), [Template Toolkit](http://www.template-toolkit.org/)
  - example template text: [noaa-swpc-alerts.tt](noaa-swpc-alerts.tt)
