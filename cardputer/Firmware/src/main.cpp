#include <Arduino.h>
#include <M5Cardputer.h>
#include <USB.h>
#include <USBHID.h>
#include <esp_sleep.h>
#include <esp_ota_ops.h>
#include <Preferences.h>
#include "bridge.h"
#include "host.h"
static const uint8_t descriptor[]={
 0x05,0x01,0x09,0x02,0xa1,0x01,0x09,0x01,0xa1,0x00,
 0x05,0x09,0x19,0x01,0x29,0x05,0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x05,0x81,0x02,
 0x75,0x03,0x95,0x01,0x81,0x03,
 0x05,0x01,0x09,0x30,0x09,0x31,0x09,0x38,0x15,0x81,0x25,0x7f,0x75,0x08,0x95,0x03,0x81,0x06,
 0x05,0x0c,0x0a,0x38,0x02,0x15,0x81,0x25,0x7f,0x75,0x08,0x95,0x01,0x81,0x06,0xc0,0xc0
};
class CommandMouse:public USBHIDDevice,public BridgeIO {
 USBHID hid;
public:
 CommandMouse() {hid.addDevice(this,sizeof(descriptor));}
 uint16_t _onGetDescriptor(uint8_t *dst) override {memcpy(dst,descriptor,sizeof(descriptor));return sizeof(descriptor);}
 void begin() {hid.begin();}
 uint32_t now() override {return millis();}
 void pause(uint32_t ms) override {delay(ms);}
 bool ready() override {return hid.ready();}
 bool send(uint8_t b,int8_t x,int8_t y,int8_t w,int8_t p) override {
  uint8_t data[5]={b,uint8_t(x),uint8_t(y),uint8_t(w),uint8_t(p)};
  return hid.SendReport(0,data,sizeof(data),100);
 }
};
CommandMouse mouse;
Bridge bridge(mouse);
char line[97];size_t length=0;bool discard=false;
constexpr const char *kVersion="1.3.0";
int hostX=0,hostY=0,hostDisplay=0;
char hostApp[49]="Waiting for Mac";
uint32_t hostUpdated=0,commands=0,hostSessionAt=0;
bool gotHost=false;
char lastCommand[40]="Ready";
char lastObserved[40]="";uint32_t observedAt=0;bool gotObserved=false;
ObservedInput observed={0,0,0,0,0,0,0};
int trailX[10],trailY[10],trailCount=0;
int viewportWidth=16,viewportHeight=9;
uint32_t wheelAt=0;bool gotWheel=false;int wheelDirection=0;
M5Canvas frame(&M5Cardputer.Display);
bool frameReady=false;
char paintedState[256]="";

void draw() {
 if(!frameReady) return;
 auto &lcd=frame;
 const uint16_t bg=0x0862,panel=0x10c4,accent=0x5d9f,text=0xe77e,muted=0x8cd5,healthy=0x5695,amber=0xf58b;
 bool live=gotHost && uint32_t(millis()-hostUpdated)<2000;
 bool usbReady=mouse.ready();
 uint32_t seconds=live?uint32_t(millis()-hostSessionAt)/1000:0;
 char uptime[16];
 if(live) snprintf(uptime,sizeof(uptime),"%02lu:%02lu:%02lu",(unsigned long)(seconds/3600),(unsigned long)((seconds/60)%60),(unsigned long)(seconds%60));
 else snprintf(uptime,sizeof(uptime),"--:--:--");
 bool wheelActive=gotWheel && uint32_t(millis()-wheelAt)<300;
 bool arrowLive=live && gotObserved && (observed.dx || observed.dy) && uint32_t(millis()-observedAt)<750;
 const char *lastAction=(gotObserved && uint32_t(millis()-observedAt)<1500)?lastObserved:lastCommand;
 char state[256];
 snprintf(state,sizeof(state),"%d|%d|%lu|%u|%d|%d|%d|%d|%d|%s|%s|%lu|%s",usbReady,bridge.armed(),(unsigned long)bridge.remainingSeconds(),bridge.buttons(),gotHost,live,hostX,hostY,hostDisplay,hostApp,lastAction,(unsigned long)commands,uptime);
 // Include live physical button and motion state in the frame cache.
 size_t used=strlen(state);snprintf(state+used,sizeof(state)-used,"|%d|%d|%d|%d|%d|%d|%d|%d",observed.buttons,observed.dx,observed.dy,arrowLive,viewportWidth,viewportHeight,wheelActive,wheelDirection);
 if(!strcmp(state,paintedState)) return;
 lcd.fillScreen(bg);lcd.setFont(&fonts::Font0);lcd.setTextSize(1);
 lcd.fillRect(0,0,240,16,panel);lcd.setTextColor(accent,panel);lcd.setCursor(7,4);lcd.print("HID EMU");
 lcd.setTextColor(muted,panel);lcd.setCursor(202,4);lcd.print(kVersion);
 lcd.fillCircle(9,24,2,usbReady?healthy:amber);lcd.setTextColor(muted,bg);lcd.setCursor(17,20);lcd.print(usbReady?"USB READY":"USB WAIT");
 lcd.setTextColor(bridge.armed()?amber:healthy,bg);lcd.setCursor(135,20);
 if(bridge.armed()) lcd.printf("ARMED %2lus",(unsigned long)bridge.remainingSeconds());else lcd.print("INPUT SAFE");
 lcd.fillRoundRect(5,33,230,40,4,panel);lcd.fillRect(5,37,2,32,accent);
 lcd.setTextColor(accent,panel);lcd.setCursor(13,37);lcd.print("X");lcd.setCursor(13,57);lcd.print("Y");
 lcd.setTextColor(live?text:muted,panel);lcd.setTextSize(2);lcd.setCursor(31,35);
 if(gotHost) lcd.printf("%d",hostX);else lcd.print("--");
 lcd.setCursor(31,55);if(gotHost) lcd.printf("%d",hostY);else lcd.print("--");
 // Small mouse diagram: physical L/R/M states; separate from bridge-held buttons.
 bool physicalLive=live && gotObserved;
 int physical=physicalLive?observed.buttons:0;
 lcd.drawRoundRect(202,38,21,29,6,muted);
 if(physical&1) lcd.fillRoundRect(204,40,8,11,2,accent);
 if(physical&2) lcd.fillRoundRect(213,40,8,11,2,accent);
 lcd.drawFastVLine(212,39,12,muted);lcd.drawFastHLine(203,52,19,muted);
 lcd.fillRoundRect(210,43,5,7,2,wheelActive?(wheelDirection>0?healthy:(wheelDirection<0?amber:accent)):((physical&4)?accent:muted));
 int plotW=32,plotH=32;
 if(viewportWidth>=viewportHeight) plotH=max(1,32*viewportHeight/viewportWidth);
 else plotW=max(1,32*viewportWidth/viewportHeight);
 int left=174-plotW/2,top=53-plotH/2;
 lcd.drawRect(left,top,plotW,plotH,0x3aef);
 lcd.drawFastHLine(left,53,plotW,0x2147);lcd.drawFastVLine(174,top,plotH,0x2147);
 float halfW=max(1,plotW/2-3),halfH=max(1,plotH/2-3);
 if(live && trailCount) {
  float scale=1.0f;
  for(int i=0;i<trailCount;++i) scale=max(scale,max(abs(trailX[i]-hostX)/halfW,abs(trailY[i]-hostY)/halfH));
  scale*=1.15f;
  int previousX=174,previousY=53;
  for(int i=0;i<trailCount;++i) {
   int tx=174+int((trailX[i]-hostX)/scale),ty=53+int((trailY[i]-hostY)/scale);
   if(i) lcd.drawLine(previousX,previousY,tx,ty,muted);
   lcd.fillCircle(tx,ty,i==trailCount-1?2:1,i==trailCount-1?accent:muted);
   previousX=tx;previousY=ty;
  }
 }
 if(arrowLive) {
  float scale=max(abs(observed.dx)/halfW,abs(observed.dy)/halfH);
  int ax=int(observed.dx/scale),ay=int(observed.dy/scale);
  int tipX=174+ax,tipY=53+ay;
  lcd.drawLine(174-ax/2,53-ay/2,tipX,tipY,accent);
  int backX=tipX-ax/2,backY=tipY-ay/2;
  lcd.fillTriangle(tipX,tipY,backX-ay/3,backY+ax/3,backX+ay/3,backY-ax/3,accent);
 } else lcd.fillCircle(174,53,2,muted);
 lcd.setTextSize(1);lcd.setTextColor(accent,bg);lcd.setCursor(7,79);lcd.print("APP");
 lcd.setTextColor(text,bg);lcd.setCursor(33,79);lcd.printf("%.32s",hostApp);
 lcd.setTextColor(muted,bg);lcd.setCursor(7,92);lcd.print("LAST");lcd.setCursor(39,92);lcd.printf("%.31s",lastAction);
 lcd.drawFastHLine(7,104,226,0x2147);
 lcd.setTextColor(live?healthy:amber,bg);lcd.setCursor(7,109);lcd.print(live?"LIVE":"LOST");
 lcd.setTextColor(text,bg);lcd.setCursor(42,109);lcd.print(uptime);
 lcd.setTextColor(muted,bg);lcd.setCursor(150,109);lcd.printf("D%d B%u #%lu",hostDisplay,bridge.buttons(),(unsigned long)commands);
 lcd.setTextColor(muted,bg);lcd.setCursor(7,125);lcd.print("S/G0 STOP              ESC HOME");
 frame.pushSprite(0,0);snprintf(paintedState,sizeof(paintedState),"%s",state);
}
void returnToLauncher() {
 bridge.stop();
 const esp_partition_t *launcher=esp_partition_find_first(ESP_PARTITION_TYPE_APP,ESP_PARTITION_SUBTYPE_APP_TEST,nullptr);
 if(!launcher || launcher->address!=0x10000 || esp_ota_get_running_partition()->address==launcher->address) {
  snprintf(lastCommand,sizeof(lastCommand),"Launcher partition not found");draw();return;
 }
 Preferences settings;
 if(settings.begin("launcher",true)) {
  bool blocked=settings.getBool("DDLB",false) || settings.getInt("LauncherOnKey",-1)>=0;
  settings.end();
  if(blocked) {snprintf(lastCommand,sizeof(lastCommand),"Check Launcher wake settings");draw();return;}
 }
 snprintf(lastCommand,sizeof(lastCommand),"Hold Enter now for Launcher");draw();delay(1300);
 // M5Launcher 3.0.0 keyboot enters its test partition on deep-sleep wake
 // with default DDLB=false and LauncherOnKey=-1 settings. Preserve settings.
 esp_sleep_enable_timer_wakeup(100000);esp_deep_sleep_start();
}
void setup() {
 // Keep the existing app partition; rename only this app's Launcher menu entry.
 const esp_partition_t *running=esp_ota_get_running_partition();
 if(running) {
  Preferences registry;
  if(registry.begin("l_apps",false)) {
   String name=registry.getString(running->label,"");
   if(name=="MouseBridge") registry.putString(running->label,"HID Emu");
   registry.end();
  }
 }
 auto cfg=M5.config();M5Cardputer.begin(cfg,true);
 M5Cardputer.Display.setRotation(0);
 if(M5Cardputer.Display.width()<M5Cardputer.Display.height()) M5Cardputer.Display.setRotation(1);
 M5Cardputer.Display.setBrightness(100);
 frame.setColorDepth(16);
 frameReady=frame.createSprite(M5Cardputer.Display.width(),M5Cardputer.Display.height())!=nullptr;
 if(!frameReady) {
  M5Cardputer.Display.fillScreen(TFT_BLACK);M5Cardputer.Display.setFont(&fonts::Font0);
  M5Cardputer.Display.setTextSize(1);M5Cardputer.Display.setTextColor(TFT_WHITE,TFT_BLACK);
  M5Cardputer.Display.setCursor(5,5);M5Cardputer.Display.print("Display buffer unavailable");
 }
 USB.productName("HID Emu Cardputer ADV");Serial.begin(115200);
 mouse.begin();USB.begin();draw();
}
void loop() {
 bridge.service();M5Cardputer.update();
 if(M5Cardputer.BtnA.wasPressed() || (M5Cardputer.Keyboard.isChange() && M5Cardputer.Keyboard.isPressed() &&
    (M5Cardputer.Keyboard.isKeyPressed('s') || M5Cardputer.Keyboard.isKeyPressed('S')))) {
  bridge.stop();snprintf(lastCommand,sizeof(lastCommand),"STOP (physical button)");draw();
 }
 if(M5Cardputer.Keyboard.isKeyPressed('`') || M5Cardputer.Keyboard.isKeyPressed(27)) returnToLauncher();
 for(int count=0;count<128 && Serial.available();++count) {
  char c=Serial.read();
  if(c=='\n' || c=='\r') {
   if(length || discard) {
    line[length]=0;char response[100];
    const char *result;
    if(!discard && !strcmp(line,"registry")) {
     Preferences registry;String name="";
     if(registry.begin("l_apps",true)) {name=registry.getString(esp_ota_get_running_partition()->label,"");registry.end();}
     snprintf(response,sizeof(response),"OK APPNAME=%s",name.c_str());result=response;
    } else if(!discard && !strcmp(line,"info")) {
     snprintf(response,sizeof(response),"OK BRIDGE=%s",kVersion);result=response;
    } else if(!discard && !strncmp(line,"observe input ",14)) {
     ObservedInput input;
     if(parseObservedInput(line+14,input)) {
      observed=input;observedAt=millis();gotObserved=true;
      if(input.kind==5 && (input.wx || input.wy)) {wheelAt=millis();gotWheel=true;wheelDirection=abs(input.wy)>=abs(input.wx)?(input.wy>0?1:-1):0;}
      const char *buttonNames[]={"LEFT","RIGHT","MIDDLE","BACK","FORWARD"};
      const char *button=buttonNames[input.button];
      switch(input.kind) {
       case 1: snprintf(lastObserved,sizeof(lastObserved),"MOVING");break;
       case 2: snprintf(lastObserved,sizeof(lastObserved),"PRESS %s",button);break;
       case 3: snprintf(lastObserved,sizeof(lastObserved),"CLICK %s",button);break;
       case 4: snprintf(lastObserved,sizeof(lastObserved),"DRAG %s",button);break;
       case 5: {
        const char *direction=abs(input.wy)>=abs(input.wx)?(input.wy>0?"UP":"DOWN"):(input.wx>0?"LEFT":"RIGHT");
        if(input.wx||input.wy) snprintf(lastObserved,sizeof(lastObserved),"SCROLL %s",direction);break;
       }
       case 6: snprintf(lastObserved,sizeof(lastObserved),"DOUBLE CLICK %s",button);break;
       default: break;
      }
      result="OK OBSERVE";
     } else result="ERR invalid mouse observation";
    } else if(!discard && !strncmp(line,"viewport ",9)) {
     int width,height;
     if(parseViewport(line+9,width,height)) {viewportWidth=width;viewportHeight=height;result="OK VIEWPORT";}
     else result="ERR invalid viewport";
    } else if(!discard && !strncmp(line,"host ",5)) {
     HostInfo h;
     if(parseHost(line+5,h)) {
      if(!gotHost || uint32_t(millis()-hostUpdated)>=2000) hostSessionAt=millis();
      if(!trailCount || trailX[trailCount-1]!=h.x || trailY[trailCount-1]!=h.y) {
       if(trailCount==10) {for(int i=0;i<9;++i) {trailX[i]=trailX[i+1];trailY[i]=trailY[i+1];}trailCount=9;}
       trailX[trailCount]=h.x;trailY[trailCount]=h.y;trailCount++;
      }
      hostX=h.x;hostY=h.y;hostDisplay=h.display;snprintf(hostApp,sizeof(hostApp),"%s",h.app);
      hostUpdated=millis();gotHost=true;result="OK HOST";
     } else result="ERR invalid host telemetry";
    } else {
     if(strcmp(line,"status") && strcmp(line,"ping")) {
      snprintf(lastCommand,sizeof(lastCommand),"%s",line);commands++;
     }
     result=discard?"ERR line too long or non-ASCII":bridge.command(line,response,sizeof(response));
    }
    Serial.println(result);
    bool quit=!strcmp(result,"OK QUIT");length=0;discard=false;
    if(quit) {Serial.flush();returnToLauncher();}
   }
  } else if((c<32 && c!='\t') || c>126 || length>=96) discard=true;
  else if(!discard) line[length++]=c;
 }
 static uint32_t painted=0;
 if(uint32_t(millis()-painted)>50) {draw();painted=millis();}
 delay(2);
}
