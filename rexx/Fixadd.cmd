/**/

call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs


F = 'C:\CONFIG.SYS'        /* Name of the file to modify */

S = ''     /* String to search for - additions will be made after this line */
                          /* Unless Replace is YES - then the line will be replaced. */

R = '0'             /* Replace line from search 1=YES or 0=NO */

L = 1                /* Line position to add lines if search parameter not specified */
                      /* additions will be written imediatly following the line specified */

A = 2                /* Number of lines to add to file */

/* The folling variables are the linse to be added in the form ADD.N */
/*  Add and remove ADD.N variables as required.  */

ADD.1 = 'DEVICE=C:\OS2\INSTALL\IBMLANLK.SYS C:\LS30FIX.LST'
ADD.2 = 'RUN=C:\OS2\INSTALL\IBMLANLK.EXE C:\LS30FIX.LST'

call sysmkdir 'c:\lstemp'
say '     Copying files to a temporary directory.'
say ' '
'@xcopy a:\lstemp\. c:\lstemp >nul'
say '     Copying locked files device driver list file.'
say ' '
'@copy a:\ls30fix.lst c:\ >nul'
say '     Modifying config.sys for locked files device driver.'

N = 0
M = 0

S = translate(s)

do until lines(f) = 0
  n = n + 1
  rec.n=translate(linein(f))
  if S <> '' then
    do
      if pos(S,rec.n) > 0 then
        m = n
    end
  else
    M = L
end

if m <> 0 then
  do
    call lineout(F)
    '@del 'F' >nul 2>nul'
    if R = '1' then
      x = M - 1
    else x = m
    do I = 1 to x
       call lineout F, rec.i
    end

    do I = 1 to A
      call lineout F, ADD.I
    end

    m = m +1
    do I = m to n
      call lineout F, rec.i
    end 
  end   
Exit