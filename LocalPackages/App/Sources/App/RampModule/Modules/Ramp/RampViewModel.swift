import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

public protocol RampModuleOutput: AnyObject {
    var didTapReceiveTokens: (() -> Void)? { get set }
    var didTapSendTokens: (() -> Void)? { get set }
    var didTapItem: ((RampAsset, OnRampLayout) -> Void)? { get set }
    var didClose: (() -> Void)? { get set }
}

public protocol RampModuleInput: AnyObject {}

protocol RampViewModel: AnyObject {
    var sectionHeaderTitle: String { get }
    var didUpdateSnapshot: ((RampViewController.Snapshot) -> Void)? { get set }
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }

    func viewDidLoad()
    func didSelect(item: RampViewController.Item)
    func didTapCloseButton()
}

final class RampViewModelImplementation: RampViewModel, RampModuleOutput, RampModuleInput {
    var didTapReceiveTokens: (() -> Void)?
    var didTapSendTokens: (() -> Void)?
    var didTapItem: ((RampAsset, OnRampLayout) -> Void)?
    var didClose: (() -> Void)?

    var didUpdateSnapshot: ((RampViewController.Snapshot) -> Void)?
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?

    let flow: RampFlow
    private let wallet: Wallet
    private let configuration: Configuration
    private let onRampService: OnRampService

    var onRampLayout: OnRampLayout?
    var isOnRampLayoutLoading = true

    init(
        flow: RampFlow,
        wallet: Wallet,
        configuration: Configuration,
        onRampService: OnRampService
    ) {
        self.flow = flow
        self.wallet = wallet
        self.configuration = configuration
        self.onRampService = onRampService
    }

    func viewDidLoad() {
        didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: flow.title))
        buildSnapshot()
        Task { await loadOnRampLayout() }
    }

    @MainActor
    private func loadOnRampLayout() async {
        do {
            onRampLayout = try await onRampService
                .getLayout(flow: flow.api, currency: nil)
                .filteredByCashOrCryptoAvailability(isAvailable: wallet.isRampCashOrCryptoAvailable)
                .filteredByTRC20Availability(isAvailable: wallet.isTronAvailable)
            isOnRampLayoutLoading = false
            buildSnapshot()
        } catch {
            onRampLayout = nil
            isOnRampLayoutLoading = false
            buildSnapshot()
        }
    }

    func didSelect(item: RampViewController.Item) {
        switch item {
        case .receiveTokens:
            didTapReceiveTokens?()
        case .sendTokens:
            didTapSendTokens?()
        case let .tokenItem(asset, _):
            if let onRampLayout {
                didTapItem?(asset, onRampLayout)
            }
        case .shimmer:
            break
        }
    }

    func didTapCloseButton() {
        didClose?()
    }
}
