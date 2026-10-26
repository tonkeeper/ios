import Foundation
import UIKit

public enum LogExporter {
    @discardableResult
    public static func exportToTemporaryFile(
        sessionLog: SessionLogBackend?,
        filenamePrefix: String = "logs",
        extraInfo: [String: String] = [:]
    ) throws -> URL {
        let filename = "\(filenamePrefix)_\(Int(Date().timeIntervalSince1970)).log"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let output = try FileHandle(forWritingTo: url)
        try output.write(contentsOf: Data("\(headerText(extraInfo: extraInfo))\n\n".utf8))
        try sessionLog?.writeSessions(to: output)
        try output.close()
        return url
    }

    private static func headerText(extraInfo: [String: String]) -> String {
        let formatter = LogTimestamp.formatter

        var lines: [String] = [
            "=== Keeper Log Export ===",
            "Generated at: \(formatter.string(from: Date()))",
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

    static var environmentDescription: String {
        "app=\(appVersion) build=\(buildNumber) \(buildConfiguration) os=\(operatingSystemVersion) device=\(deviceDescription) locale=\(Locale.current.identifier) tz=\(TimeZone.current.identifier)"
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    static var buildConfiguration: String {
        #if DEBUG
            return "Debug"
        #else
            return "Release"
        #endif
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    static var operatingSystemVersion: String {
        #if canImport(UIKit)
            return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
            return ProcessInfo.processInfo.operatingSystemVersionString
        #else
            return "unknown"
        #endif
    }

    static var deviceDescription: String {
        #if canImport(UIKit)
            return UIDevice.current.model
        #elseif os(macOS)
            return "Mac"
        #else
            return "unknown"
        #endif
    }
}
