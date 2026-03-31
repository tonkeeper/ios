import Foundation

protocol P2PExpressDoNotShowAgainStore: AnyObject {
    var doNotShowAgain: Bool { get set }
}

final class P2PExpressUserDefaultsDoNotShowAgainStore: P2PExpressDoNotShowAgainStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var doNotShowAgain: Bool {
        get {
            userDefaults.bool(forKey: .doNotShowAgainKey)
        }
        set {
            userDefaults.set(newValue, forKey: .doNotShowAgainKey)
        }
    }
}

private extension String {
    static let doNotShowAgainKey = "p2p_express_popup_do_not_show_again"
}
