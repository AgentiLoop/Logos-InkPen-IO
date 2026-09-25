import Foundation

enum SandboxChecker {

    static var isSandboxed: Bool {
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    static var isNotSandboxed: Bool {
        return !isSandboxed
    }
}
