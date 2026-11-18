#include <furi.h>
#include <furi_hal.h>
#include <gui/gui.h>
#include <input/input.h>
#include <rpc/rpc_app.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "dashboard_protocol.h"
#include "spectrum_feedback.h"

typedef struct {
    RpcAppSystem* rpc;
    FuriMutex* mutex;
    FuriMessageQueue* commands;
    volatile bool stop;
    bool armed;
    ViewPort* viewport;
    bool ui_armed;
    bool ui_usb;
    bool ui_busy;
    bool ui_error;
    uint32_t ui_completed;
    uint32_t ui_elapsed;
    char ui_command[24];
    bool ui_position_valid;
    int ui_x, ui_y;
    uint32_t ui_position_tick;
    uint32_t ui_refresh_tick;
    uint32_t armed_tick,session_tick,action_tick,wheel_tick;
    int width,height,physical,mouse_button,kind,mx,my,wheel_direction;
    int trail_x[10],trail_y[10],trail_count;
    char app[23],action[24];
    SpectrumFeedback feedback;int legacy_event;
} Bridge;

typedef struct { char text[96]; } Command;

// Copy a small synchronized snapshot; never hold the RPC lock while painting.
static void draw(Canvas* canvas, void* context) {
    Bridge* b = context;
    furi_mutex_acquire(b->mutex,FuriWaitForever);
    Bridge ui=*b;
    furi_mutex_release(b->mutex);
    uint32_t now=furi_get_tick();
    bool live=ui.ui_position_valid && now-ui.ui_position_tick<2000;
    char line[48];
    canvas_set_font(canvas,FontSecondary);
    canvas_draw_str(canvas,2,8,"HID EMU");
    canvas_draw_str(canvas,99,8,ui.ui_armed ? "ARM":"SAFE");
    canvas_draw_line(canvas,1,11,126,11);
    snprintf(line,sizeof(line),"X %d",ui.ui_x);canvas_draw_str(canvas,3,22,ui.ui_position_valid?line:"X --");
    snprintf(line,sizeof(line),"Y %d",ui.ui_y);canvas_draw_str(canvas,3,32,ui.ui_position_valid?line:"Y --");
    int w=26,h=18;
    if(ui.width>0 && ui.height>0) {
        if(ui.width*18>ui.height*26) h=MAX(1,26*ui.height/ui.width);
        else w=MAX(1,18*ui.width/ui.height);
    }
    int left=111-w/2,top=23-h/2;
    canvas_draw_frame(canvas,left,top,w,h);
    canvas_draw_dot(canvas,111,23);
    if(live && ui.trail_count) {
        float scale=1,half_w=MAX(1,w/2-2),half_h=MAX(1,h/2-2);
        for(int i=0;i<ui.trail_count;i++) scale=MAX(scale,MAX(abs(ui.trail_x[i]-ui.ui_x)/half_w,abs(ui.trail_y[i]-ui.ui_y)/half_h));
        scale*=1.15f;int px=111,py=23;
        for(int i=0;i<ui.trail_count;i++) {
            int x=111+(ui.trail_x[i]-ui.ui_x)/scale,y=23+(ui.trail_y[i]-ui.ui_y)/scale;
            if(i) canvas_draw_line(canvas,px,py,x,y);
            canvas_draw_dot(canvas,x,y);px=x;py=y;
        }
    }
    if(live && now-ui.action_tick<750 && (ui.mx || ui.my)) {
        float scale=MAX(abs(ui.mx)/(float)MAX(1,w/2-2),abs(ui.my)/(float)MAX(1,h/2-2));
        int ax=ui.mx/scale,ay=ui.my/scale;
        canvas_draw_line(canvas,111,23,111+ax,23+ay);
        canvas_draw_line(canvas,111+ax,23+ay,111+ax-ax/2-ay/3,23+ay-ay/2+ax/3);
        canvas_draw_line(canvas,111+ax,23+ay,111+ax-ax/2+ay/3,23+ay-ay/2-ax/3);
    }
    if(live && MIN(w,h)>=8) {
        uint8_t strength=spectrum_strength(&ui.feedback,now);
        int direction=strength>96?ui.feedback.direction:(now-ui.feedback.motion_at<300?ui.feedback.motion_direction:SpectrumNone);
        int radius=MAX(2,MIN(4,MIN(w,h)/2-2));
        canvas_draw_circle(canvas,111,23,radius);
        // The same spatial anchors remain readable on a monochrome display.
        if(direction==SpectrumUp) canvas_draw_line(canvas,108,23-radius-1,114,23-radius-1);
        if(direction==SpectrumRight) canvas_draw_line(canvas,111+radius+1,20,111+radius+1,26);
        if(direction==SpectrumDown) canvas_draw_line(canvas,108,23+radius+1,114,23+radius+1);
        if(direction==SpectrumLeft) canvas_draw_line(canvas,111-radius-1,20,111-radius-1,26);
        if(strength>96 && ui.feedback.scroll) canvas_draw_line(canvas,111,21,111,25);
    }
    snprintf(line,sizeof(line),"APP %.21s",ui.app[0]?ui.app:"Waiting for Mac");canvas_draw_str(canvas,3,42,line);
    const char* action=now-ui.action_tick<1500 && ui.action[0]?ui.action:ui.ui_command;
    snprintf(line,sizeof(line),"%.23s",action[0]?action:"Waiting for host");canvas_draw_str(canvas,3,51,line);
    canvas_draw_line(canvas,1,53,126,53);
    uint32_t sec=live?(now-ui.session_tick)/1000:0;
    snprintf(line,sizeof(line),"%s %s %02lu:%02lu",live?"BLE":"OLD",ui.ui_usb?"USB":"---",(unsigned long)(sec/60),(unsigned long)(sec%60));
    canvas_draw_str(canvas,2,63,line);
    for(int i=0;i<3;i++) {
        int x=86+i*14;bool lit=live && ((ui.physical&(1<<i)) || (i==2 && now-ui.wheel_tick<300));
        if(lit) {canvas_draw_box(canvas,x,55,12,9);canvas_set_color(canvas,ColorWhite);}
        char label[2]={(i==2 && live && now-ui.wheel_tick<300)?(ui.wheel_direction==1?'^':(ui.wheel_direction==-1?'v':(ui.wheel_direction==2?'<':'>'))):"LRM"[i],0};canvas_draw_str(canvas,x+3,63,label);canvas_set_color(canvas,ColorBlack);
    }
}

static void dashboard(Bridge* b, const char* command, bool busy, uint32_t elapsed) {
    furi_mutex_acquire(b->mutex,FuriWaitForever);
    b->ui_armed=b->armed;b->ui_usb=furi_hal_hid_is_connected();b->ui_busy=busy;
    if(command) snprintf(b->ui_command,sizeof(b->ui_command),"%.23s",command);
    if(command && !busy) {b->ui_completed++;b->ui_elapsed=elapsed;}
    furi_mutex_release(b->mutex);
    view_port_update(b->viewport);
}
static void input(InputEvent* event, void* context) {
    Bridge* b = context;
    if(event->key == InputKeyBack && event->type == InputTypePress) b->stop = true;
}
static void rpc_event(const RpcAppSystemEvent* event, void* context) {
    Bridge* b = context;
    furi_mutex_acquire(b->mutex, FuriWaitForever);
    if(event->type == RpcAppEventTypeSessionClose) {
        b->stop = true;
        rpc_system_app_set_callback(b->rpc, NULL, NULL);
        b->rpc = NULL;
    } else if(event->type == RpcAppEventTypeAppExit) {
        b->stop = true;
        rpc_system_app_confirm(b->rpc, true);
    } else if(event->type == RpcAppEventTypeDataExchange) {
        Command cmd = {0};
        size_t n = event->data.bytes.size;
        bool valid = event->data.type == RpcAppSystemEventDataTypeBytes && n > 0 && n < sizeof(cmd.text) && !memchr(event->data.bytes.ptr, 0, n);
        if(valid) {
            memcpy(cmd.text, event->data.bytes.ptr, n);
            if(!strcmp(cmd.text, "STOP") || !strcmp(cmd.text, "RELEASE")) {
                b->stop = true;
            }
            valid = furi_message_queue_put(b->commands, &cmd, 0) == FuriStatusOk;
        }
        rpc_system_app_confirm(b->rpc, valid);
    } else {
        rpc_system_app_confirm(b->rpc, false);
    }
    furi_mutex_release(b->mutex);
}
static void reply(Bridge* b, const char* message) {
    furi_mutex_acquire(b->mutex, FuriWaitForever);
    if(strcmp(message,"POSITION")) b->ui_error = !strncmp(message,"ERROR",5) || !strcmp(message,"STOPPED");
    if(b->rpc) rpc_system_app_exchange_data(b->rpc, (const uint8_t*)message, strlen(message));
    furi_mutex_release(b->mutex);
}
static bool wait_safe(Bridge* b, uint32_t ms) {
    for(uint32_t t = 0; t < ms && !b->stop; t += 10) {
        furi_delay_ms(MIN(10U, ms-t));
        if(furi_get_tick()-b->ui_refresh_tick>=250) {
            b->ui_refresh_tick=furi_get_tick();view_port_update(b->viewport);
        }
    }
    return !b->stop;
}
// Absolute logical screen points from the host; never emits a USB report.
static void position(Bridge* b,int x,int y) {
    furi_mutex_acquire(b->mutex,FuriWaitForever);
    if(!b->ui_position_valid || furi_get_tick()-b->ui_position_tick>=2000) b->session_tick=furi_get_tick();
    if(!b->trail_count || b->trail_x[b->trail_count-1]!=x || b->trail_y[b->trail_count-1]!=y) {
        if(b->trail_count==10) {memmove(b->trail_x,b->trail_x+1,9*sizeof(int));memmove(b->trail_y,b->trail_y+1,9*sizeof(int));b->trail_count=9;}
        b->trail_x[b->trail_count]=x;b->trail_y[b->trail_count++]=y;
    }
    b->ui_x=x;b->ui_y=y;b->ui_position_valid=true;b->ui_position_tick=furi_get_tick();
    b->ui_usb=furi_hal_hid_is_connected();b->ui_armed=b->armed;
    furi_mutex_release(b->mutex);
    view_port_update(b->viewport);
}
static void execute(Bridge* b, const char* cmd) {
    int v[8];const char* name=NULL;
    if(!strcmp(cmd,"INFO")) {reply(b,"OK BRIDGE=1.2.0");return;}
    if(!strcmp(cmd,"STATUS")) {
        char line[64];snprintf(line,sizeof(line),"OK HID=%d ARMED=%d BUTTONS=0",furi_hal_hid_is_connected(),b->armed);reply(b,line);return;
    }
    if(!strcmp(cmd,"SAFE")) {
        b->armed=false;
        bool released=furi_hal_hid_mouse_release(HID_MOUSE_BTN_LEFT|HID_MOUSE_BTN_RIGHT|HID_MOUSE_BTN_WHEEL);
        dashboard(b,NULL,false,0);reply(b,released?"SAFE":"ERROR: release failed");return;
    }
    if(!strncmp(cmd,"viewport ",9)) {
        if(!dashboard_numbers(cmd+9,v,2,NULL) || v[0]<1 || v[1]<1 || v[0]>32768 || v[1]>32768) {reply(b,"ERROR: viewport");return;}
        furi_mutex_acquire(b->mutex,FuriWaitForever);b->width=v[0];b->height=v[1];furi_mutex_release(b->mutex);
        reply(b,"VIEWPORT");return;
    }
    if(!strncmp(cmd,"host ",5)) {
        if(!dashboard_numbers(cmd+5,v,3,&name) || v[2]<1 || v[2]>32) {reply(b,"ERROR: host");return;}
        furi_mutex_acquire(b->mutex,FuriWaitForever);snprintf(b->app,sizeof(b->app),"%.22s",name);furi_mutex_release(b->mutex);
        position(b,v[0],v[1]);reply(b,"HOST");return;
    }
    if(!strncmp(cmd,"observe input ",14) || !strncmp(cmd,"observe event ",14)) {
        bool sequenced=!strncmp(cmd,"observe event ",14);int sequence;
        if(!dashboard_numbers(cmd+14,v,sequenced?8:7,NULL)) {reply(b,"ERROR: observation");return;}
        if(sequenced) {sequence=v[0];if(sequence<0 || sequence>99999) {reply(b,"ERROR: observation");return;}memmove(v,v+1,7*sizeof(int));}
        else sequence=++b->legacy_event%100000;
        if(v[0]<0 || v[0]>6 || v[1]<0 || v[1]>31 || v[2]<0 || v[2]>4) {reply(b,"ERROR: observation");return;}
        const char* buttons[]={"LEFT","RIGHT","MIDDLE","BACK","FORWARD"};
        furi_mutex_acquire(b->mutex,FuriWaitForever);
        spectrum_observe(&b->feedback,sequence,v[0],v[2],v[3],v[4],v[5],v[6],furi_get_tick());
        b->kind=v[0];b->physical=v[1];b->mouse_button=v[2];b->mx=v[3];b->my=v[4];b->action_tick=furi_get_tick();
        const char* button=buttons[v[2]];
        switch(v[0]) {
         case 1:snprintf(b->action,sizeof(b->action),"MOVING");break;
         case 2:snprintf(b->action,sizeof(b->action),"PRESS %s",button);break;
         case 3:snprintf(b->action,sizeof(b->action),"CLICK %s",button);break;
         case 4:snprintf(b->action,sizeof(b->action),"DRAG %s",button);break;
         case 5:if(v[5] || v[6]) {
             b->wheel_tick=furi_get_tick();b->wheel_direction=abs(v[6])>=abs(v[5])?(v[6]>0?1:-1):(v[5]>0?2:-2);
             snprintf(b->action,sizeof(b->action),"SCROLL %s",abs(v[6])>=abs(v[5])?(v[6]>0?"UP ^":"DOWN v"):(v[5]>0?"LEFT <":"RIGHT >"));
         }break;
         case 6:snprintf(b->action,sizeof(b->action),"DOUBLE CLICK %s",button);break;
        }
        furi_mutex_release(b->mutex);view_port_update(b->viewport);reply(b,"OBSERVE");return;
    }
    int x=0, y=0, duration=0, button=0, count=0;
    if(!strncmp(cmd,"POS ",4)) {
        if(!dashboard_numbers(cmd+4,v,2,NULL) || v[0]<-99999 || v[0]>99999 || v[1]<-99999 || v[1]>99999) {reply(b,"ERROR: position");return;}
        position(b,v[0],v[1]);reply(b,"POSITION");return;
    }
    if(!strcmp(cmd, "PING")) { reply(b, "PONG"); return; }
    if(!strcmp(cmd, "ARM")) {
        if(!furi_hal_hid_is_connected()) {reply(b,"ERROR: USB unavailable");return;}
        b->armed = true;b->armed_tick=furi_get_tick();
        view_port_update(b->viewport);
        reply(b, "ARMED"); return;
    }
    if(!b->armed || !furi_hal_hid_is_connected()) { reply(b, "ERROR: not armed or USB unavailable"); return; }
    bool okay = true;
    if(!strncmp(cmd,"MOVE ",5) && dashboard_numbers(cmd+5,v,2,NULL) && v[0]>=-127 && v[0]<=127 && v[1]>=-127 && v[1]<=127) {
        x=v[0];y=v[1];
        okay = furi_hal_hid_mouse_move(x,y);
    } else if(!strncmp(cmd,"SCROLL ",7) && dashboard_numbers(cmd+7,v,1,NULL) && v[0]>=-127 && v[0]<=127) {
        x=v[0];
        okay = furi_hal_hid_mouse_scroll(x);
    } else if(!strncmp(cmd,"CLICK ",6) && dashboard_numbers(cmd+6,v,2,NULL) && (v[0]==1 || v[0]==2 || v[0]==4) && v[1]>=1 && v[1]<=2) {
        button=v[0];count=v[1];
        for(int i=0;i<count && !b->stop;i++) {
            okay &= furi_hal_hid_mouse_press(button);
            wait_safe(b,40);
            okay &= furi_hal_hid_mouse_release(button);
            if(i+1<count) wait_safe(b,80);
        }
    } else if(!strncmp(cmd,"DRAG ",5) && dashboard_numbers(cmd+5,v,3,NULL) && v[0]>=-2000 && v[0]<=2000 && v[1]>=-2000 && v[1]<=2000 && v[2]>=100 && v[2]<=3000) {
        x=v[0];y=v[1];duration=v[2];
        int steps = MAX(duration/10, MAX((abs(x)+126)/127,(abs(y)+126)/127));
        int previous_x=0,previous_y=0;
        okay = furi_hal_hid_mouse_press(HID_MOUSE_BTN_LEFT);
        if(okay && wait_safe(b,80)) {
            for(int i=1;i<=steps && !b->stop;i++) {
                int next_x=x*i/steps, next_y=y*i/steps;
                if(!furi_hal_hid_mouse_move(next_x-previous_x,next_y-previous_y)) { okay = false; break; }
                previous_x=next_x; previous_y=next_y;
                wait_safe(b,MAX(1,duration/steps));
            }
        }
        okay &= furi_hal_hid_mouse_release(HID_MOUSE_BTN_LEFT);
    } else { reply(b,"ERROR: invalid command"); return; }
    reply(b, b->stop ? "STOPPED" : (okay ? "DONE" : "ERROR: USB report failed"));
}
// HID profile creation precedes host enumeration. Do not announce Ready until
// a neutral report can be submitted; retries also tolerate endpoint setup timing.
static bool prepare_usb(Bridge* b) {
    furi_delay_ms(250);
    for(unsigned attempt=0;attempt<30 && !b->stop;attempt++) {
        if(furi_hal_hid_is_connected() && furi_hal_hid_mouse_release(
               HID_MOUSE_BTN_LEFT|HID_MOUSE_BTN_RIGHT|HID_MOUSE_BTN_WHEEL)) {
            furi_delay_ms(50);
            return true;
        }
        furi_delay_ms(100);
    }
    return false;
}
int32_t ble_usb_mouse_app(void* args) {
    uint32_t rpc_address=0;
    if(!args || sscanf(args,"RPC %lx", &rpc_address)!=1) return -1;
    Bridge* b=malloc(sizeof(Bridge));
    memset(b,0,sizeof(Bridge));
    b->rpc=(RpcAppSystem*)rpc_address;
    b->mutex=furi_mutex_alloc(FuriMutexTypeNormal);
    b->commands=furi_message_queue_alloc(8,sizeof(Command));
    b->viewport=view_port_alloc();
    view_port_draw_callback_set(b->viewport,draw,b);
    view_port_input_callback_set(b->viewport,input,b);
    Gui* gui=furi_record_open(RECORD_GUI);
    gui_add_view_port(gui,b->viewport,GuiLayerFullscreen);
    FuriHalUsbInterface* previous_usb=furi_hal_usb_get_config();
    rpc_system_app_set_callback(b->rpc,rpc_event,b);
    if(!furi_hal_usb_set_config(&usb_hid,NULL) || !prepare_usb(b)) b->stop=true;
    if(!b->stop) rpc_system_app_send_started(b->rpc);
    while(!b->stop) {
        if(b->armed && (furi_get_tick()-b->armed_tick>=60000 || !furi_hal_hid_is_connected())) {
            b->armed=false;furi_hal_hid_mouse_release(HID_MOUSE_BTN_LEFT|HID_MOUSE_BTN_RIGHT|HID_MOUSE_BTN_WHEEL);
        }
        Command cmd;
        if(furi_message_queue_get(b->commands,&cmd,250)==FuriStatusOk) {
            if(!strncmp(cmd.text,"POS ",4) || !strncmp(cmd.text,"host ",5) || !strncmp(cmd.text,"viewport ",9) || !strncmp(cmd.text,"observe ",8) || !strcmp(cmd.text,"STATUS") || !strcmp(cmd.text,"INFO")) {execute(b,cmd.text);continue;}
            dashboard(b,cmd.text,true,0);
            uint32_t start=furi_get_tick();
            execute(b,cmd.text);
            dashboard(b,cmd.text,false,furi_get_tick()-start);
        } else {dashboard(b,NULL,false,0);}
    }
    furi_hal_hid_mouse_release(HID_MOUSE_BTN_LEFT|HID_MOUSE_BTN_RIGHT|HID_MOUSE_BTN_WHEEL);
    furi_delay_ms(30);
    furi_mutex_acquire(b->mutex,FuriWaitForever);
    if(b->rpc) {
        rpc_system_app_set_callback(b->rpc,NULL,NULL);
        rpc_system_app_send_exited(b->rpc);
    }
    furi_mutex_release(b->mutex);
    furi_hal_usb_set_config(previous_usb,NULL);
    gui_remove_view_port(gui,b->viewport);
    view_port_free(b->viewport);
    furi_record_close(RECORD_GUI);
    furi_message_queue_free(b->commands);
    furi_mutex_free(b->mutex);
    free(b);
    return 0;
}
