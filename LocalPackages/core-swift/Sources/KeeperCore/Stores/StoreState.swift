import Foundation

public final class StoreState<T>: @unchecked Sendable {
    public var value: T {
        get {
            lock.withLock {
                if needToSetInitialState {
                    _value = initialState()
                    needToSetInitialState = false
                }
                return _value
            }
        }
        set {
            lock.withLock {
                needToSetInitialState = false
                _value = newValue
            }
        }
    }

    private lazy var lock = NSLock()
    private var _value: T
    private let initialState: () -> T
    private var needToSetInitialState = true

    init(value: T, initialState: @escaping () -> T) {
        self._value = value
        self.initialState = initialState
    }
}
