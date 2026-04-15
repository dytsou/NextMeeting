import Foundation

/// Shared debug flags usable across the app.
enum AppDebug {
    /// Set to `"1"` to enable all debug-only behaviors.
    static let debugModeEnvKey = "DEV"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[debugModeEnvKey] == "1" || _isDebugAssertConfiguration()
    }

    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[NextMeeting][DEBUG] \(message())")
    }
}

