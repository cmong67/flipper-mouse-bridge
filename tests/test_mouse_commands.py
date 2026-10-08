from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
src=(root/'flipper_mouse/ble_usb_mouse.c').read_text()
a=src.index('static bool wait_safe(')
b=src.index('int32_t ble_usb_mouse_app(')
harness=r'''
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#define MIN(a,b) ((a)<(b)?(a):(b))
#define MAX(a,b) ((a)>(b)?(a):(b))
#define HID_MOUSE_BTN_LEFT 1
#define HID_MOUSE_BTN_RIGHT 2
#define HID_MOUSE_BTN_WHEEL 4
#define FuriWaitForever 0
typedef struct { bool stop; bool armed; void* viewport; void* mutex; bool ui_position_valid,ui_usb,ui_armed; int ui_x,ui_y; uint32_t ui_position_tick,ui_refresh_tick; } Bridge;
static Bridge bridge;
static int pressed, releases, movements, dx,dy,wheel,elapsed, stop_at,fail_at;
static char response[100];
static bool connected=true;
static void reply(Bridge* b,const char* msg) { (void)b; snprintf(response,sizeof(response),"%s",msg); }
static void view_port_update(void* v) { (void)v; }
static void furi_mutex_acquire(void* m,int t) { (void)m;(void)t; }
static void furi_mutex_release(void* m) { (void)m; }
static uint32_t furi_get_tick(void) { return elapsed; }
static bool furi_hal_hid_is_connected(void) { return connected; }
static bool furi_hal_hid_mouse_press(int button) { pressed|=button; return true; }
static bool furi_hal_hid_mouse_release(int button) { pressed&=~button; releases++; return true; }
static bool furi_hal_hid_mouse_move(int x,int y) {
    assert(x>=-127 && x<=127 && y>=-127 && y<=127);
    movements++; if(fail_at && movements==fail_at) return false;
    dx+=x;dy+=y;return true;
}
static bool furi_hal_hid_mouse_scroll(int x) { wheel+=x;return true; }
static void furi_delay_ms(uint32_t ms) { elapsed+=ms; if(stop_at && elapsed>=stop_at) bridge.stop=true; }
static void reset(void) { memset(&bridge,0,sizeof(bridge));pressed=releases=movements=dx=dy=wheel=elapsed=stop_at=fail_at=0;response[0]=0; connected=true; }
'''
tests=r'''
int main(void) {
 reset();execute(&bridge,"MOVE 10 0");assert(movements==0 && strstr(response,"not armed"));
 execute(&bridge,"POS -1440 820");assert(bridge.ui_position_valid && bridge.ui_x==-1440 && bridge.ui_y==820 && !strcmp(response,"POSITION") && !movements && !pressed && !releases);
 execute(&bridge,"POS 100000 0");assert(bridge.ui_x==-1440 && !movements && strncmp(response,"ERROR",5)==0);
 execute(&bridge,"POS 1 2 extra");assert(bridge.ui_x==-1440 && !movements && strncmp(response,"ERROR",5)==0);
 execute(&bridge,"PING");assert(!strcmp(response,"PONG"));
 execute(&bridge,"ARM");assert(bridge.armed && !strcmp(response,"ARMED"));
 execute(&bridge,"MOVE 127 -127");assert(dx==127 && dy==-127 && !strcmp(response,"DONE"));
 execute(&bridge,"MOVE 128 0");assert(movements==1 && strstr(response,"invalid"));
 execute(&bridge,"MOVE 0 0 garbage");assert(movements==1 && strstr(response,"invalid"));
 execute(&bridge,"CLICK 1 2");assert(!pressed && releases==2 && elapsed==160);
 execute(&bridge,"CLICK 8 1");assert(releases==2 && strstr(response,"invalid"));
 execute(&bridge,"SCROLL -3");assert(wheel==-3);
 reset();bridge.armed=true;execute(&bridge,"DRAG 2000 -2000 100");assert(dx==2000 && dy==-2000 && !pressed && releases==1 && !strcmp(response,"DONE"));
 reset();bridge.armed=true;stop_at=130;execute(&bridge,"DRAG 1000 0 3000");assert(!pressed && releases==1 && dx<1000 && !strcmp(response,"STOPPED"));
 reset();bridge.armed=true;fail_at=3;execute(&bridge,"DRAG 500 0 1000");assert(!pressed && releases==1 && movements==3 && strstr(response,"report failed"));
 reset();bridge.armed=true;execute(&bridge,"DRAG 0 0 3001");assert(releases==0 && strstr(response,"invalid"));
 connected=false;execute(&bridge,"CLICK 1 1");assert(!pressed && releases==0 && strstr(response,"USB unavailable"));
 puts("PASS: real command implementation - arming, bounds, double click, scroll, drag interpolation, interruption, report failure, button release");
}
'''
with tempfile.TemporaryDirectory() as tmp:
    c=Path(tmp)/'commands.c'; binary=Path(tmp)/'commands'
    c.write_text(harness+src[a:b]+tests)
    subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror',str(c),'-o',str(binary)],check=True)
    subprocess.run([str(binary)],check=True)
