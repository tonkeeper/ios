import ChainKit
import Foundation
import KeeperCoreSensitive

struct WalletConnectSigningContext {
    let signer: MultichainTransferSigner
    let wallet: Wallet
    let mnemonicAccess: MnemonicAccess
    let client: CryptoKitClient
    let pendingTransactionsService: PendingTransactionsService
    let evmFee: WalletConnectEVMFee?
    private let requestGuard: WalletConnectRequestGuard
    private let submission = WalletConnectTransactionSubmission()

    init(
        signer: MultichainTransferSigner,
        wallet: Wallet,
        mnemonicAccess: MnemonicAccess,
        client: CryptoKitClient,
        pendingTransactionsService: PendingTransactionsService,
        evmFee: WalletConnectEVMFee?,
        isPending: @escaping @Sendable () async -> Bool = { true }
    ) {
        let requestGuard = WalletConnectRequestGuard(isPending: isPending)
        self.requestGuard = requestGuard
        switch signer {
        case .mnemonic:
            self.signer = signer
        case let .device(device):
            self.signer = .device(requestGuard.guarding(device))
        }
        self.wallet = wallet
        self.mnemonicAccess = mnemonicAccess
        self.client = client
        self.pendingTransactionsService = pendingTransactionsService
        self.evmFee = evmFee
    }

    func checkRequestIsPending() async throws(WalletConnectSigningError) {
        do {
            try await requestGuard.check()
        } catch {
            if await submission.wasSubmitted {
                throw .requestEndedAfterBroadcast
            }
            throw .canceled
        }
    }

    func reportPendingTransaction(
        chain: WalletConnectChain,
        txHash: String,
        activityType: MultichainPendingTransaction.ActivityType
    ) async {
        await submission.record()
        await pendingTransactionsService.record(
            .chain(
                chain.multichainChain,
                wallet: wallet,
                txHashes: [txHash],
                activityType: activityType
            ),
            wallet: wallet
        )
    }

    func cryptoWallet() async throws(WalletConnectSigningError) -> MnemonicWallet {
        guard case let .mnemonic(passcodeProvider) = signer else {
            throw .unsupportedWalletKind
        }
        try await checkRequestIsPending()
        guard let passcode = await passcodeProvider() else {
            throw .canceled
        }

        try await checkRequestIsPending()
        let mnemonic: CoreMnemonic
        do {
            mnemonic = try await mnemonicAccess.getMnemonic(
                wallet: wallet,
                passcode: passcode
            )
        } catch {
            try await checkRequestIsPending()
            throw .mnemonic(reason: "failed to read mnemonic for WalletConnect: \(error.logDescription)")
        }
        try await checkRequestIsPending()
        do {
            return try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic.mnemonicWords.joined(separator: " "))
        } catch {
            throw .mnemonic(reason: "failed to read mnemonic for WalletConnect: \(error.logDescription)")
        }
    }

    func accountAddress(
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) -> String {
        let multichainChain = chain.multichainChain
        let preferredType = wallet.preferredMultichainAddressType(for: multichainChain)
        guard case let .multichain(state) = wallet.multichain,
              let address = state.address(for: multichainChain, preferredType: preferredType)
        else {
            throw .missingMultichainAddress(chain: chain, walletId: wallet.id)
        }
        return address
    }

    func chainKitAccount(
        chain: WalletConnectChain,
        cryptoWallet: MnemonicWallet
    ) throws(WalletConnectSigningError) -> ChainKit.Account {
        try chainKitAccount(chain: chain, publicKey: cryptoWallet.getPublicKey(chain: chain.multichainChain.asChainKitChain))
    }

    /// The account with the key its address was saved with, as a hardware wallet reported it.
    func storedChainKitAccount(chain: WalletConnectChain) throws(WalletConnectSigningError) -> ChainKit.Account {
        try chainKitAccount(chain: chain, publicKey: storedPublicKey(chain: chain).chainKitPubKey)
    }

    func storedPublicKey(chain: WalletConnectChain) throws(WalletConnectSigningError) -> MultichainPublicKey {
        let multichainChain = chain.multichainChain
        guard let publicKey = wallet.multichainWalletState?
            .walletAddress(for: multichainChain, preferredType: wallet.preferredMultichainAddressType(for: multichainChain))?
            .publicKey
        else {
            throw .missingMultichainAddress(chain: chain, walletId: wallet.id)
        }
        return publicKey
    }

    private func chainKitAccount(
        chain: WalletConnectChain,
        publicKey: PubKey
    ) throws(WalletConnectSigningError) -> ChainKit.Account {
        let chainKitChain = chain.multichainChain.asChainKitChain
        let addressString = try accountAddress(chain: chain)
        guard let address = Address.Companion.shared.from(value: addressString, chain: chainKitChain, type: .default_) else {
            throw .invalidTransaction(reason: "invalid sender address: \(addressString)")
        }
        return ChainKit.Account(
            address: address,
            asset: chainKitChain.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: publicKey
        )
    }

    func validateSameAddress(
        expected: String,
        actual: String,
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) {
        let lhs = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = actual.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSame = chain.eip155ChainId != nil
            ? lhs.caseInsensitiveCompare(rhs) == .orderedSame
            : lhs == rhs
        guard isSame else {
            throw .senderAddressMismatch(expected: expected, actual: actual)
        }
    }

    func validateAddress(
        _ address: String?,
        chain: WalletConnectChain
    ) throws(WalletConnectSigningError) {
        guard let address, !address.isEmpty else {
            return
        }
        try validateSameAddress(
            expected: accountAddress(chain: chain),
            actual: address,
            chain: chain
        )
    }
}

private actor WalletConnectTransactionSubmission {
    private(set) var wasSubmitted = false

    func record() {
        wasSubmitted = true
    }
}

private struct WalletConnectRequestGuard: Sendable {
    let isPending: @Sendable () async -> Bool

    func check() async throws {
        guard !Task.isCancelled, await isPending(), !Task.isCancelled else {
            throw CancellationError()
        }
    }

    func guarding(_ device: DeviceTransferSigner) -> DeviceTransferSigner {
        DeviceTransferSigner(
            evm: { input in try await checked { try await device.evm(input) } },
            tron: { input in try await checked { try await device.tron(input) } },
            solana: { input in try await checked { try await device.solana(input) } },
            bitcoin: { input in try await checked { try await device.bitcoin(input) } },
            ton: { input in try await checked { try await device.ton(input) } },
            evmMessage: { input in try await checked { try await device.evmMessage(input) } },
            evmTypedData: { domain, message in try await checked { try await device.evmTypedData(domain, message) } },
            tronMessage: { input in try await checked { try await device.tronMessage(input) } }
        )
    }

    private func checked<T>(_ sign: () async throws -> T) async throws -> T {
        try await check()
        let result = try await sign()
        try await check()
        return result
    }
}
