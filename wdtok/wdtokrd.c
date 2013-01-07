/*************************************************************
* Program Name:  WDTOKRD.EXE
* Source Name:   WDTOKRD.C
* Programmer:    Chuck Little
* Date:          28 Oct 1998  <-- Notice: Y2K Compliant.
* 
* Description:   This small program opens the binary file
*                WDTOK.CFG and jumps to byte 84 in the file.
*                It then reads for 6 bytes (gets the TIC addr)
*                and writes it to the file DESTADD.TXT.
*
* Revisions:
*   24 Oct 1998: Initial coding.
*   28 Oct 1998: Found that if WDTOK.CFG does not exist, this
*                program crashes. FIXED. Added check to ensure
*                no processing is done if file does not exist.
*   10 Nov 1998: Source file WDTOK.CFG is actually located in  
* 	 	           D:\APPS\Rumba\Mframe 
*
* NOTE:          This is just an initial implementation. It is
*                Not bulletproof. But from what I understand,
*                it doesn't need to be.
**************************************************************/
#include <stdio.h>

FILE * fp;

main ()
{
  int x = 0;
  fp = fopen("d:\\apps\\rumba\\mframe\\wdtok.cfg", "rb");
  if (fp == NULL ) {
    return(-1);
  } else {
    FILE * fp2 = fopen("d:\\apps\\rumba.old\\uninst\\destadd.txt", "w");

    unsigned char addr[6];
    fseek(fp, 84, SEEK_SET);
  
    for (x = 0; x < 6; x++) {
      fscanf(fp, "%c", &addr[x]);
      fprintf(fp2, "%02x", addr[x]);
    } /* end for */
    fclose(fp);
    fclose(fp2);
    return(0);
  } /* end if-else */
}
