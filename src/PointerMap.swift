import AppKit

final class PointerMap:NSView {
    var pointer:CGPoint?
    var targetBounds:CGRect?
    private var trail=[CGPoint]()
    private let trailLimit=20
    func update(_ point:CGPoint?,bounds:CGRect?) {
        guard pointer != point || targetBounds != bounds else {return}
        pointer=point;targetBounds=bounds
        if let point,point.x.isFinite,point.y.isFinite {
            if trail.last != point {
                trail.append(point)
                if trail.count>trailLimit { trail.removeFirst(trail.count-trailLimit) }
            }
        } else { trail.removeAll();pointer=nil }
        needsDisplay=true
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor(calibratedRed:0.065,green:0.09,blue:0.14,alpha:1).setFill();bounds.fill()
        let screens=NSScreen.screens.map { screen -> CGRect in
            let id=(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            return CGDisplayBounds(id)
        }
        let desktop=screens.reduce(CGRect.null){$0.union($1)}
        guard !desktop.isNull,desktop.width>0 else { return }
        let area=bounds.insetBy(dx:24,dy:24)
        let scale=min(area.width/desktop.width,area.height/desktop.height)
        let offset=CGPoint(x:area.midX-desktop.width*scale/2,y:area.midY-desktop.height*scale/2)
        func map(_ p:CGPoint)->CGPoint { CGPoint(x:offset.x+(p.x-desktop.minX)*scale,y:offset.y+(desktop.maxY-p.y)*scale) }
        func rect(_ r:CGRect)->CGRect { CGRect(x:map(CGPoint(x:r.minX,y:r.maxY)).x,y:map(CGPoint(x:r.minX,y:r.maxY)).y,width:r.width*scale,height:r.height*scale) }
        for screen in screens {
            let r=rect(screen)
            NSColor(calibratedWhite:0.22,alpha:1).setStroke();let border=NSBezierPath(roundedRect:r,xRadius:8,yRadius:8);border.lineWidth=1.5;border.stroke()
            NSColor(calibratedWhite:0.3,alpha:0.35).setStroke()
            for n in 1...3 { let grid=NSBezierPath();grid.move(to:CGPoint(x:r.minX+r.width*CGFloat(n)/4,y:r.minY));grid.line(to:CGPoint(x:r.minX+r.width*CGFloat(n)/4,y:r.maxY));grid.stroke() }
        }
        if let targetBounds { NSColor.systemTeal.withAlphaComponent(0.15).setFill();NSColor.systemTeal.withAlphaComponent(0.7).setStroke();let p=NSBezierPath(rect:rect(targetBounds));p.fill();p.stroke() }
        // A short fading tail keeps recent motion readable without a web of old paths.
        for i in trail.indices {
            let freshness=CGFloat(i+1)/CGFloat(trail.count)
            let p=map(trail[i])
            if i>0 {
                NSColor.systemTeal.withAlphaComponent(0.08+0.42*freshness).setStroke()
                let segment=NSBezierPath();segment.move(to:map(trail[i-1]));segment.line(to:p)
                segment.lineWidth=1.25;segment.lineCapStyle = .round;segment.stroke()
            }
            if i<trail.count-1 {
                NSColor.systemTeal.withAlphaComponent(0.1+0.55*freshness).setFill()
                NSBezierPath(ovalIn:CGRect(x:p.x-1.5,y:p.y-1.5,width:3,height:3)).fill()
            }
        }
        if let pointer {
            let p=map(pointer);NSColor.systemTeal.setStroke();let cross=NSBezierPath();cross.move(to:CGPoint(x:p.x-10,y:p.y));cross.line(to:CGPoint(x:p.x+10,y:p.y));cross.move(to:CGPoint(x:p.x,y:p.y-10));cross.line(to:CGPoint(x:p.x,y:p.y+10));cross.lineWidth=1.5;cross.stroke()
            NSColor.systemTeal.setFill();NSBezierPath(ovalIn:CGRect(x:p.x-3,y:p.y-3,width:6,height:6)).fill()
        }
    }
}
