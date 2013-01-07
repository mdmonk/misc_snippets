
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "DeCSS.h"

#define MaxKeys 1000

typedef struct
	{
		int				occ;
		DVD40bitKey		key;
	} KeyOcc;

void Syntax(void)
{
	printf("SYNTAX ERROR: Wrong number of parameters.\n");
	printf(" DeCSSplus VOBInputFile [VOBOutputFile] [/p[ause]] [/v{0..9}] [/o[utput]] [/s]\n");
	printf("   /p : Pause at the end of execution\n");
	printf("   /v : Verbosity level 0..9\n");
	printf("   /o : Use VOBInputFile as output if no output file given\n");
	printf("   /s : Scan entier file. Default is to stop after having found 20 times the same key.\n\n");
	printf(" Please make sure the file is _readable_. Use a DVD-player to\n");
	printf(" remove the sector protection\n\n");
}

int main( int argc, char* argv[] ) {

int				paramPause = 0;
int				paramVerbose = 1;
int				paramOutput = 0;
int				paramScanAll = 0;
char			*paramInputFile = NULL;
char			*paramOutputFile = NULL;

FILE			*in,*out;
unsigned char	buf[0x800];
DVD40bitKey		MyKey;
int				pos,BytesRead,BytesWritten,BestPLen,BestP,i,j,k,encrypted=0,filsize;
KeyOcc			PosKey[MaxKeys];
int				RegisteredKeys = 0, TotalKeysFound = 0, StopScanning = 0;

	if (paramVerbose>=1)
	{
		printf(" DeCSSplus v1.0 - Decrypt without knowing the key - (c) 2000 Ethan Hawke\n");
		printf("-------------------------------------------------------------------------\n");
	}

	if (argc<2)
	{
		Syntax();
		if (paramPause)
		{
			printf("Press ENTER key to continue ...\n");
			getchar();
		}
		return(1);
	}
	i=1;
	while (i<argc)
	{
		if (strncmp(argv[i],"/",1)==0)
		{
			if (strncmp(argv[i],"/p",2)==0) paramPause = 1;
			else if (strncmp(argv[i],"/v",2)==0) paramVerbose = atoi((argv[i])+2);
			else if (strncmp(argv[i],"/s",2)==0) paramScanAll = 1;
			else if (strncmp(argv[i],"/o",2)==0) paramOutput = 1;
			else
			{
				Syntax();
				if (paramPause)
				{
					printf("Press ENTER key to continue ...\n");
					getchar();
				}
				return(1);
			}
		}
		else
		{
			if (!paramInputFile) paramInputFile = argv[i];
			else if (!paramOutputFile) { paramOutputFile = argv[i]; paramOutput = 1; }
			else
			{
				Syntax();
				if (paramPause)
				{
					printf("Press ENTER key to continue ...\n");
					getchar();
				}
				return(1);
			}
		}
		i++;
	}

	if (in = fopen(paramInputFile,"rb"))
	{
		pos = 0;
		fseek(in,0,SEEK_END);
		filsize = ftell(in);
		fseek(in,0,SEEK_SET);

		do
		{
			if (paramVerbose>=1 && filsize>1024*1024) printf("%.2f of file read & found %i keys...\r",pos*100.0/filsize,TotalKeysFound);
			BytesRead = fread(buf,1,0x800,in);
			if (buf[0x14] & 0x30) // PES_scrambling_control
			{
				encrypted = 1;
				BestPLen = 0;
				BestP = 0;
				for(i=2;i<0x30;i++)
				{
					for(j=i;(j<0x80) && (buf[0x7F-(j%i)]==buf[0x7F-j]);j++);
					if ((j>BestPLen) && (j>i))
					{
						BestPLen = j;
						BestP = i;
					}
				}
				if ((BestPLen>20) && (BestPLen/BestP>=2))
				{
					i = CSScrackerDVD(0,&buf[0x80],&buf[0x80-(BestPLen/BestP)*BestP],(DVD40bitKey*)&buf[0x54],&MyKey);
					while (i>=0)
					{
						k = 0;
						for(j=0;j<RegisteredKeys;j++)
							if (memcmp(&(PosKey[j].key),&MyKey,sizeof(DVD40bitKey))==0)
							{
								PosKey[j].occ++;
								TotalKeysFound++;
								k = 1;
							}
						if (k==0)
						{
							memcpy(&(PosKey[RegisteredKeys].key),&MyKey,sizeof(DVD40bitKey));
							PosKey[RegisteredKeys++].occ = 1;
							TotalKeysFound++;
						}

						if (paramVerbose>=2) printf("\nOfs:%08X - Key: %02X %02X %02X %02X %02X\n",pos,MyKey[0],MyKey[1],MyKey[2],MyKey[3],MyKey[4]);
						i = CSScrackerDVD(i,&buf[0x80],&buf[0x80-(BestPLen/BestP)*BestP],(DVD40bitKey*)&buf[0x54],&MyKey);
					}
					if (RegisteredKeys==1 && PosKey[0].occ>=20) StopScanning = 1;
				}
			}
			
			pos += BytesRead;
		} while (BytesRead==0x800 && !StopScanning);

		fclose(in);
		if (paramVerbose>=1 && StopScanning) printf("Found enough occurancies of the same key. Scan stopped.");
		if (paramVerbose>=1) printf("\n\n");
	}
	else
	{
		printf("FILE ERROR: File could not be opened. [Check if file is readable]\n");
		if (paramPause)
		{
			printf("Press ENTER key to continue ...\n");
			getchar();
		}
		return(1);
	}

	if (!encrypted)
	{
		printf("This file was _NOT_ encrypted!\n");
		if (paramPause)
		{
			printf("Press ENTER key to continue ...\n");
			getchar();
		}
		return(0);
	}

	if (encrypted && RegisteredKeys==0)
	{
		printf("Sorry... No keys found to this encrypted file.\n");
		if (paramPause)
		{
			printf("Press ENTER key to continue ...\n");
			getchar();
		}
		return(1);
	}

	for(i=0;i<RegisteredKeys-1;i++)
		for(j=i+1;j<RegisteredKeys;j++)
			if (PosKey[j].occ>PosKey[i].occ)
			{
				memcpy(&MyKey,&(PosKey[j].key),sizeof(DVD40bitKey));
				k = PosKey[j].occ;
				memcpy(&(PosKey[j].key),&(PosKey[i].key),sizeof(DVD40bitKey));
				PosKey[j].occ = PosKey[i].occ;
				memcpy(&(PosKey[i].key),&MyKey,sizeof(DVD40bitKey));
				PosKey[i].occ = k;
			}

	if (paramVerbose>=1)
	{
		printf(" Key(s) & key probability\n--------------------------\n");
		for(i=0;i<RegisteredKeys;i++)
			printf(" %02X %02X %02X %02X %02X - %3.2f%%\n",PosKey[i].key[0],PosKey[i].key[1],PosKey[i].key[2],PosKey[i].key[3],PosKey[i].key[4],PosKey[i].occ*100.0/TotalKeysFound);
		printf("\n");
	}

	if (paramOutput)
	{

		if (RegisteredKeys>1)
		{
			printf(" Which stream key do you want to use (ex. 13 47 8A BC EF): ");
			if (scanf("%2X %2X %2X %2X %2X",&(MyKey[0]),&(MyKey[1]),&(MyKey[2]),&(MyKey[3]),&(MyKey[4]))!=5)
			{
				printf("\nNot a valid key.\n");
				if (paramPause)
				{
					printf("Press ENTER key to continue ...\n");
					getchar();
				}
				return(1);
			}
			if (paramVerbose>=2) printf("Using key %02X %02X %02X %02X %02X\n",MyKey[0],MyKey[1],MyKey[2],MyKey[3],MyKey[4]);
		}
		else
			memcpy(&(MyKey),&(PosKey[0].key),sizeof(DVD40bitKey));

		if (paramOutputFile)
		{
			if (in = fopen(paramInputFile,"rb"))
			{
				if (out = fopen(paramOutputFile,"wb"))
				{
					pos = 0;
					do
					{
						if (paramVerbose>=1 && filsize>1024*1024) printf("%.2f of file read/written...\r",pos*100.0/filsize);
						BytesRead = fread(&buf,1,0x800,in);
						if (buf[0x14] & 0x30) // PES_scrambling_control
						{
							CSSdescrambleSector(&MyKey,(unsigned char*)&buf);
							buf[0x14] &= 0x8F;
						}
						BytesWritten = fwrite(&buf,1,BytesRead,out);
						if (BytesWritten!=BytesRead)
						{
							printf("Could not write to output file.\n");
							if (paramPause)
							{
								printf("Press ENTER key to continue ...\n");
								getchar();
							}
							return(1);
						}
						pos += BytesRead;
					} while (BytesRead==0x800);
				}
				else
				{
					printf("\n File could not be opened for Write.\n");
					if (paramPause)
					{
						printf("Press ENTER key to continue ...\n");
						getchar();
					}
					return(1);
				}
			}
			else
			{
				printf("\n File could not be opened for Read/Write.\n");
				if (paramPause)
				{
					printf("Press ENTER key to continue ...\n");
					getchar();
				}
				return(1);
			}
		}
		else
		{
			if (in = fopen(paramInputFile,"r+b"))
			{
				pos = 0;
				do
				{
					if (paramVerbose>=1 && filsize>1024*1024) printf("%.2f of file read/written...\r",pos*100.0/filsize);
					fseek(in,pos,SEEK_SET);
					BytesRead = fread(&buf,1,0x800,in);
					if (buf[0x14] & 0x30) // PES_scrambling_control
					{
						CSSdescrambleSector(&MyKey,(unsigned char*)&buf);
						buf[0x14] &= 0x8F;
					}
					fseek(in,pos,SEEK_SET);
					fwrite(&buf,1,BytesRead,in);				
					pos += BytesRead;
				} while (BytesRead==0x800);
			}
			else
			{
				printf("\n File could not be opened for Read/Write.\n");
				if (paramPause)
				{
					printf("Press ENTER key to continue ...\n");
					getchar();
				}
				return(1);
			}
		}

	}

	if (paramPause)
	{
		printf("Press ENTER key to continue ...\n");
		getchar();
	}
	return(0);
}
