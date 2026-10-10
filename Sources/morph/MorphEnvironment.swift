import Cocoa

/// Centralized environment detection for Morph.
public enum MorphEnvironment {
    /// Indicates whether Morph is currently running inside an automated test harness (e.g. xctest, swift test).
    /// When true, all on-screen windows, panels, focus-steals, and global mouse monitors MUST be suppressed
    /// to ensure zero disruption to the user's display and desktop workspace.
    public static var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            ProcessInfo.processInfo.environment["MORPH_TEST_MODE"] == "1" ||
            NSClassFromString("XCTestCase") != nil
    }
}
