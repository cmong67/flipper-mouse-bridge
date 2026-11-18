import AppKit

final class MarkerView:NSView {
    var point=NSPoint.zero
    var caption=""
    var quiet=false
    var movement=0
    var motionAt=ProcessInfo.processInfo.systemUptime
    var feedback=TargetFeedback()
    var heldButtons=0
    override var isOpaque:Bool {false}
    override func draw(_ dirtyRect:NSRect) {
        if quiet {drawQuietTarget();return}
        let p=point
        NSColor.black.withAlphaComponent(0.65).setStroke()
        let halo=NSBezierPath(ovalIn:NSRect(x:p.x-13,y:p.y-13,width:26,height:26));halo.lineWidth=5;halo.stroke()
        NSColor.systemCyan.setStroke()
        let ring=NSBezierPath(ovalIn:NSRect(x:p.x-12,y:p.y-12,width:24,height:24));ring.lineWidth=1.5;ring.stroke()
        let cross=NSBezierPath();cross.move(to:NSPoint(x:p.x-25,y:p.y));cross.line(to:NSPoint(x:p.x-7,y:p.y));cross.move(to:NSPoint(x:p.x+7,y:p.y));cross.line(to:NSPoint(x:p.x+25,y:p.y));cross.move(to:NSPoint(x:p.x,y:p.y-25));cross.line(to:NSPoint(x:p.x,y:p.y-7));cross.move(to:NSPoint(x:p.x,y:p.y+7));cross.line(to:NSPoint(x:p.x,y:p.y+25));cross.lineWidth=1.5;cross.stroke()
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.white]
        let str=caption as NSString;let size=str.size(withAttributes:attrs)
        let x=max(6,min(p.x+27,bounds.width-size.width-18))
        let y=max(6,min(p.y-37,bounds.height-size.height-12))
        NSColor.black.withAlphaComponent(0.8).setFill();NSBezierPath(roundedRect:NSRect(x:x-6,y:y-5,width:size.width+12,height:size.height+10),xRadius:5,yRadius:5).fill()
        str.draw(at:NSPoint(x:x,y:y),withAttributes:attrs)
    }
}
final class Overlay {
    var windows=[NSPanel]()
    var style="Classic" {didSet{for w in windows {if let v=w.contentView as? MarkerView {v.quiet=style=="Quiet RGB";v.needsDisplay=true}}}}
    var feedback=TargetFeedback()
    var heldButtons=0
    func action(_ action:TargetAction,double:Bool=false) {
        let time=ProcessInfo.processInfo.systemUptime
        if feedback.isScroll && feedback.action==action && time-feedback.lastEvent<0.25 {feedback.lastEvent=time}
        else {feedback=TargetFeedback(action:action,started:time,doubleClick:double,lastEvent:time)}
    }
    func setEnabled(_ enabled:Bool) {
        windows.forEach{$0.orderOut(nil)};windows=[]
        guard enabled else{return}
        for screen in NSScreen.screens {
            let w=NSPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            w.isOpaque=false;w.backgroundColor = .clear;w.hasShadow=false;w.ignoresMouseEvents=true
            w.level = .floating;w.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]
            w.hidesOnDeactivate=false;w.isReleasedWhenClosed=false;w.contentView=MarkerView(frame:NSRect(origin:.zero,size:screen.frame.size))
            if let v=w.contentView as? MarkerView {v.quiet=style=="Quiet RGB"}
            w.orderFrontRegardless();windows.append(w)
        }
    }
    func update(_ p:NSPoint,_ caption:String) {
        for w in windows {
            if let v=w.contentView as? MarkerView {
                let hidden = !w.frame.contains(p)
                if v.isHidden != hidden {v.isHidden=hidden}
                guard !hidden else {continue}
                let point=NSPoint(x:p.x-w.frame.minX,y:p.y-w.frame.minY)
                if v.point != point {
                    let dx=point.x-v.point.x,dy=point.y-v.point.y
                    v.movement=abs(dy)>=abs(dx) ? (dy>0 ? 1:2):(dx>0 ? 4:3)
                    v.motionAt=ProcessInfo.processInfo.systemUptime
                }
                v.feedback=feedback;v.heldButtons=heldButtons
                if v.point != point || v.caption != caption {v.point=point;v.caption=caption;v.needsDisplay=true}
                else if v.quiet {v.setNeedsDisplay(NSRect(x:point.x-28,y:point.y-28,width:56,height:56))}
            }
        }
    }
}
