import Foundation
import KeeperCore
import LedgerKit
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

/// Signs on the Ledger a wallet was paired with: each request shows the steps sheet over the top of `presenter`,
/// once the multichain Ledger is rolled out. Until then it toasts `unavailableTitle`.
struct LedgerDeviceSigner {
    private let device: Wallet.LedgerDevice
    private let unavailableTitle: String
    private let featureFlags: TKFeatureFlags
    private let transport: LedgerKit.LedgerTransport
    private let presenter: @MainActor () -> UIViewController?

    /// `nil` for a wallet that is not on a Ledger.
    static func signer(
        for wallet: Wallet,
        unavailableTitle: String = TKLocales.LedgerSteps.unavailable,
        coreAssembly: TKCore.CoreAssembly,
        presenter: @escaping @MainActor () -> UIViewController?
    ) -> DeviceTransferSigner? {
        guard case let .Ledger(tonPublicKey, _, device) = wallet.identity.kind else {
            return nil
        }
        let ledger = LedgerDeviceSigner(
            device: device,
            unavailableTitle: unavailableTitle,
            featureFlags: coreAssembly.featureFlags,
            transport: coreAssembly.ledgerAssembly.transport,
            presenter: presenter
        )
        let account = Int(device.accountIndex)
        return DeviceTransferSigner(
            evm: { request in
                try await ledger.perform(.ethereumTransaction(request, account: account))
            },
            tron: { rawData in
                try await ledger.perform(.tronTransaction(rawData, account: account))
            },
            solana: { message in
                try await ledger.perform(.solanaTransaction(message, account: account))
            },
            bitcoin: { request in
                try await ledger.perform(.bitcoinTransaction(request, account: account))
            },
            ton: { transactions in
                try await ledger.perform(.tonTransactions(transactions, publicKey: tonPublicKey, account: account))
            },
            evmMessage: { message in
                try await ledger.perform(.ethereumMessage(message, account: account))
            },
            evmTypedData: { domainSeparator, messageHash in
                try await ledger.perform(.ethereumTypedData(domainSeparator: domainSeparator, messageHash: messageHash, account: account))
            },
            tronMessage: { message in
                try await ledger.perform(.tronMessage(message, account: account))
            }
        )
    }

    @MainActor
    private func perform<Value>(_ steps: LedgerSteps<Value>) async throws -> Value {
        guard featureFlags[.ledgerMultichain] else {
            ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: unavailableTitle))
            throw CancellationError()
        }
        guard let peripheralID = UUID(uuidString: device.deviceId) else {
            throw LedgerTransportError.peripheralNotFound
        }
        guard let viewController = presenter()?.topPresentedViewController() else {
            throw CancellationError()
        }
        return try await steps.perform(peripheralID: peripheralID, transport: transport, from: viewController)
    }
}
