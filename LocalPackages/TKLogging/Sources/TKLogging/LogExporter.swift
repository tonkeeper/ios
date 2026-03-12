import Foundation
import OSLog
import UIKit

public enum LogExporter {
    public static func collectText(
        domain: LogDomain?,
        lastHours: Double = 2,
        scope: OSLogStore.Scope = .currentProcessIdentifier,
        includeHeader: Bool = true,
        extraInfo: [String: String] = [:]
    ) throws -> String {
        let subsystem = domain?.subsystem ?? Log.configuration.defaultSubsystem
        return try collectText(
            subsystem: subsystem,
            category: domain?.category,
            lastHours: lastHours,
            scope: scope,
            includeHeader: includeHeader,
            extraInfo: extraInfo
        )
    }

    private static func collectText(
        subsystem: String,
        category: String?,
        lastHours: Double,
        scope: OSLogStore.Scope,
        includeHeader: Bool,
        extraInfo: [String: String]
    ) throws -> String {
        let store = try OSLogStore(scope: scope)
        let position = store.position(timeIntervalSinceEnd: lastHours * 3600)
        let predicate: NSPredicate
        if let category {
            predicate = NSPredicate(format: "subsystem == %@ AND category == %@", subsystem, category)
        } else {
            predicate = NSPredicate(format: "subsystem == %@", subsystem)
        }
        let entries = try store.getEntries(at: position, matching: predicate)

        let dateFormatter = ISO8601DateFormatter()
        var lines: [String] = []

        for case let entry as OSLogEntryLog in entries {
            lines.append("[\(dateFormatter.string(from: entry.date))] [\(levelName(entry.level))] \(entry.composedMessage)")
        }

        let logsBody = lines.joined(separator: "\n")

        guard includeHeader else {
            return logsBody
        }

        let header = headerText(
            subsystem: subsystem,
            category: category,
            lastHours: lastHours,
            entriesCount: lines.count,
            extraInfo: extraInfo
        )

        return logsBody.isEmpty ? header : "\(header)\n\n\(logsBody)"
    }

    @discardableResult
    public static func exportToTemporaryFile(
        domain: LogDomain?,
        lastHours: Double = 2,
        filenamePrefix: String = "logs",
        scope: OSLogStore.Scope = .currentProcessIdentifier,
        includeHeader: Bool = true,
        extraInfo: [String: String] = [:]
    ) throws -> URL {
        let text = try collectText(
            domain: domain,
            lastHours: lastHours,
            scope: scope,
            includeHeader: includeHeader,
            extraInfo: extraInfo
        )
        return try saveToTemporaryFile(text: text, filenamePrefix: filenamePrefix)
    }

    @discardableResult
    private static func saveToTemporaryFile(
        text: String,
        filenamePrefix: String
    ) throws -> URL {
        let filename = "\(filenamePrefix)_\(Int(Date().timeIntervalSince1970)).log"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func headerText(
        subsystem: String,
        category: String?,
        lastHours: Double,
        entriesCount: Int,
        extraInfo: [String: String]
    ) -> String {
        let formatter = ISO8601DateFormatter()

        var lines: [String] = [
            "=== Tonkeeper Log Export ===",
            "Generated at: \(formatter.string(from: Date()))",
            "Subsystem: \(subsystem)",
            "Category: \(category ?? "all categories")",
            "Period: last \(lastHours)h",
            "Entries count: \(entriesCount)",
            "App version: \(appVersion)",
            "Build number: \(buildNumber)",
            "Build configuration: \(buildConfiguration)",
            "Bundle identifier: \(bundleIdentifier)",
            "OS version: \(operatingSystemVersion)",
            "Device: \(deviceDescription)",
            "Locale: \(Locale.current.identifier)",
            "Time zone: \(TimeZone.current.identifier)",
        ]

        if !extraInfo.isEmpty {
            lines.append("Extra info:")
            extraInfo
                .sorted(by: { $0.key < $1.key })
                .forEach { key, value in
                    lines.append("- \(key): \(value)")
                }
        }

        return lines.joined(separator: "\n")
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    private static var buildConfiguration: String {
        #if DEBUG
            return "Debug"
        #else
            return "Release"
        #endif
    }

    private static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    private static var operatingSystemVersion: String {
        #if canImport(UIKit)
            return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
            return ProcessInfo.processInfo.operatingSystemVersionString
        #else
            return "unknown"
        #endif
    }

    private static var deviceDescription: String {
        #if canImport(UIKit)
            return UIDevice.current.model
        #elseif os(macOS)
            return "Mac"
        #else
            return "unknown"
        #endif
    }

    private static func levelName(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .error:
            return "WARNING"
        case .fault:
            return "ERROR"
        default:
            return "UNKNOWN"
        }
    }
}
