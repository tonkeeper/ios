import Foundation
import PerpsModels

/// `Store` fans out a typed event, but every perps screen reacts to "something changed"
/// and re-reads the state. The ports carry that narrower contract so the feature package
/// never sees `Store` itself.
extension PerpsMarketsStore: PerpsMarketsStoring {
    public func addChangeObserver<T: AnyObject>(_ observer: T, onChange: @escaping (T) -> Void) {
        addObserver(observer) { observer, _ in onChange(observer) }
    }
}

extension PerpsMarketDetailsStore: PerpsMarketDetailsStoring {
    public func addChangeObserver<T: AnyObject>(_ observer: T, onChange: @escaping (T) -> Void) {
        addObserver(observer) { observer, _ in onChange(observer) }
    }
}

extension PerpsAccountStore: PerpsAccountStoring {
    public func addChangeObserver<T: AnyObject>(_ observer: T, onChange: @escaping (T) -> Void) {
        addObserver(observer) { observer, _ in onChange(observer) }
    }
}
