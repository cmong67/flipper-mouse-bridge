import Foundation

// Display-only feedback: never generates a mouse or keyboard event.
enum TargetAction {case none,left,right,middle,scrollUp,scrollDown,scrollLeft,scrollRight}
struct TargetFeedback {
    var action=TargetAction.none
    var started = -100.0
    var doubleClick=false
    var lastEvent = -100.0
    var isScroll:Bool {action == .scrollUp || action == .scrollDown || action == .scrollLeft || action == .scrollRight}
    func intensity(at time:Double,reduceMotion:Bool=false)->Double {
        let age=time-started,period=0.85,count=doubleClick ? 2.0:1.0
        guard action != .none,age>=0 else{return 0}
        if isScroll {
            let elapsed=max(0,time-lastEvent),fade=max(0,1-max(0,elapsed-0.18)/0.65)
            let phase=max(0,min(time,lastEvent)-started)
            return (reduceMotion ? 0.65:(0.35+0.55*(1-cos(2 * .pi * phase/1.5))/2))*fade
        }
        guard age<period*count else{return 0}
        if reduceMotion{return 0.65}
        let phase=age.truncatingRemainder(dividingBy:period)
        return phase<0.75 ? sin(.pi*phase/0.75):0
    }
    static func hue(quadrant:Int,time:Double)->Double {
        let phase=time.truncatingRemainder(dividingBy:16)/16
        return (phase+Double(quadrant)/4).truncatingRemainder(dividingBy:1)
    }
}
