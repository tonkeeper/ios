import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TronSwift
import UIKit

public protocol ReceiveModuleOutput: AnyObject {
    var didSelectInactiveTRC20: ((Wallet) -> Void)? { get set }
}

public protocol ReceiveModuleInput: AnyObject {
    func selectToken(token: Token)
}

protocol ReceiveViewModel: AnyObject {
    var didUpdateTokenViewController: ((ReceiveTabViewController, _ animated: Bool) -> Void)? { get set }
    var didUpdateSegmentedControl: (([String]?) -> Void)? { get set }
    var didChangeIndex: ((Int) -> Void)? { get set }

    func viewDidLoad()
    func setActiveIndex(_ from: Int, _ to: Int)
}

final class ReceiveViewModelImplementation: ReceiveViewModel, ReceiveModuleOutput, ReceiveModuleInput {
    var didSelectInactiveTRC20: ((Wallet) -> Void)?

    var didUpdateTokenViewController: ((ReceiveTabViewController, _ animated: Bool) -> Void)?
    var didUpdateSegmentedControl: (([String]?) -> Void)?
    var didChangeIndex: ((Int) -> Void)?

    // MARK: - State

    private var activeTokenIndex: Int = 0

    // MARK: - Dependencies

    private let tokens: [Token]
    private var wallet: Wallet
    private let walletsStore: WalletsStore
    private let tokenModuleViewControllerProvider: (Token) -> ReceiveTabViewController

    init(
        tokens: [Token],
        wallet: Wallet,
        walletsStore: WalletsStore,
        tokenModuleViewControllerProvider: @escaping (Token) -> ReceiveTabViewController
    ) {
        self.tokens = tokens
        self.wallet = wallet
        self.walletsStore = walletsStore
        self.tokenModuleViewControllerProvider = tokenModuleViewControllerProvider
    }

    func viewDidLoad() {
        setup()
    }

    func setActiveIndex(_ from: Int, _ to: Int) {
        let index = min(tokens.count - 1, max(0, to))
        if case .tron = tokens[index], !wallet.isTronTurnOn {
            didChangeIndex?(from)
            didSelectInactiveTRC20?(wallet)
            return
        }
        activeTokenIndex = index
        setupTokenPage(animated: true)
    }

    func selectToken(token: Token) {
        guard let index = tokens.index(of: token) else { return }
        activeTokenIndex = index
        setupTokenPage(animated: true)
        didChangeIndex?(index)
    }

    private func setup() {
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateWalletTron(wallet):
                DispatchQueue.main.async {
                    guard wallet == observer.wallet else { return }
                    observer.wallet = wallet
                }
            default: break
            }
        }

        guard !tokens.isEmpty else { return }
        setupSegmentedControl()
        setupTokenPage(animated: false)
    }

    private func setupTokenPage(animated: Bool) {
        let token = tokens[activeTokenIndex]
        let tokenViewController = tokenModuleViewControllerProvider(token)
        didUpdateTokenViewController?(tokenViewController, animated)
    }

    private func setupSegmentedControl() {
        if tokens.count > 1 {
            let segmentedControlItems = tokens.map {
                switch $0 {
                case .ton: "TON"
                case .tron: "TRC20"
                }
            }
            didUpdateSegmentedControl?(segmentedControlItems)
        } else {
            didUpdateSegmentedControl?(nil)
        }
    }
}
