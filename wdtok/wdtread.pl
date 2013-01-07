#! perl.exe
##############################################
# To read the TIC address out of WDTOK.CFG
#
#  - It's a binary file and thus unreadable
#    by normal standards.
##############################################
use IO::Seekable;

open(FH, "d:\\apps\\rumba\\system\\wdtok.cfg") or die "Unable to open WDTOK.CFG: $!\n";
open(OUTFH, ">d:\\apps\\rumba.old\\uninst\\destadd.txt") or die "Unable to open DESTADD.TXT: $!\n";
seek (FH, 84, SEEK_SET) or die "can't seek to byte 84 in WDTOK.CFG: $!\n";
read (FH, $addr, 6);
close (FH);
foreach(split(//, $addr)) {
  printf( OUTFH ("%02x", ord($_)));
}
close(OUTFH);
