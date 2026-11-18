import Foundation
@main struct TargetTests {
    static func main() {
        let single=TargetFeedback(action:.left,started:0)
        precondition(single.intensity(at:-0.01)==0 && single.intensity(at:0.375)>0.99 && single.intensity(at:0.85)==0)
        let double=TargetFeedback(action:.right,started:0,doubleClick:true)
        precondition(double.intensity(at:0.8)==0 && double.intensity(at:1.225)>0.99 && double.intensity(at:1.7)==0)
        let scroll=TargetFeedback(action:.scrollDown,started:0,lastEvent:3)
        precondition(scroll.intensity(at:2)>0 && scroll.intensity(at:3.4)>0 && scroll.intensity(at:3.84)==0)
        for i in 0..<1000 {let time=Double(i)/100;precondition((0...1).contains(double.intensity(at:time)));precondition((0...1).contains(scroll.intensity(at:time)))}
        precondition(single.intensity(at:0.3,reduceMotion:true)==single.intensity(at:0.6,reduceMotion:true))
        for quadrant in 0..<4 {precondition(abs(TargetFeedback.hue(quadrant:quadrant,time:3)-TargetFeedback.hue(quadrant:quadrant,time:19))<0.0001)}
        print("PASS: gentle single/double pulse duration, sustained scroll and fade, reduce-motion behavior and 16-second color cycle")
    }
}
