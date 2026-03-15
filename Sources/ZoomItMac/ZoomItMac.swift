import AppKit

@main
enum ZoomItMacMain {
    static func main() {
        AppRuntime().run()
    }
}

@MainActor
private final class AppRuntime {
    private let app = NSApplication.shared
    private let delegate = AppDelegate()

    func run() {
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}
