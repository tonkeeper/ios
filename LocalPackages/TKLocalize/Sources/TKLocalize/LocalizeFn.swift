import Foundation

let DEFAULT_LOCALE = "en"

public func localizeDefaultLocale(_ key: String) -> String {
    guard
        let path = Bundle.module.path(forResource: DEFAULT_LOCALE, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else { return key }
    
    return bundle.localizedString(forKey: key, value: nil, table: nil)
}

public func localize(_ key: String, comment: String = "") -> String {
    let bundle = Bundle.module
    let value = bundle.localizedString(forKey: key, value: nil, table: nil)
    
    if value != key {
        return value
    }
    
    return localizeDefaultLocale(key)
}
