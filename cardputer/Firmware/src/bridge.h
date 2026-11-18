#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
class BridgeIO {
public:
 virtual uint32_t now()=0;
 virtual void pause(uint32_t ms)=0;
 virtual bool ready()=0;
 virtual bool send(uint8_t b,int8_t x,int8_t y,int8_t w,int8_t p)=0;
 virtual ~BridgeIO()=default;
};
class Bridge {
 BridgeIO &io;
 bool armed_=false,holding=false,pendingRelease=false;
 uint8_t buttons_=0;
 uint32_t armedAt=0,heldAt=0;
 bool report(uint8_t b,int x=0,int y=0,int w=0,int p=0) {
  if(!io.ready() || !io.send(b,x,y,w,p)) {stop();return false;}
  buttons_=b;pendingRelease=false;return true;
 }
 static bool number(const char *s,int limit,int &out) {
  if(!s || !*s) return false;
  const char *p=(*s=='-' || *s=='+')?s+1:s;
  if(!*p) return false;
  for(;*p;++p) if(*p<'0' || *p>'9') return false;
  char *end;long n=strtol(s,&end,10);
  if(*end || n < -limit || n>limit) return false;
  out=(int)n;return true;
 }
 static uint8_t button(const char *s) {
  if(!strcmp(s,"left")) return 1;
  if(!strcmp(s,"right")) return 2;
  if(!strcmp(s,"middle")) return 4;
  if(!strcmp(s,"back")) return 8;
  if(!strcmp(s,"forward")) return 16;
  return 0;
 }
 bool travel(int x,int y,int w=0,int p=0) {
  int biggest=abs(x);
  if(abs(y)>biggest) biggest=abs(y);
  if(abs(w)>biggest) biggest=abs(w);
  if(abs(p)>biggest) biggest=abs(p);
  int steps=(biggest+126)/127;if(!steps) steps=1;
  int px=0,py=0,pw=0,pp=0;
  for(int i=1;i<=steps;++i) {
   service();if(!armed_) return false;
   int nx=x*i/steps,ny=y*i/steps,nw=w*i/steps,np=p*i/steps;
   if(!report(buttons_,nx-px,ny-py,nw-pw,np-pp)) return false;
   px=nx;py=ny;pw=nw;pp=np;io.pause(8);
  }
  return true;
 }
 bool click(uint8_t b) {
  uint8_t previous=buttons_;
  if(!report(previous|b)) return false;
  io.pause(40);return report(previous);
 }
public:
 explicit Bridge(BridgeIO &transport):io(transport) {}
 bool armed() const {return armed_;}
 uint32_t remainingSeconds() {uint32_t elapsed=uint32_t(io.now()-armedAt);return armed_ && elapsed<60000 ? (60000-elapsed+999)/1000 : 0;}
 uint8_t buttons() const {return buttons_;}
 void stop() {
  armed_=false;holding=false;pendingRelease=true;
  // If release cannot be queued, service retries it after the endpoint recovers.
  if(io.ready() && io.send(0,0,0,0,0)) {buttons_=0;pendingRelease=false;}
 }
 void service() {
  if(!io.ready()) {armed_=false;holding=false;pendingRelease=true;return;}
  if(armed_ && uint32_t(io.now()-armedAt)>=60000) stop();
  if(holding && uint32_t(io.now()-heldAt)>=1500) {
   if(io.send(0,0,0,0,0)) {buttons_=0;holding=false;} else stop();
  }
  if(!armed_ && (buttons_ || pendingRelease) && io.send(0,0,0,0,0)) {buttons_=0;pendingRelease=false;}
 }
 const char *command(char *line,char *response,size_t capacity) {
  service();char *argv[6],*save=nullptr;int argc=0;
  for(char *p=strtok_r(line," \t",&save);p;p=strtok_r(nullptr," \t",&save)) {
   if(argc==6) return "ERR invalid command";
   for(char *c=p;*c;++c) if(*c>='A' && *c<='Z') *c+='a'-'A';
   argv[argc++]=p;
  }
  if(!argc) return "ERR empty command";
  const char *name=argv[0];
  if(!strcmp(name,"ping") && argc==1) return "OK PONG";
  if(!strcmp(name,"status") && argc==1) {
   snprintf(response,capacity,"OK HID=%d ARMED=%d BUTTONS=%u",io.ready(),armed_,buttons_);return response;
  }
  if((!strcmp(name,"stop") || !strcmp(name,"quit")) && argc==1) {
   stop();return !strcmp(name,"quit")?"OK QUIT":"OK STOP";
  }
  if(!strcmp(name,"arm") && argc==1) {
   stop();if(!report(0)) return "ERR HID unavailable";
   armed_=true;armedAt=io.now();return "OK ARMED";
  }
  if(!armed_) return "ERR disarmed";
  int x=0,y=0;bool ok=false;
  if(!strcmp(name,"move") && argc==3 && number(argv[1],2048,x) && number(argv[2],2048,y)) ok=travel(x,y);
  else if(!strcmp(name,"scroll") && (argc==2 || argc==3) && number(argv[1],127,y) && (argc==2 || number(argv[2],127,x))) ok=travel(0,0,y,x);
  else if(argc==2 && (!strcmp(name,"click") || !strcmp(name,"double") || !strcmp(name,"down") || !strcmp(name,"up"))) {
   uint8_t b=button(argv[1]);if(!b) return "ERR unknown button";
   if(!strcmp(name,"down")) {ok=report(buttons_|b);holding=ok;heldAt=io.now();}
   else if(!strcmp(name,"up")) {ok=report(buttons_ & ~b);if(!buttons_) holding=false;}
   else {
    if(buttons_ & b) return "ERR button already down";
    ok=click(b);
    if(ok && !strcmp(name,"double")) {io.pause(85);service();ok=armed_ && click(b);}
   }
  } else if(!strcmp(name,"drag") && argc==4 && number(argv[2],2048,x) && number(argv[3],2048,y)) {
   uint8_t b=button(argv[1]);if(!b || buttons_) return "ERR unknown button or another button held";
   ok=report(b);
   if(ok) {holding=true;heldAt=io.now();io.pause(40);ok=travel(x,y);}
   bool released=report(0);holding=false;ok=ok && released;
  } else return "ERR invalid command or out of range";
  if(!ok) return "ERR HID unavailable or arm expired";
  snprintf(response,capacity,"OK %s",name);
  for(char *p=response+3;*p;++p) if(*p>='a' && *p<='z') *p-='a'-'A';
  return response;
 }
};
