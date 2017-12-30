# stock-flash
Uses servicefile.xml or flashfile.xml and the fastboot utility to flash an andoird phone back to stock

## SYNOPSIS

**stock-flash.pl** [**-f** *fastbootcmd*] [**-s** *devicepath*] [**-o** *omissions*] [**-p**] *file.xml*
**stock-flash.pl** {**-h**|**--help**}

## OPTIONS

**-d**, **--device**=*DEVICEPATH*

Specify device serial number or path to device port as interperted by fastboot -s *DEVICEPATH*.  If the empty string, no -s option is passed to fastboot.  Default is empty string.

**-f**, **--fastboot**=*FASTBOOTCMD*

Sets the fastboot command name.  Must be either a file path or a program in current path.  Default is 'fastboot'.

**-h**, **--help**

Print this usage information and exit.

**-o**, **--omit**=*OMISSIONS*

Omit the comma seperated list of partitions in OMISSIONS.  Items in the list may be either partition names or filenames.  For example -o gpt.bin,boot will omit both the file gpt.bin and the boot partition.  Including this option more than once overrides earlier specifications.  Default is no ommisions: -o ''.

**-p**, **--pretend**

Perform any MD5 checks and print the fastboot that would be called, but don't acctually call fastboot.

**-s**=*DEVICEPATH*

Alias for **-d**

## DESCRIPTION

**stock-flash.pl** uses the external fastboot command to flash an android device back to stock configuration.  It requires an unziped stock rom file.  The rom file will contain either servicefile.xml or flashfile.xml or both.  servicefile.xml will return the device to stock configuration, preserving user data.  flashfile.xml will return the device to full factory configuration, wiping any user data.

**The stock rom must be the correct rom for the phone.  stock-flash.pl has no way of verifying this and flashing the wrong rom will likely brick the phone.**

**stock-flash.pl** reads the entire xml file, determines all the necessary steps,, verifies all files exist, and checks any provided MD5 sums before any flashboot commands are sent.  This reduces the chance that an invalid or corrupt rom will result in a partially flashed or bricked phone.

## TROUBLESHOOTING

If the program hangs saying *< waiting for device >*, then fastboot cannot locate your phone.  You can hit Ctrl-C to break and then run

    $ fastboot -l devices

to list available devices.  Make sure your phone is properly plugged in and that you have satisfied all the dependencies in the next section, including the proper USB drivers if stuck using windows.  If more than one device is plugged in, you can specify which device to flash using the **-d** option.

If you receive errors about missing files, be sure you unzipped the entire rom and that the .xml file is in that directory.

If you receive errors about invalid steps, operations, or MD5 sums, the downloaded rom is invalid and cannot be processed.

If you receive errors about 'Security version downgrade', the issue is that phone has received a newer update than you are flashing (perhaps via an over the air [ota] update).  The proper fix is to download an updated ROM and flash that.  If an updated ROM is not available, you can try flashing the bootloader than then rebooting the device or omitting the problematic partition with -o.  No guarentee that either of these alternate solutions will work.

## DEPENDENCIES

**stock-flash.pl** requires the external program fastboot.  On ubuntu based systems it is in the android-tools package and can be installed with

    $ sudo apt-get install android-tools

On debian systems it is in the fastboot package and can be installed using the command

    $ sudo apt-get install fastboot

On gentoo systems it is in the android-tools package and can be installed with

    $ sudo emerge -a android-tools

Mac users should install the package manager Homebrew and then run

    $ brew install android-platform-tools

Windows does not have a package manager so windows users must download and install the package manually.  Also, note that many versions of Windows do not include many of the USB drivers required for fastboot to work in the default install, so these will need to be downloaded and installed seperately.

**stock-flash.pl** uses Perl and the perl module XML::Simple.  Perl is installed by default on nearly all linux distributions and Mac.  Windows users will need to download and install perl manually.  The XML::Simple module is packaged as libxml-simple-perl in ubuntu and dev-perl/XML-Simple on gentoo.  It can also be downloaded and installed with cpan.

## COPYRIGHT

Copyright (c) 2017 Paul Maurer.  All rights reserved.  Licensed with the three clause BSD license included at the top of the program file.
