import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

extension MainCoordinator {
    func openSendResolvingMultichain(
        wallet: Wallet,
        sendInput: SendInput,
        sendSource: SendAnalyticsSource,
        transactionSentNotificationPatch: @Sendable @escaping (inout [String: Any]) -> Void = { _ in },
        recipient: LegacyRecipient? = nil,
        comment: String?,
        successReturn: URL? = nil
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            guard let multichainState = multichainSendState(for: wallet),
                  let seed = sendInput.multichainSeed()
            else {
                openSend(
                    wallet: wallet,
                    sendInput: sendInput,
                    sendSource: sendSource,
                    transactionSentNotificationPatch: transactionSentNotificationPatch,
                    recipient: recipient,
                    comment: comment,
                    successReturn: successReturn
                )
                return
            }

            guard let input = await multichainSendInput(
                wallet: wallet,
                multichainState: multichainState,
                assetId: seed.assetId,
                amount: seed.amount
            ) else {
                showMultichainSendLoadError()
                return
            }

            var multichainRecipient: MultichainRecipient?
            if let recipient, let chain = input.item.asset.asset.chain {
                multichainRecipient = MultichainRecipient(
                    string: recipient.stringValue,
                    chain: chain,
                    network: wallet.network
                )
            }

            openMultichainSend(
                wallet: wallet,
                multichainState: multichainState,
                entry: .enterAmount(input),
                sendSource: sendSource,
                transactionSentNotificationPatch: transactionSentNotificationPatch,
                recipient: multichainRecipient,
                comment: comment,
                successReturn: successReturn
            )
        }
    }

    func openSendWithTokenPicker(
        wallet: Wallet,
        sendSource: SendAnalyticsSource
    ) {
        guard let multichainState = multichainSendState(for: wallet) else {
            openSend(
                wallet: wallet,
                sendInput: .direct(item: .ton(.token(.ton, amount: 0))),
                sendSource: sendSource,
                comment: nil
            )
            return
        }

        openMultichainSend(
            wallet: wallet,
            multichainState: multichainState,
            entry: .tokenPicker(allowedChains: nil, initialChain: nil),
            sendSource: sendSource,
            comment: nil
        )
    }
}

extension MainCoordinator {
    func multichainSendState(for wallet: Wallet) -> MultichainWalletState? {
        guard wallet.network.isMainnet,
              let state = wallet.multichainWalletState
        else {
            return nil
        }
        return state
    }

    func multichainSendInput(
        wallet: Wallet,
        multichainState: MultichainWalletState,
        assetId: String,
        amount: BigUInt
    ) async -> MultichainSendInput? {
        let assetResolver = MultichainSendAssetResolver(
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService()
        )

        guard let asset = await assetResolver.resolveAsset(
            for: assetId,
            multichainState: multichainState
        ) else {
            return nil
        }

        guard keeperCoreMainAssembly.multichainAssembly.chainKitService.isTransferSupported(asset: asset) else {
            return nil
        }

        return MultichainSendInput(
            item: MultichainSendItem(
                asset: asset,
                amount: amount
            )
        )
    }

    func showMultichainSendLoadError() {
        ToastPresenter.showToast(
            configuration: ToastPresenter.Configuration(
                title: TKLocales.Trade.Assets.Errors.load
            )
        )
    }
}
