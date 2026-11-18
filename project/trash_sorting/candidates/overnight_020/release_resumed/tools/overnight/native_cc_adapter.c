#include <process.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
/* _spawnv joins argv into a Windows command line; preserve spaces and quotes. */
static char *quote(const char *s){
 size_t n=strlen(s); char *r=malloc(n*2+3),*p=r;
 if(!r)return NULL;
 *p++='"';
 while(*s){
  size_t k=0;while(*s=='\\'){k++;s++;}
  if(*s=='"'||!*s)k*=2;
  while(k--)*p++='\\';
  if(*s=='"')*p++='\\';
  if(*s)*p++=*s++;
 }
 *p++='"';*p=0;return r;
}
int main(int argc,char **argv){
 const char *python="C:/Users/Twinkle Nebula/AppData/Local/Programs/Python/Python310/python.exe";
 const char **args=calloc((size_t)argc+4,sizeof *args);
 if(!args)return 2;
 args[0]=quote(python);args[1]=quote("-m");args[2]=quote("ziglang");args[3]=quote("cc");
 for(int i=1;i<argc;i++)args[i+3]=quote(argv[i]);
 for(int i=0;i<argc+3;i++)if(!args[i])return 2;
 int rc=(int)_spawnv(_P_WAIT,python,args);
 if(rc<0){perror("compiler launch");rc=2;}
 for(int i=0;i<argc+3;i++)free((void *)args[i]);
 free(args);return rc;
}
