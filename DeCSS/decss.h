
typedef unsigned char DVD40bitKey[5];

void CSSdescramble(DVD40bitKey *key);
void CSSdescrambleSector(DVD40bitKey *key,unsigned char *sec);
void CSStitlekey1(DVD40bitKey *key,DVD40bitKey *im);
void CSStitlekey2(DVD40bitKey *key,DVD40bitKey *im);
void CSSdecrypttitlekey(DVD40bitKey *tkey,DVD40bitKey *dkey);
int CSScracker(int StartVal,unsigned char* pStream,DVD40bitKey *pkey);
int CSScrackerDVD(int StartVal,unsigned char* pCrypted,unsigned char* pDecrypted,DVD40bitKey *StreamKey,DVD40bitKey *pkey);