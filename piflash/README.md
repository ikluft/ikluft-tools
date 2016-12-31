# piflash - Flash an SD card for a Raspberry Pi with safety checks

This script flashes an SD card for a Raspberry Pi. It includes safety checks so that it won't accidentally erase a device which is not an SD card. The safety checks are probably of most use to beginners. For more advanced users (like the author) it also has the convenience of flashing directly from the file formats downloadable from raspberrypi.org without extracting a .img file from a zip/gz/xz file.

## Usage

```
piflash [--verbose] input-file output-device
```

- The optional parameter --verbose makes much more verbose status and error messages.  Use this when troubleshooting any problem or preparing program output to ask for help or report a bug.
- input-file is the path of the binary image file used as input for flashing the SD card. If it's a .img file then it will be flashed directly. If it's a gzip (.gz), xz (.xz) or zip (.zip) file then the .img file will be extracted from it to flash the SD card. It is not necessary to unpack the file if it's in one of these formats. This covers most of the images downloadable from the Raspberry Pi foundation's web site.
- output-file is the path to the block device where the SSD card is located. The device should not be mounted - if it ismounted the script will detect it and exit with an error. This operation will erase the SD card and write the new image from the input-file to it. (So make sure it's an SD card you're willing to have erased.)

## Installation

The piflash script only works on Linux systems. It depends on features of the Linux kernel to look up whether the output device is an SD card and other information about it. It has been tested so far on Fedora 25 Linux.

The following programs must exist on the system to run piflash.
* dd
  * on RPM systems, install coreutils.
* gunzip
  * on RPM systems, install gzip.
* lsblk
  * on RPM systems, install util-linux.
* sudo
  * on RPM systems, install sudo.
* sync
  * on RPM systems, install coreutils.
* true
  * on RPM systems, install coreutils.
* unzip
  * on RPM systems, install unzip.
* xz
  * on RPM systems, install xz.

Since the program uses sudo to establish root privileges, it looks for these programs in the standard locations of /usr/bin, /sbin, /usr/sbin or /bin. If your installation has any in other locations, set the environment variable `XXX_PROG` (replacing XXX with the name of the program in all upper case, such as `DD_PROG`) with the path to the program. Make sure it's a program you know is secure, provided by your OS distribution or something you built from sources. Running unknown programs with root privilege would open a potential security breach on your system.
