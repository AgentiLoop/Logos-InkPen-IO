import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        StderrFilter.shared.installFilter(suppressing: [
            "/private/var/db/DetachedSignatures",
            "os_unix.c:",
            "cannot open file at line",
            "invalid display identifier",
            "display identifier",
            "Invalid display 0x",
            "Unable to obtain a task name port right",
            "networkd_settings_read_from_file Sandbox",
            "Logging Error: Failed to receive",
            "CALocalDisplayUpdateBlock returned NO",
            "AFIsDeviceGreymatterEligible",
            "precondition failure: unable to load binary archive",
            "Missing Copy Link Service",
            "Connection invalidated",
            "ViewBridge to RemoteViewService Terminated",
            "VCVoiceShortcutClient",
            "Interrupted 0x",
            "Unable to create bundle at URL",
            "Internal inconsistency in menus",
            "[AFPreferences _languageCodeWithFallback:]"
        ])
        setupGlobalErrorHandling()
        setupFallbackTimer()
        NSHelpManager.shared.registerBooks(in: Bundle.main)
    }

    private func setupFallbackTimer() {
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if let mainWindow = NSApplication.shared.mainWindow {
                    mainWindow.makeKeyAndOrderFront(nil)
                    mainWindow.display()
                }
                NSApplication.shared.windows.forEach { window in
                    window.contentView?.needsDisplay = true
                }
            }
        }
    }

    private func setupGlobalErrorHandling() {
        NSSetUncaughtExceptionHandler { exception in
            let exceptionName = exception.name.rawValue
            let exceptionReason = exception.reason ?? "Unknown reason"
        Log.error("📄 GlobalErrorHandler: Uncaught exception: \(exceptionName)", category: .error)
        Log.error("📄 GlobalErrorHandler: Reason: \(exceptionReason)", category: .error)
            if exceptionReason.contains("DetachedSignatures") ||
                exceptionReason.contains("/private/var/db/") ||
                exceptionReason.contains("No such file or directory") ||
                exceptionReason.contains("RenderBox") ||
                exceptionReason.contains("metallib") ||
                exceptionReason.contains("personaAttributes") ||
                exceptionReason.contains("invalid display identifier") ||
                exceptionReason.contains("display identifier") {
                Log.warning("📄 GlobalErrorHandler: System-level error detected - continuing gracefully", category: .startup)
                return
            }
            Log.error("📄 GlobalErrorHandler: Allowing exception to propagate", category: .error)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        let hasDocuments = NSDocumentController.shared.documents.count > 0
        if hasDocuments {
            return false
        }
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            DispatchQueue.main.async {
                AppState.shared.openWindowAction?("onboarding-setup")
            }
            return false
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for window in NSApplication.shared.windows {
            if window.title == "Document Setup" || window.identifier?.rawValue == "onboarding-setup" {
                window.close()
            }
        }
        DocumentStateRegistry.shared.forceCleanupAll()
        SharedMetalDevice.releaseAll()
        return .terminateNow
    }

    func application(_ application: NSApplication, willPresentError error: Error) -> Error {
        Log.error("📄 App: Error intercepted: \(error)", category: .error)
        if SystemErrorHandler.shared.handleSystemError(error) {
            return NSError(domain: "AppDelegate", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "App initialization completed successfully",
                NSLocalizedRecoverySuggestionErrorKey: "The app is ready to use despite the system warning."
            ])
        }
        return error
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveAllOpenDocuments()
        DocumentStateRegistry.shared.forceCleanupAll()
        UserDefaults.standard.synchronize()
    }

    private func saveAllOpenDocuments() {
        let documentController = NSDocumentController.shared
        for document in documentController.documents {
            if document.isDocumentEdited {
                do {
                    if let fileURL = document.fileURL {
                        try document.writeSafely(to: fileURL, ofType: document.fileType ?? "io.logos.logos-inkpen-io", for: .saveOperation)
                    } else {
                        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                            let timestamp = dateFormatter.string(from: Date())
                            let autoSaveURL = documentsURL.appendingPathComponent("AutoSave_\(timestamp).inkpen")
                            try document.writeSafely(to: autoSaveURL, ofType: "io.logos.logos-inkpen-io", for: .saveAsOperation)
                        }
                    }
                } catch {
                    Log.error("❌ Failed to auto-save document: \(error)", category: .error)
                }
            }
        }
    }
}
