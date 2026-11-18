import AppKit

enum Spectrum {
    static let up=NSColor(red:1,green:0.79,blue:0.38,alpha:1)
    static let right=NSColor(red:0.40,green:0.91,blue:0.68,alpha:1)
    static let down=NSColor(red:0.43,green:0.69,blue:1,alpha:1)
    static let left=NSColor(red:0.78,green:0.60,blue:1,alpha:1)
}

extension MarkerView {
    func drawQuietTarget() {
        let p=point,time=ProcessInfo.processInfo.systemUptime
        let reduce=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let idle=time-motionAt>0.7
        let pulse=feedback.intensity(at:time,reduceMotion:reduce)
        let motion=time-motionAt<0.3 ? movement:0
        let action:TargetAction = pulse>0 || heldButtons != 0 || motion==0 ? feedback.action:([TargetAction.none,.scrollUp,.scrollDown,.left,.right][motion])
        let strength=max(pulse,motion != 0 && pulse==0 ? 0.55:0)
        let active: NSColor
        switch action {
        case .left,.scrollLeft:active=Spectrum.left
        case .right,.scrollRight:active=Spectrum.right
        case .scrollUp:active=Spectrum.up
        case .scrollDown:active=Spectrum.down
        default:active = .white
        }
        let backing=NSBezierPath(ovalIn:NSRect(x:p.x-13,y:p.y-13,width:26,height:26))
        NSColor.black.withAlphaComponent(0.55).setStroke();backing.lineWidth=4;backing.stroke()
        for quadrant in 0..<4 {
            let selected:Bool
            switch action {
            case .left,.scrollLeft:selected=quadrant==1 || quadrant==2
            case .right,.scrollRight:selected=quadrant==0 || quadrant==3
            case .scrollUp:selected=quadrant<2
            case .scrollDown:selected=quadrant>=2
            default:selected=false
            }
            let held=(heldButtons & 1 != 0 && (quadrant==1 || quadrant==2)) || (heldButtons & 2 != 0 && (quadrant==0 || quadrant==3))
            let color:NSColor
            if selected && (strength>0 || held) {color=active.withAlphaComponent(min(1,1.1*(0.55+0.4*max(strength,held ? 0.65:0))))}
            else if idle && !reduce {color=NSColor(calibratedHue:TargetFeedback.hue(quadrant:quadrant,time:time),saturation:0.48,brightness:0.92,alpha:0.693)}
            else {color=NSColor(white:0.85,alpha:0.55)}
            color.setStroke()
            let arc=NSBezierPath();arc.appendArc(withCenter:p,radius:12,startAngle:CGFloat(quadrant*90+8),endAngle:CGFloat((quadrant+1)*90-8));arc.lineWidth=1.6;arc.lineCapStyle = .round;arc.stroke()
        }
        let arms:[(NSPoint,NSPoint)]=[
            (NSPoint(x:p.x-24,y:p.y),NSPoint(x:p.x-16,y:p.y)),
            (NSPoint(x:p.x+16,y:p.y),NSPoint(x:p.x+24,y:p.y)),
            (NSPoint(x:p.x,y:p.y+16),NSPoint(x:p.x,y:p.y+24)),
            (NSPoint(x:p.x,y:p.y-24),NSPoint(x:p.x,y:p.y-16))]
        for (index,arm) in arms.enumerated() {
            let selected=(index==0 && (action == .left || action == .scrollLeft)) || (index==1 && (action == .right || action == .scrollRight)) || ((index==2 || index==3) && (action == .scrollUp || action == .scrollDown || action == .middle)) || ((index==0 || index==1) && (action == .scrollLeft || action == .scrollRight))
            (selected ? active.withAlphaComponent(min(1,1.1*(0.22+0.7*strength))):NSColor.white.withAlphaComponent(0.25)).setStroke()
            let line=NSBezierPath();line.move(to:arm.0);line.line(to:arm.1);line.lineWidth=1.2;line.lineCapStyle = .round;line.stroke()
        }
        if action == .middle || action == .scrollUp || action == .scrollDown || (action == .scrollLeft || action == .scrollRight) {
            active.withAlphaComponent(0.935*pulse).setFill()
            NSBezierPath(roundedRect:NSRect(x:p.x-1.5,y:p.y-3,width:3,height:6),xRadius:1.5,yRadius:1.5).fill()
        }
        // Preserve the original compact coordinate/application caption.
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.white]
        let str=caption as NSString,size=str.size(withAttributes:attrs)
        let x=max(6,min(p.x+27,bounds.width-size.width-18)),y=max(6,min(p.y-37,bounds.height-size.height-12))
        NSColor.black.withAlphaComponent(0.72).setFill();NSBezierPath(roundedRect:NSRect(x:x-6,y:y-5,width:size.width+12,height:size.height+10),xRadius:5,yRadius:5).fill();str.draw(at:NSPoint(x:x,y:y),withAttributes:attrs)
    }
}
