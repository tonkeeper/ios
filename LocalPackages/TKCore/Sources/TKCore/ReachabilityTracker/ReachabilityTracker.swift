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

    private let pathMonitor = NWPathMonitor()
    public private(set) var state = State.connected {
        didSet {
            guard state != oldValue else { return }
            notifyObservers(state)
        }
    }

    private var observers = [ReachabilityTrackerObserverWrapper]()

    init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
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

    static var internetCapableInterfaceTypes: [NWInterface.InterfaceType] {
        [.wifi, .cellular, .wiredEthernet]
    }
}
