import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLogging
import TKUIKit
import TonSwift
import TronSwift
import UIKit

protocol ReceiveLegacyTokenConvertible {
    var receiveLegacyToken: ReceiveLegacyToken? { get }
}

extension Token: ReceiveLegacyTokenConvertible {
    var receiveLegacyToken: ReceiveLegacyToken? {
        switch self {
        case let .ton(ton):
            .ton(ton)
        case let .tron(tron):
            .tron(tron)
        }
    }
}

enum ReceiveLegacyToken: Equatable, Hashable {
    case ton(TonToken)
    case tron(TronToken)
}

struct ReceiveAddressPreview {
    struct Asset {
        enum Icon {
            case image(UIImage?)
            case url(URL?)
        }

        let address: String?
        let name: String
        let symbol: String
        let icon: Icon

        init(
            address: String?,
            name: String,
            symbol: String,
            icon: Icon
        ) {
            self.address = address
            self.name = name
            self.symbol = symbol
            self.icon = icon
        }
    }

    let chain: MultichainChain
    let address: String
    let type: MultichainWalletAddressType?
    let qrPayload: String
    let asset: Asset?

    init(
        address: MultichainWalletAddress,
        qrPayload: String? = nil,
        asset: Asset? = nil
    ) {
        self.chain = address.chain
        self.address = address.address
        self.type = address.type
        self.qrPayload = qrPayload ?? address.address
        self.asset = asset
    }

    var walletAddress: MultichainWalletAddress {
        MultichainWalletAddress(
            chain: chain,
            address: address,
            type: type
        )
    }
}

extension ReceiveLegacyToken {
    var token: Token {
        switch self {
        case let .ton(ton):
            .ton(ton)
        case let .tron(tron):
            .tron(tron)
        }
    }
}

@MainActor
struct ReceiveModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func createReceiveCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        token: Token,
        wallet: Wallet
    ) -> ReceiveCoordinator? {
        if let state = multichainReceiveState(for: wallet) {
            if let address = receiveAddressPreview(for: token, state: state, wallet: wallet) {
                return createReceiveCoordinator(
                    router: router,
                    wallet: wallet,
                    address: address
                )
            }

            let chain = token.multichainReceiveChain
            Log.w("failed to find multichain receive address for chain \(chain.rawValue), wallet \(wallet.id)")
            return nil
        }

        return createLegacyReceiveCoordinator(
            router: router,
            tokens: [token],
            wallet: wallet,
            didDisplayToken: nil
        )
    }

    func createReceiveCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        tokens: [ReceiveLegacyTokenConvertible],
        wallet: Wallet,
        preselected: ReceiveLegacyTokenConvertible? = nil,
        didDisplayToken: ((Token) -> Void)? = nil
    ) -> ReceiveCoordinator {
        if let addresses = multichainReceiveAddresses(for: wallet) {
            return createReceiveCoordinator(
                router: router,
                wallet: wallet,
                addresses: addresses.map { ReceiveAddressPreview(address: $0) }
            )
        }

        return createLegacyReceiveCoordinator(
            router: router,
            tokens: tokens,
            initialToken: preselected?.receiveLegacyToken,
            wallet: wallet,
            didDisplayToken: didDisplayToken
        )
    }

    func createReceiveCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        wallet: Wallet,
        address: ReceiveAddressPreview
    ) -> ReceiveCoordinator {
        MultichainReceiveCoordinator(
            router: router,
            addresses: .single(address),
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            didCopyAddress: copyAddressHandler(wallet: wallet)
        )
    }

    func createReceiveCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        wallet: Wallet,
        addresses: [ReceiveAddressPreview]
    ) -> ReceiveCoordinator {
        MultichainReceiveCoordinator(
            router: router,
            addresses: .multi(addresses),
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            didCopyAddress: copyAddressHandler(wallet: wallet)
        )
    }
}

private extension ReceiveModule {
    func createLegacyReceiveCoordinator<V: UIViewController>(
        router: ContainerViewControllerRouter<V>,
        tokens: [ReceiveLegacyTokenConvertible],
        initialToken: ReceiveLegacyToken? = nil,
        wallet: Wallet,
        didDisplayToken: ((Token) -> Void)? = nil
    ) -> ReceiveCoordinator {
        LegacyReceiveCoordinator(
            router: router,
            tokens: tokens.compactMap {
                guard let token = $0.receiveLegacyToken else {
                    Log.w("failed to map token \($0) to receive legacy token")
                    return nil
                }
                return token
            },
            initialToken: initialToken,
            wallet: wallet,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly,
            didDisplayToken: didDisplayToken
        )
    }

    func multichainReceiveState(for wallet: Wallet) -> MultichainWalletState? {
        wallet.multichainWalletState
    }

    func multichainReceiveAddresses(for wallet: Wallet) -> [MultichainWalletAddress]? {
        guard let state = multichainReceiveState(for: wallet) else {
            return nil
        }
        let addresses = state.addresses
            .filter { address in
                guard address.chain == .ton else {
                    return true
                }
                return address.type == wallet.preferredMultichainAddressType(for: .ton)
            }
            .sorted { $0.chain.displayOrderIndex < $1.chain.displayOrderIndex }
        return addresses.isEmpty ? nil : addresses
    }

    func receiveAddressPreview(
        for token: Token,
        state: MultichainWalletState,
        wallet: Wallet
    ) -> ReceiveAddressPreview? {
        let chain = token.multichainReceiveChain
        guard let address = state.walletAddress(
            for: chain,
            preferredType: wallet.preferredMultichainAddressType(for: chain)
        ) else {
            return nil
        }

        return token.receiveAddressPreview(
            walletAddress: address,
            deeplinkGenerator: DeeplinkGenerator()
        )
    }

    func copyAddressHandler(wallet: Wallet) -> (String) -> Void {
        { address in
            Task { @MainActor in
                Pasteboard.copy(value: address, toast: wallet.copyToastConfiguration())
            }
        }
    }
}

extension ReceiveModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
        }
    }
}

private extension Token {
    var multichainReceiveChain: MultichainChain {
        switch self {
        case .ton:
            return .ton
        case .tron:
            return .tron
        }
    }

    func receiveAddressPreview(
        walletAddress: MultichainWalletAddress,
        deeplinkGenerator: DeeplinkGenerator
    ) -> ReceiveAddressPreview {
        switch self {
        case .ton(.ton):
            return ReceiveAddressPreview(address: walletAddress)
        case let .ton(.jetton(jettonItem)):
            let qrPayload = (try? deeplinkGenerator.generateTransferDeeplink(
                with: walletAddress.address,
                jettonAddress: jettonItem.jettonInfo.address
            )) ?? walletAddress.address

            return ReceiveAddressPreview(
                address: walletAddress,
                qrPayload: qrPayload,
                asset: ReceiveAddressPreview.Asset(
                    address: jettonItem.jettonInfo.address.toRaw(),
                    name: jettonItem.jettonInfo.name,
                    symbol: jettonItem.jettonInfo.symbol ?? "",
                    icon: .url(jettonItem.jettonInfo.imageURL)
                )
            )
        case .tron(.trx):
            return ReceiveAddressPreview(address: walletAddress)
        case .tron(.usdt):
            return ReceiveAddressPreview(
                address: walletAddress,
                asset: ReceiveAddressPreview.Asset(
                    address: TronSwift.USDT.address.base58,
                    name: TronSwift.USDT.name,
                    symbol: TronSwift.USDT.symbol,
                    icon: .image(.TKUIKit.Icons.Size44.currencyUsdt)
                )
            )
        }
    }
}
