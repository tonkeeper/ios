import CoreText
import UIKit

public extension UIFont {
    static func tkBold(size: CGFloat, features: TKFontFeatures) -> UIFont {
        tkFont(named: tkBoldFontName, size: size, fallbackWeight: .bold, features: features)
    }

    static func tkMedium(size: CGFloat, features: TKFontFeatures) -> UIFont {
        tkFont(named: tkMediumFontName, size: size, fallbackWeight: .semibold, features: features)
    }

    static func tkRegular(size: CGFloat, features: TKFontFeatures) -> UIFont {
        tkFont(named: tkRegularFontName, size: size, fallbackWeight: .medium, features: features)
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

    private static func tkFont(
        named name: String,
        size: CGFloat,
        fallbackWeight: UIFont.Weight,
        features: TKFontFeatures
    ) -> UIFont {
        guard let font = UIFont(name: name, size: size) else {
            return .systemFont(ofSize: size, weight: fallbackWeight)
        }
        return font
            .withStandardFallback()
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

    private static let tkBoldFontName = registeredFontName(for: .ttfirsneueDmbd)
    private static let tkMediumFontName = registeredFontName(for: .ttfirsneueMd)
    private static let tkRegularFontName = registeredFontName(for: .ttfirsneueNm)

    private static func registeredFontName(for file: TKUIKitFontFile) -> String {
        do {
            try registerFont(file: file)
            return file.fontName
        } catch {
            fatalError("Failed to register font: \(file.fontName)")
        }
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

enum FontError: Error {
    case failedToRegisterFont
}

func registerFont(file: TKUIKitFontFile) throws(FontError) {
    if UIFont(name: file.fontName, size: 1) != nil {
        return
    }

    guard
        let fontURL = file.url,
        let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
        let font = CGFont(fontDataProvider)
    else {
        throw .failedToRegisterFont
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
        throw .failedToRegisterFont
    }
}

private extension UIFont {
    /// A font registered with `CTFontManagerRegisterGraphicsFont` carries no cascade list, so a
    /// codepoint it lacks is dropped with a zero advance instead of being substituted. TT Firs Neue
    /// has no U+2009, which is the thin space every formatted amount puts between the currency
    /// symbol and the number, so those gaps collapsed to nothing. Borrowing the system font's
    /// cascade restores the standard fallback chain — and keeps emoji and non-Latin scripts
    /// resolving as before, which hardcoding a single donor font would not.
    func withStandardFallback() -> UIFont {
        guard !Self.standardCascadeList.isEmpty else { return self }
        let descriptor = fontDescriptor.addingAttributes(
            [UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String): Self.standardCascadeList]
        )
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    static let standardCascadeList: [UIFontDescriptor] = {
        let system = UIFont.systemFont(ofSize: UIFont.systemFontSize) as CTFont
        return CTFontCopyDefaultCascadeListForLanguages(system, nil) as? [UIFontDescriptor] ?? []
    }()
}
