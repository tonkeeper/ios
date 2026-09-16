import Foundation
import TKLogging

/// Ingestion limits the analytics backends enforce, and the single place that applies them.
///
/// Aptabase validates every event server-side (`EventBody.IsValid`) and refuses one whose property key is
/// blank or longer than `maximumPropertyKeyLength`. On `/api/v0/event` — the path the SDK transport uses —
/// that is a 400 for the whole payload, so one over-long key takes every other property of the event with
/// it, system props included; the batch path drops just that event. Repairing the key here keeps the rest
/// of the event instead of relying on every call site getting the length right.
///
/// Length is measured in UTF-16 units to match the server, which counts `string.Length`.
public enum AnalyticsLimits {
    /// Aptabase property key, and GA4's event-parameter-name limit.
    public static let maximumPropertyKeyLength = 40

    /// GA4 event name. Aptabase allows 60, so this is the binding limit for anything that can reach
    /// Firebase. The generated schema models are held to Aptabase's 60 by
    /// `scripts/analytics/check_key_limits.py`, because they only ever go to Aptabase.
    public static let maximumEventNameLength = 40

    /// Runs for every property of every event, so it stays allocation-free: `contains` is the blank
    /// check the server does (`IsNullOrWhiteSpace`) without materialising a trimmed copy of the key.
    public static func isValidPropertyKey(_ key: String) -> Bool {
        key.utf16.count <= maximumPropertyKeyLength && key.contains { !$0.isWhitespace }
    }

    /// Drops blank keys and truncates over-long ones. `reportViolation` exists so tests can exercise the
    /// repair without tripping the debug assertion.
    static func sanitizeKeys(
        _ args: [String: Any],
        reportViolation: (String) -> Void = reportInvalidPropertyKey
    ) -> [String: Any] {
        guard args.keys.contains(where: { !isValidPropertyKey($0) }) else { return args }

        var result = args.filter { isValidPropertyKey($0.key) }
        // Sorted so the collision two over-long keys can truncate into resolves the same way every run,
        // and applied after the valid keys so a truncation can never displace one.
        for key in args.keys.sorted() where !isValidPropertyKey(key) {
            reportViolation(key)
            let truncated = truncatedPropertyKey(key)
            guard isValidPropertyKey(truncated), result[truncated] == nil else { continue }
            result[truncated] = args[key]
        }
        return result
    }

    /// A key is always a code literal, never runtime data, so an over-long one is a programming error
    /// that has to surface before the build reaches QA.
    static func reportInvalidPropertyKey(_ key: String) {
        Log.w("Analytics: property key '\(key)' is rejected by the ingestion API, repairing it")
        assertionFailure(
            "Analytics property key '\(key)' must be non-blank and at most \(maximumPropertyKeyLength) characters"
        )
    }

    private static func truncatedPropertyKey(_ key: String) -> String {
        var truncated = key
        // Dropping graphemes keeps the result well-formed; prefixing UTF-16 units could split a pair.
        while truncated.utf16.count > maximumPropertyKeyLength {
            truncated.removeLast()
        }
        return truncated
    }
}
