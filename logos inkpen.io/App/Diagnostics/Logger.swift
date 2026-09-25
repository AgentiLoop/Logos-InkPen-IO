import SwiftUI
import os.log

enum LogCategory: String, CaseIterable {
    case general = "general"
    case pressure = "pressure"
    case input = "input"
    case selection = "selection"
    case zoom = "zoom"
    case metal = "metal"
    case startup = "startup"
    case shapes = "shapes"
    case fileOperations = "fileOperations"
    case performance = "performance"
    case error = "error"
    case debug = "debug"
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fault = "fault"
}

struct Log {
    #if DEBUG
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.logos.inkpen"

    private static var loggers: [LogCategory: Logger] = [:]

    private static let loggersQueue = DispatchQueue(label: "com.logos.logger.queue", attributes: .concurrent)

    private static var messageCounters: [String: Int] = [:]

    private static let maxRepeatedMessages = 3
    private static let counterQueue = DispatchQueue(label: "com.logos.logger.counters", qos: .utility)
    private static let fontRelatedPatterns = [
        "FONT",
        "TYPOGRAPHY",
        "TEXT BOX",
        "🔤",
        "FONT PANEL",
        "FONT SETTINGS",
        "FONT FAMILY",
        "PDF"
    ]

    private static func logger(for category: LogCategory) -> Logger {
        var existingLogger: Logger?
        loggersQueue.sync {
            existingLogger = loggers[category]
        }
        if let existing = existingLogger {
            return existing
        }
        return loggersQueue.sync(flags: .barrier) {
            if let existing = loggers[category] {
                return existing
            }
            let logger = Logger(subsystem: subsystem, category: category.rawValue)
            loggers[category] = logger
            return logger
        }
    }

    private static func shouldSuppressMessage(_ message: String) -> Bool {
        let isFontRelated = fontRelatedPatterns.contains { pattern in
            message.uppercased().contains(pattern)
        }
        if isFontRelated {
            return false
        }
        let messageKey = simplifyMessageForCounting(message)
        return counterQueue.sync {
            let currentCount = messageCounters[messageKey, default: 0] + 1
            messageCounters[messageKey] = currentCount
            return currentCount > maxRepeatedMessages
        }
    }

    private static func simplifyMessageForCounting(_ message: String) -> String {
        var simplified = message
        simplified = simplified.replacingOccurrences(of: #"\([0-9.-]+,\s*[0-9.-]+\)"#, with: "(X,Y)", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"[A-F0-9]{8}(-[A-F0-9]{4}){3}-[A-F0-9]{12}"#, with: "UUID", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"[A-F0-9]{8}"#, with: "UUID", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"textID=[A-F0-9]+"#, with: "textID=UUID", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"frame:\s*\([0-9.-]+,\s*[0-9.-]+,\s*[0-9.-]+,\s*[0-9.-]+\)"#, with: "frame: (X,Y,W,H)", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"position=[0-9]+"#, with: "position=N", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"length=[0-9]+"#, with: "length=N", options: .regularExpression)
        return simplified
    }
    #endif

    static func info(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        if shouldSuppressMessage(message) {
            return
        }
        let logger = logger(for: category)
        logger.info("\(message, privacy: .public)")
        #endif
    }

    static func warning(_ message: String, category: LogCategory = .general) {
        #if DEBUG
        if shouldSuppressMessage(message) {
            return
        }
        let logger = logger(for: category)
        logger.warning("\(message, privacy: .public)")
        #endif
    }

    static func error(_ message: String, category: LogCategory = .error) {
        #if DEBUG
        let logger = logger(for: category)
        logger.error("\(message, privacy: .public)")
        #endif
    }

    static func fault(_ message: String, category: LogCategory = .error) {
        #if DEBUG
        let logger = logger(for: category)
        logger.fault("\(message, privacy: .public)")
        #endif
    }

    static func metal(_ message: String, level: LogLevel = .info) {
        #if DEBUG
        switch level {
        case .debug: info(message, category: .metal)
        case .info: info(message, category: .metal)
        case .warning: warning(message, category: .metal)
        case .error: error(message, category: .metal)
        case .fault: fault(message, category: .metal)
        }
        #endif
    }

    static func fileOperation(_ message: String, level: LogLevel = .info) {
        #if DEBUG
        switch level {
        case .debug: info(message, category: .fileOperations)
        case .info: info(message, category: .fileOperations)
        case .warning: warning(message, category: .fileOperations)
        case .error: error(message, category: .error)
        case .fault: fault(message, category: .error)
        }
        #endif
    }
}
