import AppKit
import ExtraDockKit

@main
@MainActor
enum ExtraDockMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // NSApplication holds its delegate weakly; keep it alive for the run loop.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
