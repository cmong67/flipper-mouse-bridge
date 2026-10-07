#include <furi.h>
#include <furi_hal.h>
#include <gui/gui.h>
#include <input/input.h>
#include <rpc/rpc_app.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    RpcAppSystem* rpc;
    FuriMutex* mutex;
    FuriMessageQueue* commands;
    volatile bool stop;
    bool armed;
    ViewPort* viewport;
} Bridge;

typedef struct { char text[96]; } Command;

static void draw(Canvas* canvas, void* context) {
    Bridge* b = context;
    canvas_set_font(canvas, FontPrimary);
    canvas_draw_str(canvas, 3, 12, "BLE > USB Mouse");
    canvas_set_font(canvas, FontSecondary);
    canvas_draw_str(canvas, 3, 28, b->armed ? "Mouse enabled" : "Waiting for host ARM");
    canvas_draw_str(canvas, 3, 42, "BACK: stop and release");
    canvas_draw_str(canvas, 3, 56, "USB cable + Bluetooth");
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
    if(b->rpc) rpc_system_app_exchange_data(b->rpc, (const uint8_t*)message, strlen(message));
    furi_mutex_release(b->mutex);
}
static bool wait_safe(Bridge* b, uint32_t ms) {
    for(uint32_t t = 0; t < ms && !b->stop; t += 10) furi_delay_ms(MIN(10U, ms-t));
    return !b->stop;
}
static void execute(Bridge* b, const char* cmd) {
    int x=0, y=0, duration=0, button=0, count=0;
    char tail;
    if(!strcmp(cmd, "PING")) { reply(b, "PONG"); return; }
    if(!strcmp(cmd, "ARM")) {
        b->armed = true;
        view_port_update(b->viewport);
        reply(b, "ARMED"); return;
    }
    if(!b->armed || !furi_hal_hid_is_connected()) { reply(b, "ERROR: not armed or USB unavailable"); return; }
    bool okay = true;
    if(sscanf(cmd, "MOVE %d %d %c", &x, &y, &tail)==2 && x>=-127 && x<=127 && y>=-127 && y<=127) {
        okay = furi_hal_hid_mouse_move(x,y);
    } else if(sscanf(cmd, "SCROLL %d %c", &x, &tail)==1 && x>=-127 && x<=127) {
        okay = furi_hal_hid_mouse_scroll(x);
    } else if(sscanf(cmd, "CLICK %d %d %c", &button, &count, &tail)==2 && (button==1 || button==2 || button==4) && count>=1 && count<=2) {
        for(int i=0;i<count && !b->stop;i++) {
            okay &= furi_hal_hid_mouse_press(button);
            wait_safe(b,40);
            okay &= furi_hal_hid_mouse_release(button);
            if(i+1<count) wait_safe(b,80);
        }
    } else if(sscanf(cmd, "DRAG %d %d %d %c", &x, &y, &duration, &tail)==3 && x>=-2000 && x<=2000 && y>=-2000 && y<=2000 && duration>=100 && duration<=3000) {
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
    rpc_system_app_send_started(b->rpc);
    if(!furi_hal_usb_set_config(&usb_hid,NULL)) b->stop=true;
    while(!b->stop) {
        Command cmd;
        if(furi_message_queue_get(b->commands,&cmd,50)==FuriStatusOk) execute(b,cmd.text);
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
