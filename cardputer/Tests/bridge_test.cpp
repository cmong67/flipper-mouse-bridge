#include "../Firmware/src/bridge.h"
#include <assert.h>
#include <string>
#include <vector>
#include <iostream>
struct Report {int b,x,y,w,p;};
struct Fake:BridgeIO {
 uint32_t clock=0;bool connected=true,fail=false;std::vector<Report> reports;
 uint32_t now() override{return clock;}
 void pause(uint32_t ms) override{clock+=ms;}
 bool ready() override{return connected;}
 bool send(uint8_t b,int8_t x,int8_t y,int8_t w,int8_t p) override {
  if(fail)return false;
  reports.push_back({b,x,y,w,p});return true;
 }
};
std::string cmd(Bridge &b,const char *text) {
 char input[256],output[100];snprintf(input,sizeof(input),"%s",text);
 return b.command(input,output,sizeof(output));
}
int main(){
 Fake f;Bridge b(f);
 assert(cmd(b,"status")=="OK HID=1 ARMED=0 BUTTONS=0");
 assert(cmd(b,"move 1 2")=="ERR disarmed");assert(f.reports.empty());
 assert(cmd(b,"ARM")=="OK ARMED");
 f.reports.clear();assert(cmd(b,"move -2048 2048")=="OK MOVE");
 int x=0,y=0;for(auto r:f.reports){assert(abs(r.x)<=127 && abs(r.y)<=127);x+=r.x;y+=r.y;}
 assert(x==-2048 && y==2048);
 size_t count=f.reports.size();
 for(auto s:{"move 2049 0","move nope 0","move 1x 0","move 99999999999999999999999 0","move + 0","scroll 128","drag bad 1 2","click nowhere","arm extra","move 1 2 3 4 5 6"}){
  assert(cmd(b,s).find("ERR ")==0);assert(f.reports.size()==count);
 }
 assert(cmd(b,"scroll 2 -1")=="OK SCROLL");assert(f.reports.back().w==2 && f.reports.back().p==-1);
 assert(cmd(b,"down left")=="OK DOWN");assert(b.buttons()==1);
 f.clock+=1499;b.service();assert(b.buttons()==1);
 f.clock+=1;b.service();assert(b.buttons()==0);
 assert(cmd(b,"down forward")=="OK DOWN");assert(b.buttons()==16);
 assert(cmd(b,"stop")=="OK STOP");assert(!b.armed() && !b.buttons());
 assert(cmd(b,"arm")=="OK ARMED");assert(cmd(b,"double right")=="OK DOUBLE");assert(!b.buttons());
 assert(cmd(b,"drag middle -2048 7")=="OK DRAG");assert(!b.buttons());
 assert(cmd(b,"down back")=="OK DOWN");
 f.clock+=60000;b.service();assert(!b.armed() && !b.buttons());
 assert(cmd(b,"arm")=="OK ARMED");assert(cmd(b,"down left")=="OK DOWN");
 f.connected=false;b.service();assert(!b.armed());f.connected=true;b.service();assert(!b.buttons());
 f.fail=true;assert(cmd(b,"arm").find("ERR ")==0);assert(!b.armed());f.fail=false;count=f.reports.size();b.service();assert(f.reports.size()==count+1 && f.reports.back().b==0);
 f.clock=UINT32_MAX-1000;assert(cmd(b,"arm")=="OK ARMED");f.clock+=60001;b.service();assert(!b.armed());
 assert(cmd(b,"quit")=="OK QUIT");assert(!b.armed());
 std::cout<<"PASS: protocol, strict parsing, HID bounds, exact motion totals, five buttons, wheels, drag, double click, release timeout, arm expiry, disconnect, send failure, clock rollover, quit\n";
}
