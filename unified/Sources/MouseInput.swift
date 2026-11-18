import AppKit

// Some mouse drivers report buttonNumber=0 for right-button events.
// The event type is authoritative for the primary and secondary buttons.
enum MouseButtons {
    static func index(type:NSEvent.EventType,reported:Int,control:Bool)->Int {
        switch type {
        case .rightMouseDown,.rightMouseUp,.rightMouseDragged:return 1
        case .leftMouseDown,.leftMouseUp,.leftMouseDragged:return control ? 1:0
        case .otherMouseDown,.otherMouseUp,.otherMouseDragged:return min(4,max(2,reported))
        default:return 0
        }
    }
}

struct ClickTracker {
    private var times=[Double](repeating:-100,count:5)
    private var positions=[NSPoint](repeating:.zero,count:5)
    private var counts=[Int](repeating:0,count:5)
    mutating func down(button:Int,point:NSPoint,time:Double,systemCount:Int,interval:Double)->Int {
        let previous=positions[button]
        let repeated=time>=times[button] && time-times[button]<=interval && hypot(point.x-previous.x,point.y-previous.y)<=6 && counts[button]==1
        counts[button]=(systemCount==2 || repeated) ? 2:1
        times[button]=time;positions[button]=point
        return counts[button]
    }
    func count(button:Int)->Int {counts[button]}
}
