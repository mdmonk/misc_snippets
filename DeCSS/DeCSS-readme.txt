     !! THIS PROGRAM IS FOR EDUCATIONAL PURPOSE ONLY !!
!! YOU ARE NOT ALLOWED TO MISUSE THIS PROGRAM TO COPY DVDS !!


 DeCSSplus v1.0 - Decrypt without knowing the key - (c) 2000 Ethan Hawke
-------------------------------------------------------------------------

About the syntax:
 DeCSSplus VOBInputFile [VOBOutputFile] [/p[ause]] [/v{0..9}] [/o[utput]] [/s]
   /p : Pause at the end of execution
   /v : Verbosity level 0..9
   /o : Use VOBInputFile as output if no output file given
   /s : Scan entier file. Default is to stop after having found 20 times the same key.

About the program:
  DeCSSplus is another program which decrypts the content of a DVD drive. DeCSS by MoRE
 is still my favorite when you have the original medium. But what to do when someone
 gives you the crypted content WITHOUT the DVD or a key to decrypt it? Well, you could
 start guessing the key or just use this program [:)].

How it works:
  We used Frank A. Stevenson's alogithm of finding the key from the crypted and decrypted
 content. The only problem was: How to find the decrypted content? Pretty easy, if we
 might add. The content that was ciphered is an MPEG-2 stream. So if you somehow pre-
 dicted ten bytes of the ciphered stream you could calculate the key.
  Have you ever looked at a MPEG bitstream which compressed a black screen? You'd see a
 lot of repetitions. And that's exactly what we're exploiting.

Why we made it:
  Think of it: a 40 bit disc key, a 40 bit chapter key and a 40 bit player key is used
  to decipher a DVD movie. Difficult to crack the key you say. Brute force might work
  if your mpeg stream has a CRC to check if the content is right. You'd need a few days
  but we do it in less than a few seconds. Some people at hollywood made it a heck of a
  lot easy for us.  

Post Readme:
   Have phun using this program. And don't copy DVDs.

!! YOU ARE NOT ALLOWED TO MISUSE THIS PROGRAM TO COPY DVDS !!
     !! THIS PROGRAM IS FOR EDUCATIONAL PURPOSE ONLY !!
