/* PING sweep written in REXX/400         */
/* Place in a source file you fancy       */
/* QGPL/QREXSRC �  is writable by default */ 
/* Copyright � Shalom Carmel 2004         */

/* Execute by the STRREXPRC command       */

/* Caveat Emptor                          */

/******* Parameters ***********************/
/* Start of  IP range                     */
StartIP = '192.168.0.1'

/* End of IP range                        */
EndIP   = '192.168.1.254'

/* NBR = Number of PING attempts          */
/* Default = 1                            */
/* NBR = 1  */
NBR = 1

/* Log library/file name            */
/* Default = same as script         */
/* Output_loc = '*SAME'             */
/* Output_loc = 'YOURLIB/YOURFILE'  */
Output_loc = '*SAME'

/* Log member name - must exist     */
/*  before script runs.             */
/* Script will append the log to the member */
/* Default = @PINGOUT               */
Output_name = '@PINGOUT'

/* 1=log all IP, 0=log success only */
LogAll  = '0'
/************************************************************************/
/*** no need to modify anything below this point, unless you really know*/
/*** what you are doing                                                 */
/************************************************************************/
numeric digits 10
if Output_loc = '*SAME' then do
    parse source _system _start _srcmbr _srcfile _srclib
    Output_loc = _srclib  || '/' || _srcfile
end
if translate(LogAll) = 'Y' | translate(LogAll) = 'YES' | LogAll= '1'
            then LogAll= '1'
            else LogAll= '0'
address command
bBuff = copies(' ', 12)
pingmsg = copies(' ', 80)
'OVRDBF FILE(STDOUT) TOFILE('Output_loc') mbr('Output_name') share(*yes)'
PARSE var StartIP s1 "." s2 "." s3 "." s4 "." .
PARSE var EndIP   e1 "." e2 "." e3 "." e4 "." .
sADDR = s1*256*256*256 + s2*256*256 + s3*256 + s4
eADDR = e1*256*256*256 + e2*256*256 + e3*256 + e4

do nADDR = sADDR to eADDR
    x = nADDR
    do i = 1 to 4
       c.i = x // 256
       x = x % 256
    end
   cADDR = c.4||'.'||c.3||'.'||c.2||'.'||c.1
    'ping rmtsys('''cADDR''') ADRVERFMT(*IP4) MSGMODE(*QUIET) NBRPKT('NBR') '
    'RCVMSG MSGTYPE(*COMP) msg(&PingMsg)'
    select
       when LogAll then say bBuff cADDR word(PingMsg,4)
       when word(PingMsg,4) > 0 then  say bBuff cADDR
       otherwise nop
    end
end
return
