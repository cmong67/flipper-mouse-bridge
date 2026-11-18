#pragma once
#include <stdint.h>
#include <stdbool.h>
// Direction indices are screen-relative: top, right, bottom, left. Host Y is down.
enum {SpectrumNone=0,SpectrumUp=1,SpectrumRight=2,SpectrumDown=3,SpectrumLeft=4,SpectrumMiddle=5};
typedef struct {
    bool valid,scroll,double_click;
    int sequence,direction;
    uint32_t started,last_event,motion_at;
    int motion_direction;
} SpectrumFeedback;
static inline int spectrum_abs(int value) {return value<0?-value:value;}
static inline int spectrum_direction(int x,int y) {
    if(!x && !y) return SpectrumNone;
    return spectrum_abs(y)>=spectrum_abs(x)?(y<0?SpectrumUp:SpectrumDown):(x>0?SpectrumRight:SpectrumLeft);
}
static inline void spectrum_observe(SpectrumFeedback* s,int sequence,int kind,int button,int dx,int dy,int wx,int wy,uint32_t now) {
    if(dx || dy) {s->motion_direction=spectrum_direction(dx,dy);s->motion_at=now;}
    // Event IDs prevent a repeated host snapshot from restarting a click pulse.
    if(s->valid && sequence==s->sequence) return;
    s->valid=true;s->sequence=sequence;
    if(kind==5 && (wx || wy)) {
        int direction=spectrum_abs(wy)>=spectrum_abs(wx)?(wy>0?SpectrumUp:SpectrumDown):(wx>0?SpectrumLeft:SpectrumRight);
        if(!s->scroll || s->direction!=direction || (uint32_t)(now-s->last_event)>250) s->started=now;
        s->scroll=true;s->direction=direction;s->last_event=now;s->double_click=false;
    } else if(kind==2 || kind==3 || kind==6) {
        s->scroll=false;s->direction=button==0?SpectrumLeft:(button==1?SpectrumRight:SpectrumMiddle);
        s->double_click=kind==6;s->started=now;s->last_event=now;
    }
}
static inline uint8_t spectrum_strength(const SpectrumFeedback* s,uint32_t now) {
    if(!s->valid) return 0;
    uint32_t age=now-s->started;
    if(s->scroll) {
        uint32_t since=now-s->last_event;
        if(since>=830) return 0;
        uint32_t phase=(since>180?s->last_event-s->started:age)%1500;
        uint32_t triangle=phase<750?phase:1500-phase;
        uint32_t value=90+140*triangle/750;
        return (uint8_t)(since<=180?value:value*(830-since)/650);
    }
    if(age>=(s->double_click?1700U:850U)) return 0;
    uint32_t phase=age%850;if(phase>=750) return 0;
    float x=(phase<375?phase:750-phase)/375.0f;
    return (uint8_t)(255*x*x*(3-2*x));
}
static inline uint32_t spectrum_rgb(int direction) {
    switch(direction) {
    case SpectrumUp:return 0xffc961;
    case SpectrumRight:return 0x66e8ad;
    case SpectrumDown:return 0x6eb0ff;
    case SpectrumLeft:return 0xc799ff;
    default:return 0xe9edf5;
    }
}
// Scale only the target, keeping dashboard panels and status text unchanged.
static inline uint32_t spectrum_brightness(uint32_t c,unsigned scale) {
    unsigned r=((c>>16)&255)*scale/255,g=((c>>8)&255)*scale/255,b=(c&255)*scale/255;
    return (r>255?255:r)<<16|(g>255?255:g)<<8|(b>255?255:b);
}
static inline uint16_t spectrum_565(uint32_t c) {return (uint16_t)(((c>>19)&31)<<11|((c>>10)&63)<<5|((c>>3)&31));}
static inline uint32_t spectrum_idle_rgb(unsigned quadrant,uint32_t now) {
    unsigned hue=((now%16000)*1536/16000+quadrant*384)%1536;
    unsigned sector=hue/256,part=hue%256,low=124,high=232,up=low+(high-low)*part/256,down=high-(high-low)*part/256;
    unsigned r=low,g=low,b=low;
    switch(sector) {case 0:r=high;g=up;break;case 1:r=down;g=high;break;case 2:g=high;b=up;break;case 3:g=down;b=high;break;case 4:r=up;b=high;break;default:r=high;b=down;break;}
    return r<<16|g<<8|b;
}
