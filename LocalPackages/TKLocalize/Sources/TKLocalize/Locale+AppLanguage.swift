import Foundation

public extension Locale {
    static var appLanguage: Locale {
        appLanguage(
            preferredLocalizations: Bundle.main.preferredLocalizations,
            developmentLocalization: Bundle.main.developmentLocalization,
            fallback: .current
        )
    }
}

extension Locale {
    static func appLanguage(
        preferredLocalizations: [String],
        developmentLocalization: String?,
        fallback: Locale
    ) -> Locale {
        let identifier = preferredLocalizations.first {
            !$0.isEmpty && $0 != "Base"
        } ?? developmentLocalization

        guard let identifier, !identifier.isEmpty else {
            return fallback
        }

        return Locale(identifier: identifier)
    }
}
