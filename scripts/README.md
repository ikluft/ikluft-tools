This directory contains miscellaneous helpful scripts I've written.

- [android-deviceinfo.sh](android-deviceinfo.sh) is a script to collect various device and system information about an Android device which is connected via ADB. It creates a subdirectory named for the brand and model of the device and puts files in it with output of various commands that are run via ADB shell.
- [bloat-remover-onntab.sh](bloat-remover-onntab.sh) is a script to remove bloatware apps from an Onn (Walmart) Android tablet. This worked for a 2020-model 10.1 inch tablet. Review and modify the script as needed for your own use. This is for use on Linux or other Unix-like systems. You must have ADB, and may (or may not) need root access on your desktop/laptop system to run ADB. It requires developer access on the tablet, but not root. Of course, since it uninstalls apps, I have to re-emphasize what is already the case from the [GPLv3 license](https://www.gnu.org/licenses/gpl-3.0.txt) that you use it at your own risk. I posted it because I see [people asking online](https://forum.xda-developers.com/t/latest-10-1-inch-onn-tablet-any-way-to-remove-walmart-button-from-the-navbar-remove-other-walmart-branding.4329241/post-85717903). *Warning: you can easily disable your device by removing system apps. Don't remove anything you don't understand. You have been warned.*
- *[flatpak-aliases.pl](flatpak-aliases.pl)* is a script for Linux desktop and laptop systems
  (equipped with a graphical user interface) which when executed from the
  user's .bashrc script will make command-line shell aliases to launch
  any of the installed Flatpaks on the system. For example, if you installed
  the Gnu Image Manipulation Program (GIMP), it will make a shell function
  called org.gnome.GIMP based on the Flatpak's identified to run it, and
  shell aliases "GIMP" and "gimp" which refer to that shell function. So you
  can just run it as "gimp" with any usual command line arguments passed along
  to it. And similar functions/aliases will be made for all Flatpak apps
  installed on the system.
- *[makelog](makelog)* is a script which runs make and keeps a log file of its standard output and error. This is useful for any software developer working on a project which uses make for builds.
- *[rot13](rot13)* is a trivial cypher program which rotates the letters 13 positions across the alphabet, so that it is also its own decryption method. This was originated in Internet tradition since the days of UseNet as a trivially-silly cypher which was built into many UseNet reader programs. But it actually dates back to Ancient Rome.
- *[timestamp-str](timestamp-str)* prints a timestamp string from the current time in YYYYMMDDHHMM format. It can be used for creating files with the creation time in their name.

Scripts moved to other GitHub repos:

- bootstrap-prereqs.pl has been moved mostly to [Sys::OsPackage](https://github.com/ikluft/Sys-OsPackage),
  except for the part that read /etc/os-release which became [Sys::OsRelease](https://github.com/ikluft/Sys-OsRelease).
  It was started here as a script to install dependencies for a Perl script, with preference for installing
  OS packages: RPM on Fedora/RedHat/CentOS Linux, APK on Alpine Linux, and DEB on Debian/Ubuntu Linux. If an
  OS package isn't found or the user isn't root, then CPAN is used to build and install the packages. For
  local users the packages are installed in a subdirectory of their home directory. One use case is for
  setting up containers.

- *ical-isc2sv-mtg.pl* generates a QR code with an ICal event. I made this for
  monthly ISC² Silicon Valley Chapter meetings. But by filling in the
  command-line arguments, it can generate QR codes for a variety of events.
  It was moved to [GitHub - ikluft/isc2sv-tools: software tools for (ISC)² Silicon Valley Chapter](https://github.com/ikluft/isc2sv-tools)

- *isc2-zoomcsv2cpe.pl* processes a Zoom webinar attendee report (in Comma
  Separated Values CSV format) into CSV data with members' earned Continuing
  Professional Education CPE points for the amount of time Zoom says they
  attended the meeting. I made this for monthly ISC² Silicon Valley Chapter
  meetings. This could be useful to other ISC² chapters, but not likely for
  any other purposes.
  It was moved to [GitHub - ikluft/isc2sv-tools: software tools for (ISC)² Silicon Valley Chapter](https://github.com/ikluft/isc2sv-tools)
