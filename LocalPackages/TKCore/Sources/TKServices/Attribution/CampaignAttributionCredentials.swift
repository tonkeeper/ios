import Foundation

public enum CampaignAttributionCredentials {
    public static let placeholderPrefix = "REPLACE_WITH_"

    /// A build setting left at its placeholder must not be sent to an attribution SDK.
    public static func configured(_ rawValue: String?) -> String? {
        guard
            let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty,
            !trimmed.hasPrefix(placeholderPrefix)
        else {
            return nil
        }
        return trimmed
    }
}
