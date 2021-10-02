This directory contains miscellaneous helpful scripts I've written.

- [bloat-remover-onntab.sh](bloat-remover-onntab.sh) is a script to remove bloatware apps from an Onn (Walmart) Android tablet. This worked for a 2020-model 10.1 inch tablet. Review and modify the script as needed for your own use. This is for use on Linux or other Unix-like systems. You must have ADB, and may (or may not) need root access on your desktop/laptop system to run ADB. It requires developer access on the tablet, but not root. Of course, since it uninstalls apps, I have to re-emphasize what is already the case from the [GPLv3 license](https://www.gnu.org/licenses/gpl-3.0.txt) that you use it at your own risk. I posted it because I see people asking online. *Warning: you can easily disable your device by removing system apps. Don't remove anything you don't understand. You have been warned.*
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

Scripts moved to [GitHub - ikluft/isc2sv-tools: software tools for (ISC)² Silicon Valley Chapter](https://github.com/ikluft/isc2sv-tools)

- *ical-isc2sv-mtg.pl* generates a QR code with an ICal event. I made this for
  monthly ISC² Silicon Valley Chapter meetings. But by filling in the
  command-line arguments, it can generate QR codes for a variety of events.

- *isc2-zoomcsv2cpe.pl* processes a Zoom webinar attendee report (in Comma
  Separated Values CSV format) into CSV data with members' earned Continuing
  Professional Education CPE points for the amount of time Zoom says they
  attended the meeting. I made this for monthly ISC² Silicon Valley Chapter
  meetings. This could be useful to other ISC² chapters, but not likely for
  any other purposes.
