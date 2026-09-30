import BigInt
import Foundation
import KeeperCoreComponents
import TKBatteryAPI
import TKLogging
import TonAPI
import TonSwift

public enum TransferError: Swift.Error {
    case nothingToSend
    case unsupportedTransfer
    case failedToCreateTransferData(
        message: String?
    )
    case noExcessesAddress
    case noJettonWalletAddress
    case sendFailed(
        message: String?
    )
}

public struct TransferEmulationResult {
    public struct Extra {
        public enum Amount {
            case fee(BigUInt)
            case refund(BigUInt)
        }

        public let token: TonToken
        public let amount: Amount
        public let excess: UInt?
    }

    public let transferType: TransferType
    public let extra: Extra
    public let transactionInfo: MessageConsequences?
    public let isGaslessAvailable: Bool
}

public enum TransferType {
    case `default`
    case battery(excessAddress: Address)
    case gasless(excessAddress: Address, fee: BigUInt)

    public var isBattery: Bool {
        switch self {
        case .default, .gasless:
            return false
        case .battery:
            return true
        }
    }

    public var isGasless: Bool {
        switch self {
        case .default, .battery:
            return false
        case .gasless:
            return true
        }
    }

    public var excessAddress: Address? {
        switch self {
        case .default:
            return nil
        case let .battery(excessAddress):
            return excessAddress
        case let .gasless(excessAddress, _):
            return excessAddress
        }
    }
}

public struct TransferService {
    private let batteryService: BatteryService
    private let balanceService: BalanceService
    private let sendService: SendService
    private let accountService: AccountService
    private let configuration: Configuration
    private let currencyStore: CurrencyStore

    init(
        batteryService: BatteryService,
        balanceService: BalanceService,
        sendService: SendService,
        accountService: AccountService,
        configuration: Configuration,
        settingsRepository: SettingsRepository,
        currencyStore: CurrencyStore
    ) {
        self.batteryService = batteryService
        self.balanceService = balanceService
        self.sendService = sendService
        self.accountService = accountService
        self.configuration = configuration
        self.currencyStore = currencyStore
    }

    private func adjustExcessAddressIfNeeded(
        wallet: Wallet,
        transferType: TransferType
    ) async throws(TransferError) -> TransferType {
        guard case .battery = transferType else {
            return transferType
        }
        func getTransferType(
            from address: @autoclosure () throws -> Address
        ) throws(TransferError) -> TransferType {
            let excessAddress: Address
            do {
                excessAddress = try address()
            } catch {
                throw .failedToCreateTransferData(
                    message: "battery transfer: failed to get excess address due to error: \(error.localizedDescription)"
                )
            }
            return .battery(excessAddress: excessAddress)
        }
        let batteryConfig: Components.Schemas.Config
        do {
            batteryConfig = try await batteryService.loadBatteryConfig(
                wallet: wallet
            )
        } catch {
            Log.w("adjust excess address: failed to fetch battery config")
            return try getTransferType(from: wallet.address)
        }
        do {
            return try getTransferType(from: batteryConfig.excessAddress)
        } catch {
            Log.w("adjust excess address: failed to parse battery config excess address")
            return try getTransferType(from: wallet.address)
        }
    }

    @discardableResult
    public func sendTransaction<SignError: Error>(
        wallet: Wallet,
        transfer: Transfer,
        transferType rawTransferType: TransferType,
        signClosure: (TransferData) async -> Result<SignedTransactions, SignError>
    ) async throws(SomeOf<TransferError, SignError>) -> SignedTransactions {
        let transferType: TransferType
        do {
            // TODO: kinda bullshit, should do something with this
            transferType = try await adjustExcessAddressIfNeeded(
                wallet: wallet,
                transferType: rawTransferType
            )
        } catch {
            throw .certain(error)
        }
        return try await doSendTransaction(
            wallet: wallet,
            transfer: transfer,
            transferType: transferType,
            signClosure: signClosure
        )
    }

    @discardableResult
    private func doSendTransaction<SignError: Error>(
        wallet: Wallet,
        transfer: Transfer,
        transferType: TransferType,
        signClosure: (TransferData) async -> Result<SignedTransactions, SignError>
    ) async throws(SomeOf<TransferError, SignError>) -> SignedTransactions {
        let seqno: UInt64
        do {
            seqno = try await sendService.loadSeqno(wallet: wallet)
        } catch {
            throw .certain(
                .failedToCreateTransferData(message: "failed to get seqno due to error: \(error.localizedDescription)")
            )
        }

        let transferData: TransferData
        do {
            transferData = try await createTransferData(
                wallet: wallet,
                transfer: transfer,
                seqno: seqno,
                transferType: transferType
            )
        } catch {
            throw .certain(error)
        }
        let signedTransactions: SignedTransactions
        do {
            signedTransactions = try await signClosure(transferData).get()
        } catch {
            throw .certain(error)
        }

        if signedTransactions.isEmpty {
            throw .certain(.nothingToSend)
        }

        let route = Self.broadcastRoute(transfer: transfer, transferType: transferType)
        do {
            try await broadcast(
                signedTransactions,
                wallet: wallet,
                route: route,
                transferType: transferType
            )
        } catch {
            throw .certain(error)
        }

        return signedTransactions
    }

    enum BroadcastRoute: Equatable {
        case tonAPI
        case batteryRelay
        case batteryTransport
    }

    static func broadcastRoute(
        transfer: Transfer,
        transferType: TransferType
    ) -> BroadcastRoute {
        switch transferType {
        case .battery, .gasless:
            return .batteryRelay
        case .default:
            return transfer.broadcastsThroughBattery ? .batteryTransport : .tonAPI
        }
    }

    private func broadcast(
        _ signedTransactions: SignedTransactions,
        wallet: Wallet,
        route: BroadcastRoute,
        transferType: TransferType
    ) async throws(TransferError) {
        switch route {
        case .tonAPI:
            try await broadcastThroughTonAPI(signedTransactions, wallet: wallet, transferType: transferType)
        case .batteryRelay:
            do {
                try await broadcastThroughBattery(signedTransactions, wallet: wallet)
            } catch {
                throw .sendFailed(message: error.localizedDescription)
            }
        case .batteryTransport:
            do {
                try await broadcastThroughBattery(signedTransactions, wallet: wallet)
            } catch is BatteryAuthorizationError {
                Log.w("battery transport: no battery authorization, broadcasting through TONAPI")
                try await broadcastThroughTonAPI(signedTransactions, wallet: wallet, transferType: transferType)
            } catch {
                throw .sendFailed(message: error.localizedDescription)
            }
        }
    }

    private func broadcastThroughTonAPI(
        _ signedTransactions: SignedTransactions,
        wallet: Wallet,
        transferType: TransferType
    ) async throws(TransferError) {
        do {
            if signedTransactions.count == 1 {
                try await sendService.sendTransaction(boc: signedTransactions[0], wallet: wallet)
            } else {
                try await sendService.sendTransactions(batch: signedTransactions.bocs, wallet: wallet)
            }
        } catch {
            let kind = signedTransactions.count == 1 ? "single" : "batch"
            throw .sendFailed(
                message: "failed to \(kind) \(transferType.analyticsName) send due to error: \(error.localizedDescription)"
            )
        }
    }

    private func broadcastThroughBattery(
        _ signedTransactions: SignedTransactions,
        wallet: Wallet
    ) async throws {
        for boc in signedTransactions {
            try await batteryService.sendTransaction(
                wallet: wallet,
                boc: boc,
                proof: signedTransactions.batterySendProof(for: boc)
            )
        }
    }

    public func emulate(
        wallet: Wallet,
        transfer: Transfer,
        params: [EmulateMessageToWalletRequestParamsInner]? = nil,
        ignoreGasless: Bool = false,
        withoutRelayer: Bool = false,
        isPreferGasless: Bool = true
    ) async throws -> TransferEmulationResult {
        let isRelayer = await isRelayerAvailable(wallet: wallet, transfer: transfer)
        let batteryConfig = try? await batteryService.loadBatteryConfig(wallet: wallet)
        let isGaslessToken = await isGaslessToken(wallet: wallet, transfer: transfer)

        let isGaslessAvailable = await isGaslessAvailable(wallet: wallet, transfer: transfer)

        if ignoreGasless && withoutRelayer {
            return try await defaultEmulate(
                wallet: wallet,
                transfer: transfer,
                params: params,
                isGaslessAvailable: isGaslessAvailable
            )
        } else if isRelayer,
                  !withoutRelayer,
                  await configuration.isBatteryEnable(network: wallet.network),
                  await configuration.isBatterySendEnable(network: wallet.network)
        {
            do {
                return try await emulateWithBattery(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: wallet.address,
                    transferType: .battery(excessAddress: wallet.address)
                )
            } catch {
                return try await emulate(
                    wallet: wallet,
                    transfer: transfer,
                    params: params,
                    withoutRelayer: true,
                    isPreferGasless: isPreferGasless
                )
            }
        } else if !ignoreGasless,
                  wallet.isGaslessAvailable,
                  isPreferGasless,
                  let excessesAddress = try? batteryConfig?.excessAddress,
                  isGaslessToken
        {
            do {
                return try await emulateWithGasless(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: excessesAddress,
                    transferType: .gasless(excessAddress: excessesAddress, fee: 1)
                )
            } catch {
                return try await emulate(
                    wallet: wallet,
                    transfer: transfer,
                    params: params,
                    ignoreGasless: true
                )
            }
        } else {
            let result = try await defaultEmulate(
                wallet: wallet,
                transfer: transfer,
                params: params,
                isGaslessAvailable: isGaslessAvailable
            )
            if case .ton = transfer {
                return result
            }

            guard wallet.isGaslessAvailable,
                  let excessesAddress = try? batteryConfig?.excessAddress,
                  isGaslessToken
            else {
                return result
            }
            let tonBalance = (try? await balanceService.loadWalletBalance(
                wallet: wallet,
                currency: .USD,
                includingTransferFees: true
            ).balance.tonBalance.amount) ?? 0

            let jettonMasterAddress: Address? = {
                if case let .jetton(jettonItem, _, _, _, _) = transfer {
                    return jettonItem.jettonInfo.address
                }
                return nil
            }()
            let transferCost = batteryConfig?.transferCost(jettonMasterAddress: jettonMasterAddress)
                ?? Components.Schemas.Config.fallbackTransferCost
            let amount = {
                switch result.extra.amount {
                case let .fee(fee):
                    return fee + transferCost
                case .refund:
                    return transferCost
                }
            }()
            guard amount > tonBalance else {
                return result
            }
            return try await emulateWithGasless(
                wallet: wallet,
                transfer: transfer,
                excessAddress: excessesAddress,
                transferType: .gasless(excessAddress: excessesAddress, fee: 1)
            )
        }
    }

    /// `includeUnavailableBattery` asks for the battery estimate even when the battery cannot pay
    /// for this transfer. Only a caller that lists fee options wants it: the option has to reach the
    /// picker to be marked insufficient and offer a refill. A caller that is *choosing* the method
    /// must leave it off, otherwise it preselects a method the user cannot confirm with.
    public func emulate(
        wallet: Wallet,
        transfer: Transfer,
        params: [EmulateMessageToWalletRequestParamsInner]? = nil,
        preferredExtraType: TransactionConfirmationModel.ExtraType,
        includeUnavailableBattery: Bool = false
    ) async throws -> TransferEmulationResult {
        do {
            switch preferredExtraType {
            case .default, .multichain:
                return try await defaultEmulate(
                    wallet: wallet,
                    transfer: transfer,
                    params: params,
                    isGaslessAvailable: false
                )
            case .battery:
                let batteryConfig = try await batteryService.loadBatteryConfig(wallet: wallet)
                guard let excessAddress = try? batteryConfig.excessAddress else { throw TransferError.noExcessesAddress }
                return try await emulateWithBattery(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: excessAddress,
                    transferType: .battery(excessAddress: excessAddress),
                    keepsUnavailableEstimate: includeUnavailableBattery
                )
            case .gasless:
                let batteryConfig = try await batteryService.loadBatteryConfig(wallet: wallet)
                guard let excessesAddress = try? batteryConfig.excessAddress else { throw TransferError.noExcessesAddress }
                return try await emulateWithGasless(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: excessesAddress,
                    transferType: .gasless(excessAddress: excessesAddress, fee: 1)
                )
            }
        } catch {
            return try await defaultEmulate(
                wallet: wallet,
                transfer: transfer,
                params: params,
                isGaslessAvailable: false
            )
        }
    }

    /// Transfer cost (in nano-TON) attached to a transfer to cover its cost,
    /// sourced from the battery config (`transfer_cost`). Uses the per-jetton
    /// override when `jettonMasterAddress` matches, otherwise the config
    /// default, falling back to the legacy 0.05 TON when the config is
    /// unavailable or contains an invalid value.
    public func transferCost(wallet: Wallet, jettonMasterAddress: Address?) async -> BigUInt {
        let config = try? await batteryService.loadBatteryConfig(wallet: wallet)
        return config?.transferCost(jettonMasterAddress: jettonMasterAddress)
            ?? Components.Schemas.Config.fallbackTransferCost
    }

    func isGaslessAvailable(wallet: Wallet, transfer: Transfer) async -> Bool {
        guard !configuration.flag(\.gaslessDisabled, network: wallet.network) else { return false }

        let isGaslessToken = await isGaslessToken(wallet: wallet, transfer: transfer)
        let batteryConfig = try? await batteryService.loadBatteryConfig(wallet: wallet)

        guard wallet.isGaslessAvailable,
              let _ = try? batteryConfig?.excessAddress,
              isGaslessToken
        else {
            return false
        }
        return true
    }

    /// Whether the wallet's settings let the battery pay for this kind of transfer at all, ignoring
    /// how many charges are left. Listing a fee option is this question; preselecting one is
    /// `isRelayerAvailable`, which also demands a balance.
    static func isRelayerEnabled(
        wallet: Wallet,
        transfer: Transfer
    ) -> Bool {
        switch transfer {
        case .ton, .renewDNS:
            return false
        case .jetton:
            return wallet.isBatteryEnable && wallet.batterySettings.isJettonTransactionEnable
        case .nft:
            return wallet.isBatteryEnable && wallet.batterySettings.isNFTTransactionEnable
        case .stonfiSwap, .nativeSwap, .multichainSwap:
            return wallet.isBatteryEnable && wallet.batterySettings.isSwapTransactionEnable
        case let .signRaw(_, isForceRelayer, _):
            return isForceRelayer
        }
    }

    func isRelayerAvailable(
        wallet: Wallet,
        transfer: Transfer
    ) async -> Bool {
        guard Self.isRelayerEnabled(wallet: wallet, transfer: transfer) else {
            return false
        }
        switch transfer {
        case .signRaw:
            // A forced relayer is the caller's decision and carries no balance precondition.
            return true
        case .ton, .jetton, .nft, .stonfiSwap, .renewDNS, .nativeSwap, .multichainSwap:
            return await isBatteryBalanceEnable(wallet: wallet)
        }
    }

    func isBatteryBalanceEnable(wallet: Wallet) async -> Bool {
        do {
            let batteryBalance = try await batteryService.loadBatteryBalance(wallet: wallet)
            let compareResult = batteryBalance.balanceDecimalNumber.compare(0)
            return compareResult == .orderedDescending
        } catch {
            return false
        }
    }

    private func emulateWithBattery(
        wallet: Wallet,
        transfer: Transfer,
        excessAddress: Address,
        transferType: TransferType,
        keepsUnavailableEstimate: Bool = false
    ) async throws -> TransferEmulationResult {
        let seqno = try await sendService.loadSeqno(wallet: wallet)
        do {
            let transferData = try await createTransferData(
                wallet: wallet,
                transfer: transfer,
                seqno: seqno,
                transferType: transferType
            )
            let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
                .createUnsignedWalletTransfer(wallet: wallet)
            let signed = try TransferSigner.signWalletTransfer(
                walletTransfer,
                wallet: wallet,
                seqno: transferData.seqno,
                signer: WalletTransferEmptyKeySigner()
            )
            do {
                let transactionInfo = try await batteryService.loadTransactionInfo(
                    wallet: wallet,
                    boc: signed.toBoc().base64EncodedString()
                )
                // `isBatteryAvailable == false` means "cannot pay right now", not "no estimate":
                // the charges are what the picker needs to mark the option insufficient.
                if transactionInfo.isBatteryAvailable || keepsUnavailableEstimate {
                    return TransferEmulationResult(
                        transferType: .battery(excessAddress: excessAddress),
                        extra: TransferEmulationResult.Extra(
                            token: .ton,
                            amount: transactionInfo.info.event.extra > 0 ?
                                .refund(BigUInt(transactionInfo.info.event.extra)) :
                                .fee(BigUInt(abs(transactionInfo.info.event.extra))),
                            excess: transactionInfo.excess
                        ),
                        transactionInfo: transactionInfo.info,
                        isGaslessAvailable: false
                    )
                } else {
                    return try await defaultEmulate(
                        wallet: wallet,
                        transfer: transfer,
                        isGaslessAvailable: false
                    )
                }
            } catch {
                return try await defaultEmulate(
                    wallet: wallet,
                    transfer: transfer,
                    isGaslessAvailable: false
                )
            }
        } catch {
            throw error
        }
    }

    private func emulateWithGasless(
        wallet: Wallet,
        transfer: Transfer,
        excessAddress: Address,
        transferType: TransferType
    ) async throws -> TransferEmulationResult {
        guard case let .jetton(jettonItem, _, _, _, _) = transfer else {
            throw TransferError.unsupportedTransfer
        }

        let seqno = try await sendService.loadSeqno(wallet: wallet)
        let transferData = try await createTransferData(
            wallet: wallet,
            transfer: transfer,
            seqno: seqno,
            transferType: transferType
        )
        let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(wallet: wallet)
        let signed = try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: transferData.seqno,
            signer: WalletTransferEmptyKeySigner()
        )

        let comission = try await batteryService.loadGasslessCommission(
            wallet: wallet,
            jettonMasterAddress: jettonItem.jettonInfo.address.toRaw(),
            boc: signed.toBoc().base64EncodedString()
        )
        let fee = BigUInt(stringLiteral: comission)
        return TransferEmulationResult(
            transferType: .gasless(excessAddress: excessAddress, fee: fee),
            extra: TransferEmulationResult.Extra(token: .jetton(jettonItem), amount: .fee(fee), excess: nil),
            transactionInfo: nil,
            isGaslessAvailable: true
        )
    }

    private func defaultEmulate(
        wallet: Wallet,
        transfer: Transfer,
        params: [EmulateMessageToWalletRequestParamsInner]? = nil,
        isGaslessAvailable: Bool
    ) async throws -> TransferEmulationResult {
        let seqno = try await sendService.loadSeqno(wallet: wallet)
        let transferData = try await createTransferData(
            wallet: wallet,
            transfer: transfer,
            seqno: seqno,
            transferType: .default
        )
        let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(wallet: wallet)
        let signed = try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: transferData.seqno,
            signer: WalletTransferEmptyKeySigner()
        )
        let transactionInfo = try await sendService.loadTransactionInfo(
            boc: signed.toBoc().hexString(),
            wallet: wallet,
            params: params,
            currency: currencyStore.state
        )
        return TransferEmulationResult(
            transferType: .default,
            extra: TransferEmulationResult.Extra(
                token: .ton,
                amount: transactionInfo.event.extra > 0 ?
                    .refund(BigUInt(transactionInfo.event.extra)) :
                    .fee(BigUInt(abs(transactionInfo.event.extra))),
                excess: nil
            ),
            transactionInfo: transactionInfo,
            isGaslessAvailable: isGaslessAvailable
        )
    }

    private func createTransferData(
        wallet: Wallet,
        transfer: Transfer,
        seqno: UInt64,
        transferType: TransferType
    ) async throws(TransferError) -> TransferData {
        let safelyTimeout = await sendService.getTimeoutSafely(wallet: wallet, TTL: DEFAULT_TTL)
        let messageType: MessageType = {
            switch transferType {
            case .default:
                return .ext
            case .battery:
                return wallet.isW5Generation ? .int : .ext
            case .gasless:
                return .int
            }
        }()
        let responseAddress: Address? = transferType.excessAddress

        switch transfer {
        case let .ton(amount, recipient, comment):
            let account = try? await accountService.loadAccount(network: wallet.network, address: recipient.recipientAddress.address)
            let shouldForceBounceFalse = ["empty", "uninit", "nonexist"].contains(account?.status)
            let isMax = await {
                do {
                    let balance = try await balanceService.loadWalletBalance(
                        wallet: wallet,
                        currency: .USD,
                        includingTransferFees: true
                    )
                    return BigUInt(balance.balance.tonBalance.amount) == amount
                } catch {
                    return false
                }
            }()
            return TransferData(
                transfer: .ton(
                    TransferData.Ton(
                        amount: amount,
                        isMax: isMax,
                        recipient: recipient.recipientAddress.address,
                        isBouncable: shouldForceBounceFalse ? false : recipient.recipientAddress.isBouncable,
                        comment: comment
                    )
                ),
                wallet: wallet,
                messageType: messageType,
                seqno: seqno,
                timeout: safelyTimeout
            )
        case let .jetton(jettonItem, transferAmount, amount, recipient, comment):
            guard let jettonWalletAddress = jettonItem.walletAddress else {
                throw TransferError.noJettonWalletAddress
            }

            var customPayload: Cell?
            var stateInit: TonSwift.StateInit?

            if jettonItem.jettonInfo.hasCustomPayload,
               let payload = try? await sendService.getJettonCustomPayload(
                   wallet: wallet,
                   jetton: jettonItem.jettonInfo.address
               )
            {
                customPayload = payload.customPayload
                if let payloadStateInit = payload.stateInit {
                    stateInit = try? StateInit.loadFrom(slice: payloadStateInit.beginParse())
                }
            }

            var additionalInternalMessages = [MessageRelaxed]()
            if case let .gasless(excessAddress, fee) = transferType {
                let customPayload = Builder()
                do {
                    try customPayload.store(uint: OpCodes.GASLESS, bits: 32)

                    additionalInternalMessages = try [
                        JettonTransferMessage.internalMessage(
                            jettonAddress: jettonWalletAddress,
                            amount: BigInt(fee),
                            bounce: true,
                            to: excessAddress,
                            from: excessAddress,
                            forwardPayload: customPayload.endCell()
                        ),
                    ]
                } catch {
                    throw .failedToCreateTransferData(
                        message: "failed to build gasless custom payload due to error: \(error.localizedDescription)"
                    )
                }
            }

            return TransferData(
                transfer: .jetton(
                    TransferData.Jetton(
                        transferAmount: transferAmount,
                        jettonAddress: jettonWalletAddress,
                        amount: amount,
                        recipient: recipient.recipientAddress.address,
                        responseAddress: responseAddress,
                        comment: comment,
                        customPayload: customPayload,
                        stateInit: stateInit,
                        additionalInternalMessages: additionalInternalMessages
                    )
                ),
                wallet: wallet,
                messageType: messageType,
                seqno: seqno,
                timeout: safelyTimeout
            )
        case let .nft(nft, transferAmount, recipient, comment):
            var commentCell: Cell?
            if let comment {
                do {
                    commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
                } catch {
                    throw .failedToCreateTransferData(
                        message: "failed to build nft comment cell due to error: \(error.localizedDescription)"
                    )
                }
            }

            return TransferData(
                transfer: .nft(
                    TransferData.NFT(
                        nftAddress: nft.address,
                        recipient: recipient.recipientAddress.address,
                        responseAddress: responseAddress,
                        isBouncable: true,
                        transferAmount: transferAmount.magnitude,
                        forwardPayload: commentCell
                    )
                ),
                wallet: wallet,
                messageType: messageType,
                seqno: seqno,
                timeout: safelyTimeout
            )
        case let .stonfiSwap(signRawRequest), let .multichainSwap(signRawRequest):
            let transferData: TransferData
            do {
                transferData = try TransferData(
                    transfer: await createTransferDataTransfer(
                        wallet: wallet,
                        signRawRequest: signRawRequest,
                        seqno: seqno,
                        transferType: transferType,
                        keepsPayloadExcessAddress: transfer.keepsPayloadExcessAddress
                    ),
                    wallet: wallet,
                    messageType: messageType,
                    seqno: seqno,
                    timeout: safelyTimeout
                )
            } catch {
                throw .failedToCreateTransferData(
                    message: "failed to build swap transfer data due to error: \(error.localizedDescription)"
                )
            }
            return transferData
        case let .signRaw(signRawRequest, _, _):
            let transferData: TransferData
            do {
                transferData = try TransferData(
                    transfer: await createTransferDataTransfer(
                        wallet: wallet,
                        signRawRequest: signRawRequest,
                        seqno: seqno,
                        transferType: transferType
                    ),
                    wallet: wallet,
                    messageType: messageType,
                    seqno: seqno,
                    timeout: {
                        guard let validUntil = signRawRequest.validUntil else {
                            return safelyTimeout
                        }

                        return min(UInt64(validUntil), safelyTimeout)
                    }()
                )
            } catch {
                throw .failedToCreateTransferData(
                    message: "failed to build tonconnect request transfer data due to error: \(error.localizedDescription)"
                )
            }
            return transferData
        case let .renewDNS(nft):
            return TransferData(
                transfer: TransferData.Transfer.changeDNSRecord(
                    .renew(
                        TransferData.ChangeDNSRecord.RenewDNS(
                            nftAddress: nft.address,
                            linkAmount: OP_AMOUNT.CHANGE_DNS_RECORD
                        )
                    )
                ),
                wallet: wallet,
                messageType: messageType,
                seqno: seqno,
                timeout: safelyTimeout
            )
        case let .nativeSwap(model):
            let payloads = try model.messages
                .map { message throws(TransferError) in
                    try TransferData.TonConnect.Payload(
                        value: BigInt(message.sendAmount) ?? 0,
                        recipientAddress: message.targetAddress,
                        stateInit: nil,
                        payload: nativeSwapPayload(
                            message.payload,
                            excessAddress: transferType.excessAddress
                        )
                    )
                }
            return TransferData(
                transfer: .tonConnect(TransferData.TonConnect(
                    payloads: payloads,
                    sender: nil
                )),
                wallet: wallet,
                messageType: messageType,
                seqno: seqno,
                timeout: safelyTimeout
            )
        }
    }

    private func createTransferDataTransfer(
        wallet: Wallet,
        signRawRequest: SignRawRequest,
        seqno: UInt64,
        transferType: TransferType,
        keepsPayloadExcessAddress: Bool = false
    ) async throws -> TransferData.Transfer {
        let payloads = try await getTonconnectPayloads(
            wallet: wallet,
            signRawRequest: signRawRequest,
            transferType: transferType,
            keepsPayloadExcessAddress: keepsPayloadExcessAddress
        )

        return TransferData.Transfer.tonConnect(
            TransferData.TonConnect(
                payloads: payloads,
                sender: signRawRequest.from
            )
        )
    }

    private func getTonconnectPayloads(
        wallet: Wallet,
        signRawRequest: SignRawRequest,
        transferType: TransferType,
        keepsPayloadExcessAddress: Bool = false
    ) async throws -> [TransferData.TonConnect.Payload] {
        if case .battery = transferType, let batteryMessageVariant = signRawRequest.messagesVariants?.battery {
            return batteryMessageVariant.map {
                TransferData.TonConnect.Payload(
                    value: BigInt(integerLiteral: Int64($0.amount)),
                    recipientAddress: $0.address,
                    stateInit: $0.stateInit,
                    payload: $0.payload
                )
            }
        }

        let jettonsBalance = try await balanceService.loadWalletBalance(
            wallet: wallet,
            currency: .USD,
            includingTransferFees: true
        ).balance.jettonsBalance

        var rebuildedMessages: [SignRawRequestMessage] = []
        for message in signRawRequest.messages {
            let foundJetton = jettonsBalance.first(where: { $0.item.walletAddress == message.address.address })

            guard let jetton = foundJetton else {
                rebuildedMessages.append(message)
                continue
            }

            if !jetton.item.jettonInfo.hasCustomPayload {
                rebuildedMessages.append(message)
                continue
            }

            let jettonPayload = try await sendService.getJettonCustomPayload(wallet: wallet, jetton: jetton.item.jettonInfo.address)

            guard let jettonSendPayload = message.payload else {
                rebuildedMessages.append(message)
                continue
            }
            var jettonTransferData = try JettonTransferData.loadFrom(
                slice: Cell.fromBase64(src: jettonSendPayload).beginParse()
            )

            jettonTransferData.customPayload = jettonPayload.customPayload

            let stateInit: String? = try jettonPayload.stateInit != nil
                ? jettonPayload.stateInit?.toBoc().base64EncodedString()
                : message.stateInit
            let payload: String? = try Builder().store(jettonTransferData).endCell().toBoc().base64EncodedString()

            rebuildedMessages.append(SignRawRequestMessage(
                address: message.address,
                amount: message.amount,
                stateInit: stateInit,
                payload: payload
            ))
        }
        return try rebuildedMessages.map {
            var resultPayload: String? = $0.payload
            if !keepsPayloadExcessAddress, let payload = $0.payload, let excessesAddress = transferType.excessAddress {
                var payloadCell = try Cell.fromBase64(src: payload.fixBase64())
                payloadCell = try TransferPayloadExcessAddressRewriter.rewrite(
                    payload: payloadCell,
                    excessAddress: excessesAddress
                )
                resultPayload = try payloadCell.toBoc().base64EncodedString()
            }

            return TransferData.TonConnect.Payload(
                value: BigInt(integerLiteral: Int64($0.amount)),
                recipientAddress: $0.address,
                stateInit: $0.stateInit,
                payload: resultPayload
            )
        }
    }

    private func nativeSwapPayload(_ payload: String, excessAddress: Address?) throws(TransferError) -> String? {
        guard let excessAddress else {
            return Data(strictHex: payload)?.base64EncodedString()
        }

        guard let payloadData = Data(strictHex: payload) else {
            throw TransferError.failedToCreateTransferData(message: "native swap payload is not valid hex")
        }

        let payloadCells: [Cell]
        do {
            payloadCells = try Cell.fromBoc(src: payloadData)
        } catch {
            throw TransferError.failedToCreateTransferData(
                message: "native swap payload is not a valid cell: \(error.localizedDescription)"
            )
        }
        guard payloadCells.count == 1, let payloadCell = payloadCells.first else {
            throw TransferError.failedToCreateTransferData(message: "native swap payload must contain exactly one root cell")
        }

        do {
            let rebuildedPayload = try TransferPayloadExcessAddressRewriter.rewrite(
                payload: payloadCell,
                excessAddress: excessAddress
            )
            return try rebuildedPayload.toBoc().base64EncodedString()
        } catch {
            throw TransferError.failedToCreateTransferData(
                message: "failed to rebuild native swap payload: \(error.localizedDescription)"
            )
        }
    }

    private func isGaslessToken(
        wallet: Wallet,
        transfer: Transfer
    ) async -> Bool {
        guard wallet.isGaslessAvailable else { return false }
        guard case let .jetton(jettonItem, _, _, _, _) = transfer else {
            return false
        }
        do {
            let rechargeMethods = try await batteryService.loadRechargeMethods(wallet: wallet, includeRechargeOnly: false)
            return rechargeMethods.contains(where: {
                $0.supportGasless && $0.jettonMasterAddress == jettonItem.jettonInfo.address
            })
        } catch {
            return false
        }
    }
}
