import Foundation

public enum CampaignAttributionDecoding {
    public static func makeRecord(
        provider: CampaignAttributionProvider,
        payload: [String: AttributionJSON],
        capturedAt: Date
    ) -> CampaignAttributionRecord? {
        let destination: String?
        switch provider {
        case .branch:
            guard isBranchAttributed(payload) else { return nil }
            destination = branchDestination(payload)
        case .linkrunner:
            guard isLinkrunnerAttributed(payload) else { return nil }
            destination = linkrunnerDestination(payload)
        }
        return CampaignAttributionRecord(
            provider: provider,
            payload: payload,
            resolvedDeeplink: destination,
            capturedAt: capturedAt
        )
    }

    public static func branchDestination(_ payload: [String: AttributionJSON]) -> String? {
        for key in ["$ios_deeplink_path", "$deeplink_path", "$canonical_url", "$ios_url"] {
            guard let rawValue = payload[key]?.stringValue else { continue }
            if let destination = normalizeDestination(rawValue) {
                return destination
            }
        }
        return nil
    }

    public static func linkrunnerDestination(_ payload: [String: AttributionJSON]) -> String? {
        guard let rawValue = payload["deeplink"]?.stringValue else { return nil }
        return normalizeDestination(rawValue)
    }

    /// A resolved link is routed on the open that produced it. Cached install data from a later
    /// launch is kept in the store and is not opened again.
    public static func shouldRoute(
        provider: CampaignAttributionProvider,
        payload: [String: AttributionJSON],
        isFirstTouch: Bool
    ) -> Bool {
        switch provider {
        case .branch:
            let openedLink = payload["+clicked_branch_link"]?.boolValue == true
            guard openedLink || isFirstTouch else { return false }
            return branchDestination(payload) != nil
        case .linkrunner:
            guard isFirstTouch else { return false }
            return linkrunnerDestination(payload) != nil
        }
    }

    private static func isBranchAttributed(_ payload: [String: AttributionJSON]) -> Bool {
        if payload["+clicked_branch_link"]?.boolValue == true {
            return true
        }
        return ["~campaign", "~channel", "~feature", "~id"].contains { key in
            guard let value = payload[key]?.stringValue else { return false }
            return !value.isEmpty
        }
    }

    private static func isLinkrunnerAttributed(_ payload: [String: AttributionJSON]) -> Bool {
        if let deeplink = payload["deeplink"]?.stringValue,
           !deeplink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return true
        }
        let campaign = payload["campaignData"]?.objectValue
        let type = campaign?["type"]?.stringValue?.uppercased()
        if type == "INORGANIC" {
            return true
        }
        if let identifier = campaign?["id"]?.stringValue, !identifier.isEmpty, type != "ORGANIC" {
            return true
        }
        return false
    }

    public static func appLink(_ link: String?) -> String? {
        guard let link else { return nil }
        guard let url = URL(string: link), isTrackingURL(url) else { return link }
        return nil
    }

    /// Tracking hosts stay out: the system already delivered that URL.
    private static func normalizeDestination(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return relativeDestination(trimmed)
        }
        if isTrackingURL(url) {
            return nil
        }
        guard isInAppURL(url, scheme: scheme) else { return nil }
        return url.absoluteString
    }

    private static func relativeDestination(_ rawValue: String) -> String? {
        let path = rawValue.hasPrefix("/") ? String(rawValue.dropFirst()) : rawValue
        guard !path.isEmpty, !path.contains(" "), !path.contains("://") else { return nil }
        return "tonkeeper://\(path)"
    }

    private static func isTrackingURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "go.tonkeeper.com" || host == "link.tonkeeper.com" {
            return true
        }
        return host == "app.link" || host.hasSuffix(".app.link")
    }

    private static func isInAppURL(_ url: URL, scheme: String) -> Bool {
        if scheme == "tonkeeper" || scheme == "keeper" || scheme == "tonkeeper-mob" || scheme == "ton" {
            return true
        }
        guard scheme == "https" || scheme == "http" else { return false }
        let host = url.host?.lowercased()
        return host == "app.tonkeeper.com" || host == "app.tonkeeper.org" || host == "app.keeperwallet.com"
    }
}
