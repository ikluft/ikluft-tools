This directory contains miscellaneous helpful scripts I've written.

- *[android-deviceinfo.sh](android-deviceinfo.sh)* is a script to collect various device and system information about an Android device which is connected via ADB. It creates a subdirectory named for the brand and model of the device and puts files in it with output of various commands that are run via ADB shell.
  - language: Unix shell🐚
  - dependencies:  [ADB (Android Debug Bridge)](https://developer.android.com/studio/command-line/adb)
- *[bloat-remover-onntab.sh](bloat-remover-onntab.sh)* is a script to remove bloatware apps from an Onn (Walmart) Android tablet. This worked for a 2020-model 10.1 inch tablet. Review and modify the script as needed for your own use. This is for use on Linux or other Unix-like systems. You must have ADB, and may (or may not) need root access on your desktop/laptop system to run ADB. It requires developer access on the tablet, but not root. Of course, since it uninstalls apps, I have to re-emphasize what is already the case from the [GPLv3 license](https://www.gnu.org/licenses/gpl-3.0.txt) that you use it at your own risk. I posted it because I see [people asking online](https://forum.xda-developers.com/t/latest-10-1-inch-onn-tablet-any-way-to-remove-walmart-button-from-the-navbar-remove-other-walmart-branding.4329241/post-85717903). *Warning: you can easily disable your device by removing system apps. Don't remove anything you don't understand. You have been warned.*
  - language: Unix shell🐚
  - dependencies:  [ADB (Android Debug Bridge)](https://developer.android.com/studio/command-line/adb)
- *[cef_syntax_diagrams.py](cef_syntax_diagrams.py)* generates syntax diagrams (a.k.a. railroad diagrams) for the Condorcet Election Format (CEF)
  - language: Python🐍
- *[conv-mstdn.sh](conv-mstdn.sh)* reduces the size of an MP4 video file for upload to Mastodon, where some instance servers have relatively lower file size limits
  - language: Unix shell🐚
  - dependencies: [ffmpeg](https://ffmpeg.org/)
- *[flatpak-aliases.pl](flatpak-aliases.pl)* is a script for Linux desktop and laptop systems (equipped with a graphical user interface) which when executed from the user's .bashrc script will make command-line shell aliases to launch any of the installed Flatpaks on the system. For example, if you installed the Gnu Image Manipulation Program (GIMP), it will make a shell function called org.gnome.GIMP based on the Flatpak's identified to run it, and shell aliases "GIMP" and "gimp" which refer to that shell function. So you can just run it as "gimp" with any usual command line arguments passed along to it. And similar functions/aliases will be made for all Flatpak apps installed on the system.
  - language: Perl5🐪
  - dependencies: [flatpak](https://flatpak.org/)
- *[jcsac_gen_cal.py](jcsac_gen_cal.py)* generates calendar entries for the crew selecting space stories at JetCityStar Aerospace Chat
  - language: Python🐍
- *[jpeg2med](jpeg2med)* is a shell script which copied and scales down a JPEG image to a medium-sized image, defined as 800 pixels or a number set by the MED_SIZE environment variable.
  - language: Unix shell🐚
  - dependencies: [NetPBM](https://en.wikipedia.org/wiki/Netpbm)
- *[jpeg2sc](jpeg2sc)* is a shell script which copied and scales down a JPEG image, default 1600 pixels otherwise a number set by the MED_SIZE environment variable.
  - language: Unix shell🐚
  - dependencies: [NetPBM](https://en.wikipedia.org/wiki/Netpbm)
- *[makelog](makelog)* is a shell script which runs make and keeps a log file of its standard output and error. This is useful for any software developer working on a project which uses make for builds.
  - language: Unix shell🐚
  - dependencies: [make](https://www.gnu.org/software/make/)
- *[perltidy.rc](perltidy.rc)* is the perltidy configuration file used to format the Perl scripts in this repo and others of mine
  - language: Perl5🐪
  - dependencies: [perltidy](https://metacpan.org/dist/Perl-Tidy/view/bin/perltidy)
- *[perlcritic.rc](perlcritic.rc)* is the perlcritic configuration template used for static analysis of Perl scripts in this repo and others of mine
  - language: Perl5🐪
  - dependencies: [perlcritic](https://metacpan.org/dist/Perl-Critic/view/bin/perlcritic) (more via [Wikipedia](https://en.wikipedia.org/wiki/Perl::Critic))
- *[png2tn](png2tn)* is a shell script which copies and scales down a PNG (Portable Network Graphics) image to a smaller 100-pixel high thumbnail image.
  - language: Unix shell🐚
  - dependencies: [NetPBM](https://en.wikipedia.org/wiki/Netpbm)
- *[pull-nasa-neo.pl](pull-nasa-neo.pl)* reads NASA JPL data on Near Earth Object (NEO) asteroid close approaches to Earth, within 2 lunar distances (LD) and makes a table of upcoming events and recent ones within 15 days.
  - language: Perl5🐪
  - dependencies: [curl](https://curl.se/), [Template Toolkit](http://www.template-toolkit.org/)
- *[rot13](rot13)* implements the trivial ROT13 cypher which rotates the letters 13 positions across the alphabet, so that it is also its own decryption method. This was originated in Internet tradition since the days of UseNet as a trivially-silly cypher which was built into many UseNet reader programs. But it actually dates back to Ancient Roman times. It can still be an amusement when playfully hiding non-important messages from someone who doesn't know what ROT13 is.
  - language: Unix shell🐚
- *[space-story-count.pl](space-story-count.pl)* is used to list and rank space stories for the JetCityStar Aerospace Chat. The rankings use PrefVote's implementation of the RankedPairs or Schulze preference-voting algorithms to turn rankings from the editorial team members into the team's overall ranking of the stories.
  - language: Perl5🐪
  - dependencies: [PrefVote](https://github.com/ikluft/prefvote)
- *[timestamp-str](timestamp-str)* prints a timestamp string from the current time in YYYYMMDDHHMM format. It can be used for creating files with the creation time in their name.
  - language: Unix shell🐚

Scripts moved to other GitHub repos:

- bootstrap-prereqs.pl has been moved mostly to [Sys::OsPackage](https://github.com/ikluft/Sys-OsPackage),
  except for the part that read /etc/os-release which became [Sys::OsRelease](https://github.com/ikluft/Sys-OsRelease).
  It was started here as a script to install dependencies for a Perl script, with preference for installing
  OS packages: RPM on Fedora/RedHat/CentOS Linux, APK on Alpine Linux, and DEB on Debian/Ubuntu Linux. If an
  OS package isn't found or the user isn't root, then CPAN is used to build and install the packages. For
  local users the packages are installed in a subdirectory of their home directory. One use case is for
  setting up containers.

- *ical-isc2sv-mtg.pl* generates a QR code with an ICal event. I made this for
  monthly ISC2 Silicon Valley Chapter meetings. But by filling in the
  command-line arguments, it can generate QR codes for a variety of events.
  It was moved to [GitHub - ikluft/isc2sv-tools: software tools for ISC2 Silicon Valley Chapter](https://github.com/ikluft/isc2sv-tools)

- *isc2-zoomcsv2cpe.pl* processes a Zoom webinar attendee report (in Comma
  Separated Values CSV format) into CSV data with members' earned Continuing
  Professional Education CPE points for the amount of time Zoom says they
  attended the meeting. I made this for monthly ISC2 Silicon Valley Chapter
  meetings. This could be useful to other ISC2 chapters, but not likely for
  any other purposes.
  It was moved to [GitHub - ikluft/isc2sv-tools: software tools for ISC2 Silicon Valley Chapter](https://github.com/ikluft/isc2sv-tools)
