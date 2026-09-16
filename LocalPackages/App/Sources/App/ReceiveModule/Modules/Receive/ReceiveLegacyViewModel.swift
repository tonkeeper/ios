import Foundation
import KeeperCore
import TKCore
import TKLocalize

protocol ReceiveLegacyViewModel: AnyObject {
    var didUpdateTokenViewController: ((ReceiveTabViewController, _ animated: Bool) -> Void)? { get set }
    var didUpdateSegmentedControl: (([String]?) -> Void)? { get set }
    var didChangeIndex: ((Int) -> Void)? { get set }
    func viewDidLoad()
    func setActiveIndex(_ from: Int, _ to: Int)
    func close()
}

final class ReceiveLegacyViewModelImplementation: ReceiveLegacyViewModel, ReceiveModuleOutput, ReceiveModuleInput {
    var didRequestClose: (() -> Void)?
    var didDisplayToken: ((ReceiveLegacyToken) -> Void)?

    var didUpdateTokenViewController: ((ReceiveTabViewController, _ animated: Bool) -> Void)?
    var didUpdateSegmentedControl: (([String]?) -> Void)?
    var didChangeIndex: ((Int) -> Void)?

    private var activeTokenIndex = 0

    private let tokens: [ReceiveLegacyToken]
    private let tokenModuleViewControllerProvider: (ReceiveLegacyToken) -> ReceiveTabViewController

    init(
        tokens: [ReceiveLegacyToken],
        initialToken: ReceiveLegacyToken? = nil,
        tokenModuleViewControllerProvider: @escaping (ReceiveLegacyToken) -> ReceiveTabViewController
    ) {
        self.tokens = tokens
        self.tokenModuleViewControllerProvider = tokenModuleViewControllerProvider
        if let initialToken, let index = tokens.firstIndex(of: initialToken) {
            activeTokenIndex = index
        }
    }

    func viewDidLoad() {
        setup()
    }

    func setActiveIndex(_ from: Int, _ to: Int) {
        let index = min(tokens.count - 1, max(0, to))
        activeTokenIndex = index
        setupTokenPage(animated: true)
    }

    func close() {
        didRequestClose?()
    }
}

private extension ReceiveLegacyViewModelImplementation {
    func setup() {
        guard !tokens.isEmpty else { return }
        setupSegmentedControl()
        // Reflect a non-default preselection on the control; guarded to >1 tab because a
        // single-token receive has no segmented control to index into.
        if tokens.count > 1, activeTokenIndex != 0 {
            didChangeIndex?(activeTokenIndex)
        }
        setupTokenPage(animated: false)
    }

    func setupTokenPage(animated: Bool) {
        let token = tokens[activeTokenIndex]
        let tokenViewController = tokenModuleViewControllerProvider(token)
        didUpdateTokenViewController?(tokenViewController, animated)
        didDisplayToken?(token)
    }

    func setupSegmentedControl() {
        if tokens.count > 1 {
            let segmentedControlItems = tokens.map {
                switch $0 {
                case .ton:
                    TKLocales.Receive.Multichain.Networks.Ton.title
                case .tron:
                    TKLocales.Receive.Segments.trc20
                }
            }
            didUpdateSegmentedControl?(segmentedControlItems)
        } else {
            didUpdateSegmentedControl?(nil)
        }
    }
}
