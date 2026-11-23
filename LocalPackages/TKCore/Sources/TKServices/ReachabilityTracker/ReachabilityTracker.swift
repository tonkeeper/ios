import Foundation
import Network

public protocol ReachabilityTrackerObserver: AnyObject {
    func didUpdateState(_ state: ReachabilityTracker.State)
}

public final class ReachabilityTracker {
    public enum State {
        case noInternetConnection
        case connected
    }

    struct ReachabilityTrackerObserverWrapper {
        weak var observer: ReachabilityTrackerObserver?
    }

    public enum InterfaceType {
        case wifi
        case cellular
        case wired
        case other
        case none
    }

    private let pathMonitor = NWPathMonitor()
    public private(set) var interfaceType = InterfaceType.other
    public private(set) var state = State.connected {
        didSet {
            guard state != oldValue else { return }
            notifyObservers(state)
        }
    }

    private var observers = [ReachabilityTrackerObserverWrapper]()

    package init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.interfaceType = Self.interfaceType(for: path)
            self?.state = Self.state(for: path)
        }
        pathMonitor.start(queue: .main)
    }

    deinit {
        pathMonitor.cancel()
    }

    public func addObserver(_ observer: ReachabilityTrackerObserver) {
        observers.append(.init(observer: observer))
    }
}

private extension ReachabilityTracker {
    func notifyObservers(_ state: State) {
        observers = observers.filter { $0.observer != nil }
        observers.forEach { $0.observer?.didUpdateState(state) }
    }

    static func state(for path: NWPath) -> State {
        guard path.status == .satisfied else {
            return .noInternetConnection
        }
        return internetCapableInterfaceTypes.contains(where: path.usesInterfaceType)
            ? .connected
            : .noInternetConnection
    }

    static func interfaceType(for path: NWPath) -> InterfaceType {
        guard path.status == .satisfied else { return .none }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        return .other
    }

    static var internetCapableInterfaceTypes: [NWInterface.InterfaceType] {
        [.wifi, .cellular, .wiredEthernet]
    }
}
