import BigInt
import Foundation
import TKLogging
import TonAPI
import TonSwift

public enum LinkDNSEmulation {
    case confirmation(SendTransactionModel)
    case insufficientFunds(required: BigUInt, available: BigUInt)
}

public final class LinkDNSController {
    public enum Error: Swift.Error {
        case failedToSign
        case indexerOffline
    }

    /// The API rejects emulation the wallet balance cannot cover, so the operation is emulated
    /// against an overridden balance and the shortage is reported from the wallet balance instead.
    private static let emulationBalance: Int64 = 2_000_000_000

    private let wallet: Wallet
    private let nft: NFT
    private let sendService: SendService
    private let balanceStore: BalanceStore
    private let balanceService: BalanceService

    init(
        wallet: Wallet,
        nft: NFT,
        sendService: SendService,
        balanceStore: BalanceStore,
        balanceService: BalanceService
    ) {
        self.wallet = wallet
        self.nft = nft
        self.sendService = sendService
        self.balanceStore = balanceStore
        self.balanceService = balanceService
    }

    public func emulate(dnsLink: DNSLink) async throws -> LinkDNSEmulation {
        let signedTransactions = try await createSignedTransactions(dnsLink: dnsLink) { transferData in
            let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
                .createUnsignedWalletTransfer(
                    wallet: wallet
                )
            let signed = try TransferSigner.signWalletTransfer(
                walletTransfer,
                wallet: wallet,
                seqno: transferData.seqno,
                signer: WalletTransferEmptyKeySigner()
            )

            return try [signed.toBoc().hexString()]
        }

        let boc = signedTransactions[0]
        let walletAddress = try wallet.address

        let transactionInfo = try await sendService.loadTransactionInfo(
            boc: boc,
            wallet: wallet,
            params: [
                EmulateMessageToWalletRequestParamsInner(
                    address: walletAddress.toRaw(),
                    balance: Self.emulationBalance
                ),
            ],
            currency: nil
        )

        let model = try SendTransactionModel(
            accountEvent: transactionInfo.event,
            risk: transactionInfo.risk,
            transaction: transactionInfo.trace.transaction
        )

        guard let available = await availableTonBalance() else {
            return .confirmation(model)
        }

        let required = requiredAmount(for: transactionInfo)
        guard required <= available else {
            return .insufficientFunds(required: required, available: available)
        }

        return .confirmation(model)
    }

    public func sendLinkTransaction(
        dnsLink: DNSLink,
        signClosure: (TransferData) async throws -> SignedTransactions
    ) async throws {
        let indexingLatency = try await sendService.getIndexingLatency(wallet: wallet)
        if indexingLatency > (TonSwift.DEFAULT_TTL - 30) {
            throw Error.indexerOffline
        }

        let signedTransactions = try await createSignedTransactions(dnsLink: dnsLink) { transferData in
            try await signClosure(transferData)
        }

        if signedTransactions.isEmpty {
            throw Error.failedToSign
        }

        do {
            if signedTransactions.count == 1 {
                try await sendService.sendTransaction(boc: signedTransactions[0], wallet: wallet)
            } else {
                try await sendService.sendTransactions(batch: signedTransactions.bocs, wallet: wallet)
            }
            NotificationCenter.default.postTransactionSendNotification(wallet: wallet)
        } catch {
            throw error
        }
    }
}

private extension LinkDNSController {
    /// What the wallet has to hold when the message is sent: the Gram the operation puts at
    /// stake plus its fee. Change comes back only after the transaction lands.
    func requiredAmount(for transactionInfo: MessageConsequences) -> BigUInt {
        BigUInt(max(transactionInfo.risk.gram, 0))
            + BigUInt(max(transactionInfo.trace.transaction.totalFees, 0))
    }

    /// A stale or missing snapshot would either block a funded wallet or wave an empty one through
    /// to a broadcast that cannot succeed, so anything but a fresh balance is loaded again.
    func availableTonBalance() async -> BigUInt? {
        let storedState = balanceStore.getState()[wallet]
        if case let .current(walletBalance) = storedState {
            return tonAmount(of: walletBalance)
        }

        do {
            let walletBalance = try await balanceService.loadWalletBalance(
                wallet: wallet,
                currency: .USD,
                includingTransferFees: false
            )
            return tonAmount(of: walletBalance)
        } catch {
            Log.w("failed to load wallet balance for dns link due to error: \(error)")
            return storedState.map { tonAmount(of: $0.walletBalance) }
        }
    }

    func tonAmount(of walletBalance: WalletBalance) -> BigUInt {
        BigUInt(max(walletBalance.balance.tonBalance.amount, 0))
    }

    func createSignedTransactions(dnsLink: DNSLink, signClosure: (TransferData) async throws -> SignedTransactions) async throws -> SignedTransactions {
        let seqno = try await sendService.loadSeqno(wallet: wallet)
        let timeout = await sendService.getTimeoutSafely(wallet: wallet, TTL: DEFAULT_TTL)
        let linkAmount = OP_AMOUNT.CHANGE_DNS_RECORD
        let linkAddress: Address?
        switch dnsLink {
        case let .link(address):
            linkAddress = address.address
        case .unlink:
            linkAddress = nil
        }

        let transferData = TransferData(
            transfer: .changeDNSRecord(TransferData.ChangeDNSRecord.link(TransferData.ChangeDNSRecord.LinkDNS(nftAddress: nft.address, linkAddress: linkAddress, linkAmount: linkAmount))),
            wallet: wallet,
            messageType: .ext,
            seqno: seqno,
            timeout: timeout
        )

        return try await signClosure(transferData)
    }
}

public enum OP_AMOUNT {
    public static var CHANGE_DNS_RECORD = BigUInt(stringLiteral: "020000000")
}
