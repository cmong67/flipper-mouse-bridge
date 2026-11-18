#pragma once
#include <errno.h>
#include <stdlib.h>
#include <string.h>
struct HostInfo {int x,y,display;char app[49];};
inline bool parseHost(const char *text,HostInfo &out) {
 long numbers[3];const char *p=text;
 for(int i=0;i<3;++i) {
  if(!*p || !((*p>='0' && *p<='9') || *p=='-' || *p=='+')) return false;
  char *end;errno=0;numbers[i]=strtol(p,&end,10);
  if(errno==ERANGE || end==p || *end!=' ') return false;
  p=end+1;
 }
 if(numbers[0]<-100000 || numbers[0]>100000 || numbers[1]<-100000 || numbers[1]>100000 || numbers[2]<1 || numbers[2]>32) return false;
 size_t size=strlen(p);if(size==0 || size>48) return false;
 for(const char *c=p;*c;++c) if(*c<32 || *c>126) return false;
 out.x=numbers[0];out.y=numbers[1];out.display=numbers[2];memcpy(out.app,p,size+1);return true;
}

struct ObservedInput {int kind,buttons,button,dx,dy,wx,wy;};
inline bool parseObservedInput(const char *text,ObservedInput &out) {
 long values[7];const char *p=text;
 for(int i=0;i<7;++i) {
  if(!*p || !((*p>='0' && *p<='9') || *p=='-' || *p=='+')) return false;
  char *end;errno=0;values[i]=strtol(p,&end,10);
  if(errno==ERANGE || end==p || values[i]<-100000 || values[i]>100000) return false;
  if(i<6) {if(*end!=' ') return false;p=end+1;} else if(*end) return false;
 }
 if(values[0]<0 || values[0]>6 || values[1]<0 || values[1]>31 || values[2]<0 || values[2]>4) return false;
 out={int(values[0]),int(values[1]),int(values[2]),int(values[3]),int(values[4]),int(values[5]),int(values[6])};return true;
}

inline bool parseViewport(const char *text,int &width,int &height) {
 long v[2];const char *p=text;
 for(int i=0;i<2;++i) {
  if(*p<'0' || *p>'9') return false;
  char *end;errno=0;v[i]=strtol(p,&end,10);
  if(errno==ERANGE || v[i]<1 || v[i]>32768) return false;
  if(i==0) {if(*end!=' ') return false;p=end+1;} else if(*end) return false;
 }
 width=v[0];height=v[1];return true;
}
