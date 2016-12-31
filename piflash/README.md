# piflash - Flash an SD card for a Raspberry Pi with safety checks

This script flashes an SD card for a Raspberry Pi. It includes safety checks so that it won't accidentally erase a device which is not an SD card.

## Usage

```
piflash [--verbose] input-file output-device
```

- The optional parameter --verbose makes much more verbose status and error messages.  Use this when troubleshooting any problem or preparing program output to ask for help or report a bug.
- input-file is the path of the binary image file used as input for flashing the SD card. If it's a .img file then it will be flashed directly. If it's a gzip (.gz), xz (.xz) or zip (.zip) file then the .img file will be extracted from it to flash the SD card. It is not necessary to unpack the file if it's in one of these formats. This covers most of the images downloadable from the Raspberry Pi foundation's web site.
- output-file is the path to the block device where the SSD card is located. The device should not be mounted - if it ismounted the script will detect it and exit with an error. This operation will erase the SD card and write the new image from the input-file to it. (So make sure it's an SD card you're willing to have erased.)
