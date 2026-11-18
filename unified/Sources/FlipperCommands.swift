import Foundation

enum FlipperCommands {
    static func translate(_ text:String)->MouseCommand? {
        let p=text.split(separator:" ").map(String.init)
        guard let verb=p.first else{return nil}
        func integer(_ i:Int,_ limit:Int)->Int? {guard p.indices.contains(i),let n=Int(p[i]),abs(Double(n))<=Double(limit) else{return nil};return n}
        let buttons=["left":1,"right":2,"middle":4]
        switch verb {
        case "ping" where p.count==1:return .ping
        case "arm" where p.count==1:return .arm
        case "stop" where p.count==1:return .raw("SAFE")
        case "info" where p.count==1:return .raw("INFO")
        case "status" where p.count==1:return .raw("STATUS")
        case "host","viewport","observe":return text.utf8.count<96 ? .raw(text):nil
        case "move" where p.count==3:
            guard let x=integer(1,127),let y=integer(2,127) else{return nil};return .move(x,y)
        case "click" where p.count==2, "double" where p.count==2:
            guard let button=buttons[p[1]] else{return nil};return .click(button,verb=="double" ? 2:1)
        case "scroll" where p.count==2:
            guard let n=integer(1,127) else{return nil};return .scroll(n)
        case "drag" where p.count==4 && p[1]=="left":
            guard let x=integer(2,2000),let y=integer(3,2000) else{return nil};return .drag(x,y,500)
        default:return nil
        }
    }
}
