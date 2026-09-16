import Foundation

public struct TKFontFeatures: Hashable, Sendable {
    enum StylisticSet: String, CaseIterable, Sendable {
        case alternateLowercase = "ss07"
        case alternateCapitalG = "ss09"
        case alternateAt = "ss17"
        case alternateAmpersand = "ss18"
    }

    public static let display = TKFontFeatures(
        stylisticSets: [.alternateCapitalG, .alternateAt, .alternateAmpersand]
    )

    public static let text = TKFontFeatures(
        stylisticSets: [.alternateLowercase, .alternateCapitalG, .alternateAt, .alternateAmpersand]
    )

    let stylisticSets: [StylisticSet]
}
