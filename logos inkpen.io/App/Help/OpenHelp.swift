import SwiftUI

func openLogosInkPenHelp() {
    let helpBookName = "LogosInkPenHelp"
    if let helpBookPath = Bundle.main.path(forResource: helpBookName, ofType: "help") {
        let helpBookURL = URL(fileURLWithPath: helpBookPath)
        let indexPath = helpBookURL.appendingPathComponent("Contents/Resources/en.lproj/index.html")
        if FileManager.default.fileExists(atPath: indexPath.path) {
            NSWorkspace.shared.open(indexPath)
        } else {
            NSWorkspace.shared.open(helpBookURL)
            Log.warning("📚 Help index not found, opening Help Book root", category: .general)
        }
    } else {
        let projectHelpPath = "/Users/toddbruss/Documents/GitHub/logos/logos inkpen.io/LogosInkPenHelp.help/Contents/Resources/en.lproj/index.html"
        if FileManager.default.fileExists(atPath: projectHelpPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: projectHelpPath))
        } else {
            Log.error("📚 Help Book not found", category: .error)
            let alert = NSAlert()
            alert.messageText = "Help Not Available"
            alert.informativeText = "The help documentation could not be found."
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}
