import Foundation

enum LaunchOptions: Equatable {
    case dashboard, preview, cli(String), render(String), selfTest, help, version

    static let usage = """
    Usage: mouse-bridge [--cli [DEVICE_NAME] | --dashboard-preview | --render-dashboard /absolute/output.png | --self-test | --help | --version]
    Choose one mode. No arguments opens the local dashboard.
    """

    static func parse(_ arguments: [String]) -> LaunchOptions? {
        switch arguments {
        case []: return .dashboard
        case ["--dashboard-preview"]: return .preview
        case ["--self-test"]: return .selfTest
        case ["--help"], ["-h"]: return .help
        case ["--version"]: return .version
        case ["--cli"]: return .cli("Flipper")
        default:
            guard arguments.count == 2 else { return nil }
            if arguments[0] == "--cli" {
                let name = arguments[1].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !name.hasPrefix("--") else { return nil }
                return .cli(name)
            }
            if arguments[0] == "--render-dashboard", arguments[1].hasPrefix("/") {
                return .render(arguments[1])
            }
            return nil
        }
    }

    static func tests() {
        precondition(parse([]) == .dashboard)
        precondition(parse(["--cli"]) == .cli("Flipper"))
        precondition(parse(["--cli", " Codex "]) == .cli("Codex"))
        precondition(parse(["--dashboard-preview"]) == .preview)
        precondition(parse(["--render-dashboard", "/tmp/test.png"]) == .render("/tmp/test.png"))
        for invalid in [["--cli", "--dashboard-preview"], ["--dashboard-preview", "--cli", "Codex"], ["--render-dashboard"], ["--render-dashboard", "relative.png"], ["--cli", " "], ["--unknown"], ["--self-test", "--cli"], ["Codex"], ["--cli", "Codex", "extra"]] {
            precondition(parse(invalid) == nil)
        }
        print("PASS: exclusive launch modes and argument validation")
    }
}
