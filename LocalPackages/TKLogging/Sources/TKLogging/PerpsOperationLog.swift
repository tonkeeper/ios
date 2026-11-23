import Foundation

public protocol PerpsOperationLoggableError: Error {
    var operationLogSource: String { get }
    var operationLogFields: [String: String] { get }
}

public extension PerpsOperationLoggableError {
    var operationLogFields: [String: String] {
        [:]
    }
}

public enum PerpsOperationLog {
    @TaskLocal public static var context: [String: String] = [:]

    public static func step<T>(
        _ stage: String,
        source: String = "client",
        fields: [String: String] = [:],
        quiet: Bool = false,
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> T
    ) async rethrows -> T {
        var fields = fields
        if quiet { fields["poll"] = "true" }
        return try await withContext(fields: fields) {
            let started = ProcessInfo.processInfo.systemUptime
            if !quiet { event(stage, outcome: "started", source: source) }
            do {
                let value = try await operation()
                if !quiet { event(stage, outcome: "completed", source: source, fields: ["duration_ms": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))]) }
                return value
            } catch {
                event(stage, outcome: "failed", source: source, error: error, fields: ["duration_ms": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))])
                throw error
            }
        }
    }

    public static func withContext<T>(
        fields: [String: String],
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> T
    ) async rethrows -> T {
        var scope = context.merging(fields) { _, new in new }
        if scope["trace_id"] == nil { scope["trace_id"] = UUID().uuidString }
        if scope["chain"] == nil {
            scope["chain"] = scope["asset_id"]?.split(separator: "/").first.map(String.init)
        }
        return try await $context.withValue(scope) {
            try await operation()
        }
    }

    public static func event(
        _ stage: String,
        outcome: String,
        source: String = "client",
        error: Error? = nil,
        fields: [String: String] = [:]
    ) {
        var info = context.merging(fields) { _, new in new }
        if let details = (error as? any PerpsOperationLoggableError)?.operationLogFields {
            info.merge(details) { _, new in new }
        }
        info["stage"] = stage
        info["outcome"] = outcome
        info["boundary"] = source
        info["source"] = (error as? any PerpsOperationLoggableError)?.operationLogSource ?? source
        if info["source"] == "unknown", outcome == "failed" { info["outcome"] = "unknown" }
        let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled || info["source"] == "user_or_lifecycle"
        if cancelled {
            info["outcome"] = "cancelled"
            info["source"] = "user_or_lifecycle"
        } else if let error = error as? URLError {
            info["source"] = "network"
            info["network_code"] = String(error.errorCode)
        }
        if !cancelled, info["outcome"] != "noop", error != nil || ["failed", "unknown", "unavailable", "rejected"].contains(info["outcome"] ?? outcome) {
            Log.perps.w("Operation", error: error, extraInfo: info)
        } else {
            Log.perps.i("Operation", error: error, extraInfo: info)
        }
    }
}
