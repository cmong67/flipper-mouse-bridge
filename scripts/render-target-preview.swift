import AppKit
@main struct Preview {
    static func main()throws {
        _ = NSApplication.shared
        let image=NSImage(size:NSSize(width:900,height:390))
        image.lockFocus()
        NSColor(red:0.045,green:0.058,blue:0.08,alpha:1).setFill();NSRect(x:0,y:0,width:900,height:390).fill()
        let titleAttrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:14,weight:.semibold),.foregroundColor:NSColor.white]
        let now=ProcessInfo.processInfo.systemUptime
        let cases:[(String,TargetAction,Bool)]=[("Original · Classic",.none,false),("Quiet RGB · idle",.none,true),("Left · violet",.left,true),("Right · green",.right,true),("Scroll up · amber",.scrollUp,true),("Scroll down · blue",.scrollDown,true)]
        for (index,item) in cases.enumerated() {
            let x=CGFloat(index%3)*300,y=CGFloat(1-index/3)*195
            NSGraphicsContext.saveGraphicsState();let transform=NSAffineTransform();transform.translateX(by:x,yBy:y);transform.concat()
            NSColor(white:0.11,alpha:1).setFill();NSBezierPath(roundedRect:NSRect(x:8,y:8,width:284,height:179),xRadius:10,yRadius:10).fill()
            (item.0 as NSString).draw(at:NSPoint(x:22,y:155),withAttributes:titleAttrs)
            let view=MarkerView(frame:NSRect(x:0,y:0,width:280,height:150));view.point=NSPoint(x:68,y:88);view.caption="X 1240 · Y 680";view.quiet=item.2;view.motionAt=now-2
            view.feedback=TargetFeedback(action:item.1,started:now-0.375,lastEvent:now)
            view.draw(view.bounds)
            NSGraphicsContext.restoreGraphicsState()
        }
        image.unlockFocus()
        let bitmap=NSBitmapImageRep(cgImage:image.cgImage(forProposedRect:nil,context:nil,hints:nil)!)
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
    }
}
