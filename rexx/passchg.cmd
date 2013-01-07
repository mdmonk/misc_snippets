/* PASSCHG.CMD */
call rxfuncadd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
call SysLoadFuncs

START:
call syscls
'@echo [1;31;40m'

Say '               YOU MUST BE LOGGED ON WITH ADMINISTRATIVE AUTHORITY'
Say '                           TO CHANGE LOCKUP PASSWORDS.'
Say '                        CHANGES TAKE EFFECT AFTER REBOOT'
Say '               ---------------------------------------------------'
'@echo [1;33;40m'
say ' '
Say '     Do you want to change the password on;'
Say ' '
say '             A - Single Server'
say ' '         
say '             B - From Servers Listed in the File SERVER.LST'
say ' '
say '             C - All Servers in the Local Domain and'
say '                 Listed in the OTHDOMAINS Line of IBMLAN.INI'
say ' '
say '             D - View a Server Password'
say ' '
say '                 ANYTHING ELSE TO EXIT'
say ' '
'@echo [1;32;40m'
say '     Enter Selection '

parse value SysCurPos() with row col
'@echo [1;36;40m'
row = row - 1
pos = SysCurPos(row,22)

parse upper value SysGetKey() with c

if c <> 'A' & c <> 'B' & c <> 'C' & c <> 'D' then
  signal quit

say ' '
say '     Your selection was 'c'  Do you wish to continue?'
parse value SysCurPos() with row col
row = row - 1
pos = SysCurPos(row,52)
parse upper value sysgetkey() with t

if t <> 'Y' then	
  signal start


SELECT
   
  when c = 'A'
     then call single

  when c = 'B'
     then call list

  when c = 'C'
     then call list
 
  when c = 'D'
     then call view

  otherwise
    signal quit
       
end
Signal start

QUIT:
call syscls
do 3
  say ' '
end
exit

SINGLE:
call syscls
do 3
  say ' '
end
say '     Enter the name of the server to change the lockup password on.'
say ' '
say '          >>>>>'
parse value SysCurPos() with row col
row = row - 1
pos = SysCurPos(row,16)
parse upper pull Name

say ' '
say '     Enter the new password.'
say ' '
say '          >>>>>'
parse value SysCurPos() with row col
row = row - 1
pos = SysCurPos(row,16)
parse upper pull PW

'@echo [1;33;40m'
say '     Server Name - 'name  
say ' '
say '     New Password - 'PW
say ' '
say '     Are these values correct?'
parse value SysCurPos() with row col
'@echo [1;36;40m'
row = row - 1

pos = SysCurPos(23,5)
say 'Press M for Main Menu'

pos = SysCurPos(row,32)
parse upper value sysgetkey() with t

if t = 'M' then
  signal start

if t <> 'Y' then
  signal single

call syscls
do 3
  Say ' '
end
'@net admin \\'name' /c c:\utils\pw c 'pw
if rc = '0' then
  do
    say ' '
    say '     Password changed on 'NAME'.'
  end
else
  do
    '@echo [1;31;40m'    
    say '     Change unsuccessful on 'NAME'.'  
  end
'@echo [1;36;40m'
pos = SysCurPos(23,5)
'@pause'
return


LIST:
call syscls
do 3
  say ' '
end
if c = 'B' then 
  do
    say '     Server Name will be taken from the text file SERVER.LST' 
    file = 'SERVER.LST'
    NAME = linein(file)
  end
  else nop
  
if c = 'C' then
  do
    say '     Server Names will be taken from the NET VIEW command'
    file = 'viewlist.txt'
    '@net view > 'file
    do 3
      NAME = linein(file)
    end
  end
  else nop

say ' '
say '     Enter the new password'
say ' '
say '          >>>>>'

parse value SysCurPos() with row col
row = row - 1
pos = SysCurPos(row,16)
parse upper pull pw
say ' '
say '     Is what you typed above correct?'
parse value SysCurPos() with row col
row = row - 1

pos = SysCurPos(23,5)
say 'Press M for Main Menu'

pos = SysCurPos(row,38)
parse upper value sysgetkey() with t

if t = 'M' then
  signal start

if t <> 'Y' then
  signal list

call syscls
do 3
  say ' '
end

do while lines(file) > 0
  if name <> ' ' then
    do
      if c = 'C' then
        name = substr(name,3,7)
        else name = substr(name,1,7)
      '@net admin \\'NAME' /c c:\utils\pw c 'pw
      if rc = '0' then
        do
          say ' '
          say '     Password changed on 'NAME'.'
        end
      else
        do
          '@echo [1;31;40m'
          say '     Change unsuccessful on 'NAME'.'  
          '@echo [1;36;40m'
        end
    end
  NAME = linein(file)
end

call lineout file
if c = 'C' then
  '@del viewlist.txt > nul'
say ' '
pos = SysCurPos(23,5)
'@pause'
return


VIEW:
call syscls
do 3
  say ' '
end
say '     Enter the Name of the Server to check the password on.'
say ' '
say '          >>>>>'
parse value SysCurPos() with row col
row = row - 1
pos = SysCurPos(row,16)
parse upper pull name
say ' '
say '     Is what you typed above correct?'
parse value SysCurPos() with row col
row = row - 1

pos = SysCurPos(23,5)
say 'Press M for Main Menu'

pos = SysCurPos(row,38)
parse upper value sysgetkey() with t

if t = 'M' then
  signal start

if t <> 'Y' then
  signal view

say ' '
say ' '
say ' '
say '     THE PASSWORD FOR 'NAME' IS '     

'@net admin \\'name' /c c:\utils\pw v'
say ' '
pos = SysCurPos(23,5)
'@PAUSE'
RETURN

