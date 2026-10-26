import CoreText
import TKLogging
import UIKit

public extension UIFont {
    static func tkBold(size: CGFloat, features: TKFontFeatures) -> UIFont {
        tkFont(.bold, size: size, features: features)
    }

    static func tkMedium(size: CGFloat, features: TKFontFeatures) -> UIFont {
        tkFont(.medium, size: size, features: features)
    }

    static func tkRegular(size: CGFloat, features: TKFontFeatures) -> UIFont {
        tkFont(.regular, size: size, features: features)
    }

    /// Same font with tabular lining figures (`tnum`+`lnum`), keeping the original family.
    /// Digits then share a fixed width, so live countdowns and numeric values don't jitter as they change.
    func monospacedDigits() -> UIFont {
        addingFeatureSettings([
            [
                UIFontDescriptor.FeatureKey.type.rawValue: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector.rawValue: kMonospacedNumbersSelector,
            ],
            [
                UIFontDescriptor.FeatureKey.type.rawValue: kNumberCaseType,
                UIFontDescriptor.FeatureKey.selector.rawValue: kUpperCaseNumbersSelector,
            ],
        ])
    }

    private static func tkFont(_ face: TKFontFace, size: CGFloat, features: TKFontFeatures) -> UIFont {
        guard let font = UIFont(name: face.name, size: size) else {
            return .systemFont(ofSize: size, weight: face.systemWeight)
        }
        return font
            .withStandardFallback(face.cascade)
            .applying(features)
    }

    /// `addingAttributes` overwrites `.featureSettings` wholesale, so a later call would drop the
    /// stylistic sets baked in at construction. Merge instead of replace.
    private func addingFeatureSettings(_ settings: [[String: Any]]) -> UIFont {
        guard !settings.isEmpty else { return self }
        let existing = fontDescriptor.fontAttributes[.featureSettings] as? [[String: Any]] ?? []
        let descriptor = fontDescriptor.addingAttributes([.featureSettings: existing + settings])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension UIFont {
    func applying(_ features: TKFontFeatures) -> UIFont {
        addingFeatureSettings(features.stylisticSets.map {
            [
                kCTFontOpenTypeFeatureTag as String: $0.rawValue,
                kCTFontOpenTypeFeatureValue as String: 1,
            ]
        })
    }
}

enum FontError: LoggableError {
    case missingFile
    case unreadableFile
    case registrationFailed((any Error)?)

    var logDescription: String {
        let description = LogDescription(type: FontError.self)
        switch self {
        case .missingFile:
            return description.with("case", "missingFile").text
        case .unreadableFile:
            return description.with("case", "unreadableFile").text
        case let .registrationFailed(error):
            return description.with("case", "registrationFailed").with("underlying", error: error).text
        }
    }
}

func registerFont(file: TKUIKitFontFile) throws(FontError) {
    if UIFont(name: file.fontName, size: 1) != nil {
        return
    }

    guard let fontURL = file.url else {
        throw .missingFile
    }
    guard
        let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
        let font = CGFont(fontDataProvider)
    else {
        throw .unreadableFile
    }
    var registrationError: Unmanaged<CFError>?
    guard CTFontManagerRegisterGraphicsFont(font, &registrationError) else {
        let nsError = registrationError.map {
            $0.takeRetainedValue() as Error as NSError
        }
        if nsError?.domain == kCTFontManagerErrorDomain as String,
           nsError?.code == CTFontManagerError.alreadyRegistered.rawValue
        {
            return
        }
        throw .registrationFailed(nsError)
    }
}

private struct TKFontFace {
    static let bold = TKFontFace(file: .ttfirsneueDmbd, systemWeight: .bold)
    static let medium = TKFontFace(file: .ttfirsneueMd, systemWeight: .semibold)
    static let regular = TKFontFace(file: .ttfirsneueNm, systemWeight: .medium)

    let name: String
    let systemWeight: UIFont.Weight
    /// An explicit cascade replaces the default one, so the face keeps its own default chain and gets
    /// the system font in front of it for U+2009, the thin space of formatted amounts: TT Firs Neue
    /// lacks it, and Helvetica, heading the default chain, draws it as a hair space. The system font's
    /// own chain is not borrowed: its CJK entries are private UI fonts that iOS 18 renders as boxes.
    let cascade: [UIFontDescriptor]

    init(file: TKUIKitFontFile, systemWeight: UIFont.Weight) {
        do {
            try registerFont(file: file)
        } catch {
            Log.e("failed to register font", error: error, extraInfo: ["font": file.fontName])
        }
        let defaultCascade = UIFont(name: file.fontName, size: UIFont.systemFontSize).flatMap {
            CTFontCopyDefaultCascadeListForLanguages($0 as CTFont, nil) as? [UIFontDescriptor]
        } ?? []
        let systemFont = UIFont.systemFont(ofSize: UIFont.systemFontSize, weight: systemWeight)
        name = file.fontName
        self.systemWeight = systemWeight
        cascade = defaultCascade.isEmpty ? [] : [systemFont.fontDescriptor] + defaultCascade
    }
}

private extension UIFont {
    func withStandardFallback(_ cascade: [UIFontDescriptor]) -> UIFont {
        guard !cascade.isEmpty else { return self }
        let descriptor = fontDescriptor.addingAttributes(
            [UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String): cascade]
        )
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
