import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

struct WalletConnectProposalAssembly {
    private init() {}

    @MainActor
    static func module(
        proposal: WalletConnectSessionProposal,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<
        WalletConnectProposalHostingViewController,
        WalletConnectProposalModuleOutput,
        WalletConnectProposalModuleInput
    > {
        let contentProvider: (Wallet) -> WalletConnectProposalContent = { wallet in
            makeContent(
                proposal: proposal,
                wallet: wallet,
                keeperCoreMainAssembly: keeperCoreMainAssembly
            )
        }
        let viewModel = WalletConnectProposalViewModel(
            wallet: wallet,
            content: contentProvider(wallet),
            contentProvider: contentProvider
        )
        let viewController = WalletConnectProposalHostingViewController(
            proposalId: proposal.id,
            pairingTopic: proposal.pairingTopic,
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: viewModel)
    }
}

private extension WalletConnectProposalAssembly {
    static func makeContent(
        proposal: WalletConnectSessionProposal,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> WalletConnectProposalContent {
        let namespaces = proposal.approvableNamespaces(wallet: wallet)
        let chains = orderedUniqueChains(in: namespaces)
        let items = chains.compactMap { chain -> WalletConnectProposalChainItem? in
            guard let address = wallet.walletConnectAddress(for: chain) else {
                return nil
            }
            return WalletConnectProposalChainItem(
                chain: chain,
                cellContent: WalletConnectChainCellContent(
                    title: chain.multichainChain.shortDisplayTitle,
                    address: shortAddress(address),
                    icon: chain.multichainChain.tokenIcon44
                )
            )
        }

        let totalBalance = keeperCoreMainAssembly
            .storesAssembly
            .totalBalanceStore
            .state[wallet]?
            .totalBalance

        let balanceText = totalBalance.map {
            keeperCoreMainAssembly.formattersAssembly.amountFormatter.format(
                decimal: $0.amount,
                accessory: .fiat($0.currency),
                style: .fiatBalance
            )
        }

        let dappHost = dappHost(for: proposal.dapp)
        let dappName = proposal.dapp.name.isEmpty ? dappHost : proposal.dapp.name
        // Full, not shortened: the header tickers it sideways, and an ellipsis mid-address reads as a
        // rendering glitch once it scrolls past.
        let walletAddress = chains
            .compactMap { wallet.walletConnectAddress(for: $0) }
            .first
            ?? ""

        return WalletConnectProposalContent(
            dappName: dappName,
            dappHost: dappHost,
            dappURL: dappURL(for: proposal.dapp),
            dappIconURL: proposal.dapp.iconURL.flatMap(URL.init(string:)),
            walletTitle: wallet.label,
            walletBalance: balanceText,
            walletAddress: walletAddress,
            validation: proposal.validation,
            canApprove: proposal.canBeApproved(wallet: wallet),
            permissions: WalletConnectProposalPermissionItem.items(
                methods: Set(namespaces.flatMap(\.methods))
            ),
            chains: items
        )
    }

    static func dappHost(for dapp: WalletConnectDapp) -> String {
        guard !dapp.url.isEmpty else {
            return dapp.name.isEmpty ? TKLocales.WalletConnect.Common.dapp : dapp.name
        }
        return URL(string: dapp.url)?.host ?? dapp.url
    }

    static func dappURL(for dapp: WalletConnectDapp) -> URL? {
        let urlString = dapp.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return nil }

        if let url = URL(string: urlString),
           url.scheme != nil
        {
            return url
        }

        if urlString.hasPrefix("//") {
            return URL(string: "https:\(urlString)")
        }

        return URL(string: "https://\(urlString)")
    }

    static func shortAddress(_ address: String) -> String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }

    static func orderedUniqueChains(
        in namespaces: [WalletConnectProposalNamespace]
    ) -> [WalletConnectChain] {
        var result = [WalletConnectChain]()
        for chain in namespaces.flatMap(\.chains) where !result.contains(chain) {
            result.append(chain)
        }
        return result
    }
}
