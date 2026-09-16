import Foundation
import StoreKit

final class StorefrontCountryCodeCache: @unchecked Sendable {
    private typealias CountryCodeProvider = @Sendable () async -> String?
    private static let unavailableCountryCodeRetryInterval: TimeInterval = 1

    private let lock = NSLock()
    private let countryCodeProvider: CountryCodeProvider
    private let currentDate: @Sendable () -> Date
    private var resolution: Resolution?
    private var loadTask: Task<String?, Never>?

    init() {
        countryCodeProvider = {
            await Storefront.current
                .map(\.countryCode)
                .flatMap(Locale.current.alpha2Code(fromIsoCode:))
        }
        currentDate = { Date() }
    }

    init(
        countryCodeProvider: @escaping @Sendable () async -> String?,
        currentDate: @escaping @Sendable () -> Date
    ) {
        self.countryCodeProvider = countryCodeProvider
        self.currentDate = currentDate
    }

    var cachedCountryCode: String? {
        lock.withLock {
            resolution?.countryCode
        }
    }

    func warmUp() {
        Task {
            _ = await countryCode()
        }
    }

    func countryCode() async -> String? {
        switch loadAction() {
        case let .resolved(countryCode):
            return countryCode
        case let .load(task):
            return await task.value
        }
    }

    private enum LoadAction {
        case resolved(String?)
        case load(Task<String?, Never>)
    }

    private enum Resolution {
        case resolved(String)
        case unavailable(retryAfter: Date)

        var countryCode: String? {
            guard case let .resolved(countryCode) = self else {
                return nil
            }
            return countryCode
        }

        func loadAction(at date: Date) -> LoadAction? {
            switch self {
            case let .resolved(countryCode):
                .resolved(countryCode)
            case let .unavailable(retryAfter) where date < retryAfter:
                .resolved(nil)
            case .unavailable:
                nil
            }
        }
    }

    private func loadAction() -> LoadAction {
        lock.withLock {
            if let loadAction = resolution?.loadAction(at: currentDate()) {
                return loadAction
            }
            if let loadTask {
                return .load(loadTask)
            }
            let countryCodeProvider = self.countryCodeProvider
            let task = Task { [weak self] in
                let countryCode = await countryCodeProvider()
                self?.store(countryCode)
                return countryCode
            }
            loadTask = task
            return .load(task)
        }
    }

    private func store(_ countryCode: String?) {
        lock.withLock {
            resolution = countryCode.map(Resolution.resolved)
                ?? .unavailable(
                    retryAfter: currentDate().addingTimeInterval(
                        Self.unavailableCountryCodeRetryInterval
                    )
                )
            loadTask = nil
        }
    }
}

private extension Locale {
    private static let availableRegions = Locale.availableIdentifiers.map(Locale.init(identifier:))

    func alpha2Code(fromIsoCode isoCode: String) -> String? {
        let regionName = localizedString(forRegionCode: isoCode) ?? ""
        return Self.availableRegions.first {
            localizedString(forRegionCode: $0.regionCode ?? "") == regionName
        }?.regionCode
    }
}
