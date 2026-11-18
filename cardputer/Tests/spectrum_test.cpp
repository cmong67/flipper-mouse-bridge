#include "../Firmware/src/spectrum_feedback.h"
#include <cassert>
int main() {
 SpectrumFeedback s={};spectrum_observe(&s,1,6,1,0,0,0,0,1000);
 assert(s.direction==SpectrumRight&&s.double_click);
 assert(spectrum_strength(&s,1375)==255&&spectrum_strength(&s,1800)==0&&spectrum_strength(&s,2225)==255&&spectrum_strength(&s,2700)==0);
 spectrum_observe(&s,1,6,1,10,0,0,0,1400);assert(s.started==1000&&s.motion_direction==SpectrumRight);
 spectrum_observe(&s,2,5,2,0,0,0,10,3000);assert(s.direction==SpectrumUp);
 spectrum_observe(&s,3,5,2,0,0,0,10,3100);assert(s.started==3000&&spectrum_strength(&s,3200)>0);
 assert(spectrum_strength(&s,3930)==0);
 spectrum_observe(&s,4,5,2,0,0,0,-10,4000);assert(s.direction==SpectrumDown);
 spectrum_observe(&s,5,3,0,-10,-10,0,0,0xfffffff0);assert(s.motion_direction==SpectrumUp);assert(spectrum_strength(&s,30)>0);
 assert(spectrum_rgb(SpectrumUp)==0xffc961&&spectrum_rgb(SpectrumLeft)==0xc799ff);
 for(unsigned q=0;q<4;q++)assert(spectrum_idle_rgb(q,333)==spectrum_idle_rgb(q,16333));
}
