import Foundation

public struct KeysCountryCodeProvider {
    private let countryCodeSource: () -> String?

    public init(countryCodeSource: @escaping () -> String?) {
        self.countryCodeSource = countryCodeSource
    }

    public var keysCountryCode: String? {
        countryCodeSource()?.uppercased()
    }
}
