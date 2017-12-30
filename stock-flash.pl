#!/usr/bin/perl -w

# Copyright (c) 2017 Paul Maurer
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;

use Digest::MD5;
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use XML::Simple;

my $device = '';
my $fastbootcmd = 'fastboot';
my $help;
my $pretend;
GetOptions("device|d|s=s" => \$device,
	   "fastboot|f=s" => \$fastbootcmd,
	   "help|h"       => \$help,
	   "pretend|p"    => \$pretend)
    or pod2usage(2);

pod2usage(-exitval => 0, -verbose => 3) if $help;

pod2usage(2) unless scalar (@ARGV) == 1;

my $xmlfile = $ARGV[0];

die "Cannot find regular file \"${xmlfile}\"" unless -f $xmlfile;

my ($vol, $dir) = File::Spec->splitpath($xmlfile);

my $xml = new XML::Simple;
my $data = $xml->XMLin($xmlfile);

print "Flashing ", $data->{'header'}->{'software_version'}->{'version'}, "\n" if defined($data->{'header'}->{'software_version'}->{'version'});

die "Cannot find steps" unless defined($data->{'steps'}->{'step'});
my $ss = $data->{'steps'}->{'step'};

my @steps = ();
if (ref($ss) eq 'ARRAY') {
    @steps = @{$ss};
} else {
    push @steps, $ss;
}

my $md5 = Digest::MD5->new;
my @cmds;
foreach my $step (@steps) {
    die "Invalid step: no operation" unless defined($step->{'operation'});
    my $op = $step->{'operation'};

    ## ERASE
    if ($op eq 'erase') {
	die "Invalid erase step: Missing partition" unless defined($step->{'partition'});
	push @cmds, ['erase', $step->{'partition'}];

    ## FLASH
    } elsif ($op eq 'flash') {
	die "Invalid flash step: Missing partition" unless defined($step->{'partition'});
	die "Invalid flash step: Missing filename" unless defined($step->{'filename'});
	my $par = $step->{'partition'};
	my $file = File::Spec->catpath($vol, $dir, $step->{'filename'});

	die "Cannot find file to flash: ${file}" unless -f $file;

	if (defined($step->{'MD5'})) {
	    print "Verifying MD5 sum of ${file}\n";
	    open(my $fhandle, '<', $file) or die "Cannot open flash file ${file}";
	    $md5->reset;
	    $md5->addfile($fhandle);
	    close($fhandle);
	    my $act = lc($md5->hexdigest);
	    my $exp = lc($step->{'MD5'});
	    die "MD5 digest mismatch on flash file ${file}, expected ${exp}, found ${act}" unless $act eq $exp;
	}
	push @cmds, ['flash', $par, $file];
	
    ## GETVAR
    } elsif ($op eq 'getvar') {
	die "Invalid getvar step: Missing var" unless defined($step->{'var'});
	push @cmds, ['getvar', $step->{'var'}];

    ## OEM
    } elsif ($op eq 'oem') {
	die "Invalid oem step: Missing var" unless defined($step->{'var'});
	push @cmds, ['oem', $step->{'var'}];

    } else {
	die "Invalid step: Unkown operation ${op}";
    }
}

my @base = ($fastbootcmd);
if ($device ne '') {
    push @base, '-s', $device;
}
foreach my $cmd (@cmds) {
    my @full = (@base, @{$cmd});
    print join(' ', @full), "\n";
    if (! $pretend) {
	system(@full) == 0 or die "Error calling fastboot";
    }
}

__END__
=head1 stock-flash.pl

Flash a stock rom onto an android phone

=head1 SYNOPSIS

B<stock-flash.pl> [B<-f> I<fastbootcmd>] [B<-s> I<devicepath>] [B<-p>] I<file.xml>
B<stock-flash.pl> {B<-h>|B<--help>}

=head1 OPTIONS

=over 8

=item B<-d>, B<--device>=I<DEVICEPATH>

Specify device serial number or path to device port as interperted by fastboot -s I<DEVICEPATH>.  If the empty string, no -s option is passed to fastboot.  Default is empty string.

=item B<-f>, B<--fastboot>=I<FASTBOOTCMD>

Sets the fastboot command name.  Must be either a file path or a program in current path.  Default is 'fastboot'.

=item B<-h>, B<--help>

Print this usage information and exit.

=item B<-p>, B<--pretend>

Perform any MD5 checks and print the fastboot that would be called, but don't acctually call fastboot.

=item B<-s>=I<DEVICEPATH>

Alias for B<-d>

=back

=head1 DESCRIPTION

B<stock-flash.pl> uses the external fastboot command to flash an android device back to stock configuration.  It requires an unziped stock rom file.  The rom file will contain either servicefile.xml or flashfile.xml or both.  servicefile.xml will return the device to stock configuration, preserving user data.  flashfile.xml will return the device to full factory configuration, wiping any user data.

B<The stock rom must be the correct rom for the phone.  stock-flash.pl has no way of verifying this and flashing the wrong rom will likely brick the phone.>

B<stock-flash.pl> reads the entire xml file, determines all the necessary steps,, verifies all files exist, and checks any provided MD5 sums before any flashboot commands are sent.  This reduces the chance that an invalid or corrupt rom will result in a partially flashed or bricked phone.

=head1 TROUBLESHOOTING

If the program hangs saying I<< < waiting for device > >>, then fastboot cannot locate your phone.  You can hit Ctrl-C to break and then run

    $ fastboot -l devices

to list available devices.  Make sure your phone is properly plugged in and that you have satisfied all the dependencies in the next section, including the proper USB drivers if stuck using windows.  If more than one device is plugged in, you can specify which device to flash using the B<-d> option.

If you receive errors about missing files, be sure you unzipped the entire rom and that the .xml file is in that directory.

If you receive errors about invalid steps, operations, or MD5 sums, the downloaded rom is invalid and cannot be processed.

=head1 DEPENDENCIES

B<stock-flash.pl> requires the external program fastboot.  On ubuntu based systems it is in the android-tools package and can be installed with

    $ sudo apt-get install android-tools

On debian systems it is in the fastboot package and can be installed using the command

    $ sudo apt-get install fastboot

On gentoo systems it is in the android-tools package and can be installed with

    $ sudo emerge -a android-tools

Mac users should install the package manager Homebrew and then run

    $ brew install android-platform-tools

Windows does not have a package manager so windows users must download and install the package manually.  Also, note that many versions of Windows do not include many of the USB drivers required for fastboot to work in the default install, so these will need to be downloaded and installed seperately.

B<stock-flash.pl> uses Perl and the perl module XML::Simple.  Perl is installed by default on nearly all linux distributions and Mac.  Windows users will need to download and install perl manually.  The XML::Simple module is packaged as libxml-simple-perl in ubuntu and dev-perl/XML-Simple on gentoo.  It can also be downloaded and installed with cpan.

=head1 COPYRIGHT

Copyright (c) 2017 Paul Maurer.  All rights reserved.  Licensed with the three clause BSD license included at the top of the program file.

=cut
