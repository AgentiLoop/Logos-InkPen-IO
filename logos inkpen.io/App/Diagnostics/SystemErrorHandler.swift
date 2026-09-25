import SwiftUI

class SystemErrorHandler {
    static let shared = SystemErrorHandler()

    private init() {}

    func handleSystemError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        let errorDomain = (error as NSError).domain
        let errorCode = (error as NSError).code
        if errorDescription.contains("detachedsignatures") ||
            errorDescription.contains("/private/var/db/") ||
            errorDescription.contains("no such file or directory") {
            return true
        }
        if errorDescription.contains("renderbox") ||
            errorDescription.contains("metallib") ||
            errorDescription.contains("mach-o") {
            return true
        }
        if errorDescription.contains("personaattributes") ||
            errorDescription.contains("persona type") ||
            errorDescription.contains("operation not permitted") {
            return true
        }
        if errorDomain == "NSCocoaErrorDomain" &&
            (errorDescription.contains("file system") || errorDescription.contains("permission")) {
            return true
        }
        if errorDomain == "NSPOSIXErrorDomain" &&
            (errorCode == 1 || errorCode == 2) {
            return true
        }
        return false
    }
}
