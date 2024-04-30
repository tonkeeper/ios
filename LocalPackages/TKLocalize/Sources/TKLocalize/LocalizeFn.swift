import Foundation

let DEFAULT_LOCALE = "en"

public func localize(_ key: String, comment: String = "", bundle: Bundle = Bundle.main) -> String {
    let value = NSLocalizedString(key, bundle: bundle, comment: comment)

    if value != key || NSLocale.autoupdatingCurrent.identifier == DEFAULT_LOCALE {
        return value
    }

    // Fallback to default locale
    guard
        let path = bundle.path(forResource: DEFAULT_LOCALE, ofType: "lproj"),
        let defaultLangBundle = Bundle(path: path)
    else { return value }
    return translate(key, bundle: defaultLangBundle)
}
