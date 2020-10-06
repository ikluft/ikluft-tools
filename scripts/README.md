This directory contains miscellaneous helpful scripts.

*flatpak-aliases.pl* is a script for Linux desktop and laptop systems
(equipped with a graphical user interface) which when executed from the
user's .bashrc script will make command-line shell aliases to launch
any of the installed Flatpaks on the system. For example, if you installed
the Gnu Image Manipulation Program (GIMP), it will make a shell function
called org.gnome.GIMP based on the Flatpak's identified to run it, and
shell aliases "GIMP" and "gimp" which refer to that shell function. So you
can just run it as "gimp" with any usual command line arguments passed along
to it. And similar functions/aliases will be made for all Flatpak apps
installed on the system.

*ical-isc2sv-mtg.pl* generates a QR code with an ICal event. I made this for
the monthly ISC² Silicon Valley Chapter meetings. But by filling in the
command-line arguments, it will generate QR codes for a variety of events.

