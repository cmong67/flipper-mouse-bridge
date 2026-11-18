import AppKit
// Read-only device display capture for release verification; never sends HID input.
enum FlipperScreenCapture {
 static func run(path:String) {
    let bridge=MouseBridge()
    var owner:SessionOwner?
    do {owner=try SessionOwner()} catch {fputs("Controller already running\n",stderr);exit(1)}
    var requested=false,captured=false
    bridge.onScreen={bytes in
        guard !captured,bytes.count==1024 else{return};captured=true
        let image=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:128,pixelsHigh:64,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:384,bitsPerPixel:24)!
        for y in 0..<64 {for x in 0..<128 {
            let lit=(bytes[x+(y/8)*128] & (1 << (y%8))) != 0
            let value:UInt8=lit ? 0:255
            let offset=y*384+x*3
            image.bitmapData![offset]=value;image.bitmapData![offset+1]=value;image.bitmapData![offset+2]=value
        }}
        do {try image.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))}
        catch {fputs("Capture write failed\n",stderr);bridge.stop {exit(1)};return}
        print("CAPTURED",path);bridge.stop {owner=nil;exit(0)}
    }
    bridge.onState={state,detail in
        if state == .failed {fputs((detail+"\n"),stderr);exit(1)}
    }
    let timer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true){_ in
        if !requested && bridge.state == .ready {requested=bridge.captureScreen()}
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+30) {bridge.stop {exit(2)}}
    bridge.connect(UserDefaults.standard.string(forKey:"UnifiedFlipperName") ?? "")
    withExtendedLifetime((owner,timer,bridge)){RunLoop.main.run()}
 }
}
