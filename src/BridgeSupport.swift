import Foundation
import Darwin

enum BridgeError: Error, CustomStringConvertible {
    case message(String)
    var description: String { switch self { case let .message(text): return text } }
}
typealias Completion = (Result<String, BridgeError>) -> Void

enum MouseCommand: Equatable {
    case ping, arm, position(Int, Int), move(Int, Int), click(Int, Int), scroll(Int), drag(Int, Int, Int)
    var needsArm: Bool { switch self {case .ping,.arm,.position:return false;default:return true} }
    var isTelemetry:Bool { if case .position=self {return true};return false }
    var text: String {
        switch self {
        case .ping: return "PING"
        case .arm: return "ARM"
        case let .position(x,y): return "POS \(x) \(y)"
        case let .move(x,y): return "MOVE \(x) \(y)"
        case let .click(b,n): return "CLICK \(b) \(n)"
        case let .scroll(n): return "SCROLL \(n)"
        case let .drag(x,y,t): return "DRAG \(x) \(y) \(t)"
        }
    }
    static func parse(_ text: String) -> MouseCommand? {
        let parts=text.uppercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let name=parts.first else { return nil }
        let args=parts.dropFirst().compactMap(Int.init)
        guard args.count == parts.count-1 else { return nil }
        switch (name,args.count) {
        case ("PING",0): return .ping
        case ("ARM",0): return .arm
        case ("POS",2) where args.allSatisfy({ (-99999...99999).contains($0) }): return .position(args[0],args[1])
        case ("MOVE",2) where args.allSatisfy({ (-127...127).contains($0) }): return .move(args[0],args[1])
        case ("CLICK",2) where [1,2,4].contains(args[0]) && (1...2).contains(args[1]): return .click(args[0],args[1])
        case ("SCROLL",1) where (-127...127).contains(args[0]): return .scroll(args[0])
        case ("DRAG",3) where (-2000...2000).contains(args[0]) && (-2000...2000).contains(args[1]) && (100...3000).contains(args[2]): return .drag(args[0],args[1],args[2])
        default: return nil
        }
    }
}

struct QueuedCommand {
    let command: MouseCommand
    let deadline: TimeInterval
    let completion: Completion
    let validWhen: ()->Bool
}
struct CommandQueue {
    let limit: Int
    private(set) var items=[QueuedCommand]()
    mutating func append(_ command: MouseCommand, now: TimeInterval, validWhen: @escaping ()->Bool = {true}, completion: @escaping Completion) -> Bool {
        guard items.count < limit else { return false }
        items.append(QueuedCommand(command: command, deadline: now+5, completion: completion, validWhen:validWhen)); return true
    }
    mutating func next(now: TimeInterval) -> (QueuedCommand?, [QueuedCommand]) {
        var expired=[QueuedCommand]()
        while !items.isEmpty {
            let item=items.removeFirst()
            if now <= item.deadline { return (item,expired) }
            expired.append(item)
        }
        return (nil,expired)
    }
    mutating func cancel() -> [QueuedCommand] { let old=items; items.removeAll(); return old }
}

// One lock for GUI and CLI; the OS releases it even if the process crashes.
final class SessionOwner {
    let descriptor: Int32
    init() throws {
        let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("FlipperMouseBridge",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        descriptor=open(directory.appendingPathComponent("controller.lock").path,O_CREAT|O_RDWR,0o600)
        guard descriptor >= 0 else { throw BridgeError.message("Cannot open the controller session lock.") }
        guard flock(descriptor,LOCK_EX|LOCK_NB)==0 else {
            close(descriptor); throw BridgeError.message("Another bridge controller is running. Stop or close it first.")
        }
    }
    deinit { flock(descriptor,LOCK_UN); close(descriptor) }
}

func supportTests() {
    precondition(MouseCommand.parse("click 1 2") == .click(1,2))
    precondition(MouseCommand.parse("POS -1200 400") == .position(-1200,400))
    precondition(!MouseCommand.position(1,2).needsArm)
    for invalid in ["POS 100000 0","POS 1 2 garbage","MOVE 128 0","MOVE 0 -128","DRAG 0 0 99","CLICK 3 1","CLICK 1 3","ARM extra","SCROLL 1 2","MOVE 1e3 0"] {
        precondition(MouseCommand.parse(invalid)==nil)
    }
    var q=CommandQueue(limit:2);var completions=[String]()
    let done: Completion={ result in completions.append(String(describing:result)) }
    precondition(q.append(.move(1,0),now:0,completion:done))
    precondition(q.append(.click(1,1),now:1,completion:done))
    precondition(!q.append(.arm,now:1,completion:done))
    let (next,expired)=q.next(now:5.5)
    expired.forEach { $0.completion(.failure(.message("Expired"))) }
    precondition(next?.command == .click(1,1))
    precondition(completions.count==1 && q.items.isEmpty)
    precondition(q.append(.drag(100,0,1000),now:10,completion:done))
    let cancelled=q.cancel();precondition(cancelled.count==1 && q.next(now:10).0==nil)
    precondition(q.append(.click(1,1),now:20,validWhen:{false},completion:done))
    let rejected=q.next(now:20).0
    precondition(rejected != nil && !rejected!.validWhen())
    print("PASS: input bounds, queue capacity, action expiry, cancellation and dispatch guard")
}
