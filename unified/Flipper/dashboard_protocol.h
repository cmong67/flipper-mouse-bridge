#pragma once
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
// Exact integer fields, bounded before conversion to the device's int type.
static bool dashboard_numbers(const char* p,int* out,size_t count,const char** text) {
 for(size_t i=0;i<count;i++) {
  if(!*p || !((*p>='0' && *p<='9') || *p=='-' || *p=='+')) return false;
  char* end;errno=0;long n=strtol(p,&end,10);
  if(errno==ERANGE || end==p || n < -100000 || n>100000) return false;
  out[i]=(int)n;
  if(i+1<count || text) {if(*end!=' ') return false;p=end+1;}
  else {if(*end) return false;p=end;}
 }
 if(text) {*text=p;size_t len=strlen(p);if(!len || len>44) return false;for(;*p;p++) if(*p<32 || *p>126) return false;}
 return true;
}
