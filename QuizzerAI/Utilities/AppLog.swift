import os

/// Centralised diagnostic logging for QuizzerAI.
///
/// Uses Apple's `os.Logger` instead of `print()`. Logger messages are:
///   - Categorised by subsystem + category for easy filtering in Console.app
///   - Visible only when the log level is enabled (`.warning` for diagnostics)
///   - NOT written to stdout (unlike `print()`), so they don't trigger
///     Apple review flags for "excessive logging"
///
/// Usage:
///   `AppLog.ai.warning("OCR failed: \(error.localizedDescription, privacy: .public)")`
enum AppLog {
    private static let subsystem = "com.quizzerai"

    /// AI engine: OCR, Foundation Models, extraction pipeline
    static let ai         = Logger(subsystem: subsystem, category: "AI")
    /// StoreKit 2: products, entitlements, purchases
    static let store      = Logger(subsystem: subsystem, category: "Store")
    /// Camera session lifecycle: configuration, torch, start/stop
    static let camera     = Logger(subsystem: subsystem, category: "Camera")
    /// BGProcessingTask scheduling and execution
    static let background = Logger(subsystem: subsystem, category: "Background")
    /// SwiftUI view-level events: save failures, scan errors
    static let ui         = Logger(subsystem: subsystem, category: "UI")
    /// App lifecycle: container creation, background transitions
    static let app        = Logger(subsystem: subsystem, category: "App")
}
