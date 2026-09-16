@testable import TKCore
import XCTest

final class StorefrontCountryCodeCacheTests: XCTestCase {
    func test_countryCodeCachesUnavailableStorefrontUntilRetryTime() async {
        let provider = CountryCodeProviderSpy(values: [nil, "US"])
        let dateProvider = CurrentDateProvider()
        let cache = StorefrontCountryCodeCache(
            countryCodeProvider: { await provider.countryCode() },
            currentDate: { dateProvider.currentDate() }
        )

        let firstCountryCode = await cache.countryCode()
        let secondCountryCode = await cache.countryCode()
        dateProvider.advance(by: 1)
        let cachedCountryCode = await cache.countryCode()

        XCTAssertNil(firstCountryCode)
        XCTAssertNil(secondCountryCode)
        XCTAssertEqual(cachedCountryCode, "US")
        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 2)
    }
}

private final class CurrentDateProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date()

    func currentDate() -> Date {
        lock.withLock {
            date
        }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            date.addTimeInterval(interval)
        }
    }
}

private actor CountryCodeProviderSpy {
    private var values: [String?]
    private(set) var callCount = 0

    init(values: [String?]) {
        self.values = values
    }

    func countryCode() -> String? {
        callCount += 1
        return values.removeFirst()
    }
}
