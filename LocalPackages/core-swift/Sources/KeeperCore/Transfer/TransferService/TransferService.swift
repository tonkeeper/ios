import BigInt
import Foundation
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

        public var jettonInfo: JettonInfo? {
            switch token {
            case .ton:
                return nil
            case let .jetton(jettonItem):
                return jettonItem.jettonInfo
            }
        }
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
    private let tonProofTokenService: TonProofTokenService
    private let batteryService: BatteryService
    private let balanceService: BalanceService
    private let sendService: SendService
    private let accountService: AccountService
    private let configuration: Configuration
    private let currencyStore: CurrencyStore

    init(
        tonProofTokenService: TonProofTokenService,
        batteryService: BatteryService,
        balanceService: BalanceService,
        sendService: SendService,
        accountService: AccountService,
        configuration: Configuration,
        settingsRepository: SettingsRepository,
        currencyStore: CurrencyStore
    ) {
        self.tonProofTokenService = tonProofTokenService
        self.batteryService = batteryService
        self.balanceService = balanceService
        self.sendService = sendService
        self.accountService = accountService
        self.configuration = configuration
        self.currencyStore = currencyStore
    }

    @discardableResult
    public func sendTransaction<SignError: Error>(
        wallet: Wallet,
        transfer: Transfer,
        transferType: TransferType,
        signClosure: (TransferData) async -> Result<SignedTransactions, SignError>
    ) async throws(SomeOf<TransferError, SignError>) -> String {
        // TODO: kinda bullshit, should do something with this
        var transferType = transferType
        if case .battery = transferType {
            do {
                let batteryConfig = try? await batteryService.loadBatteryConfig(wallet: wallet)
                let updatedExcessAddress: Address
                if let excessAddress = try? batteryConfig?.excessAddress {
                    updatedExcessAddress = excessAddress
                } else {
                    updatedExcessAddress = try wallet.address
                }
                transferType = .battery(excessAddress: updatedExcessAddress)
            } catch {
                throw .certain(
                    .failedToCreateTransferData(message: "battery transfer: failed to get excess address due to error: \(error.localizedDescription)")
                )
            }
        }
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

        if signedTransactions.count == 1 {
            let boc = signedTransactions[0]
            switch transferType {
            case .default:
                do {
                    try await sendService.sendTransaction(
                        boc: boc,
                        wallet: wallet
                    )
                } catch {
                    throw .certain(
                        .sendFailed(message: "failed to single \(transferType.analyticsName) send due to error: \(error.localizedDescription)")
                    )
                }
            case .battery, .gasless:
                let tonProofToken: String
                do {
                    tonProofToken = try tonProofTokenService.getWalletToken(wallet)
                } catch {
                    throw .certain(
                        .sendFailed(message: "failed to get proof token on single send due to error: \(error.localizedDescription)")
                    )
                }
                do {
                    try await batteryService.sendTransaction(
                        wallet: wallet,
                        boc: boc,
                        tonProofToken: tonProofToken
                    )
                } catch {
                    throw .certain(
                        .sendFailed(message: error.localizedDescription)
                    )
                }
            }
        } else {
            switch transferType {
            case .default:
                do {
                    try await sendService.sendTransactions(
                        batch: signedTransactions,
                        wallet: wallet
                    )
                } catch {
                    throw .certain(
                        .sendFailed(message: "failed to batch \(transferType.analyticsName) send due to error: \(error.localizedDescription)")
                    )
                }
            case .battery, .gasless:
                let tonProofToken: String
                do {
                    tonProofToken = try tonProofTokenService.getWalletToken(wallet)
                } catch {
                    throw .certain(
                        .sendFailed(message: "failed to get proof token on batch send due to error: \(error.localizedDescription)")
                    )
                }
                for boc in signedTransactions {
                    do {
                        try await batteryService.sendTransaction(
                            wallet: wallet,
                            boc: boc,
                            tonProofToken: tonProofToken
                        )
                    } catch {
                        throw .certain(
                            .sendFailed(message: error.localizedDescription)
                        )
                    }
                }
            }
        }

        return signedTransactions[0]
    }

    public func emulate(
        wallet: Wallet,
        transfer: Transfer,
        params: [EmulateMessageToWalletRequestParamsInner]? = nil,
        ignoreGasless: Bool = false,
        withoutRelayer: Bool = false,
        isPreferGasless: Bool = true
    ) async throws -> TransferEmulationResult {
        let tonProofToken = try? tonProofTokenService.getWalletToken(wallet)
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
                  let tonProofToken,
                  await configuration.isBatteryEnable(network: wallet.network),
                  await configuration.isBatterySendEnable(network: wallet.network)
        {
            do {
                return try await emulateWithBattery(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: wallet.address,
                    tonProofToken: tonProofToken,
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
                  let tonProofToken,
                  let excessesAddress = try? batteryConfig?.excessAddress,
                  isGaslessToken
        {
            do {
                return try await emulateWithGasless(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: excessesAddress,
                    tonProofToken: tonProofToken,
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
                  let tonProofToken,
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

            let amount = {
                switch result.extra.amount {
                case let .fee(fee):
                    return fee + BigUInt(50_000_000)
                case .refund:
                    return BigUInt(50_000_000)
                }
            }()
            guard amount > tonBalance else {
                return result
            }
            return try await emulateWithGasless(
                wallet: wallet,
                transfer: transfer,
                excessAddress: excessesAddress,
                tonProofToken: tonProofToken,
                transferType: .gasless(excessAddress: excessesAddress, fee: 1)
            )
        }
    }

    public func emulate(
        wallet: Wallet,
        transfer: Transfer,
        params: [EmulateMessageToWalletRequestParamsInner]? = nil,
        preferredExtraType: TransactionConfirmationModel.ExtraType
    ) async throws -> TransferEmulationResult {
        do {
            switch preferredExtraType {
            case .default:
                return try await defaultEmulate(
                    wallet: wallet,
                    transfer: transfer,
                    params: params,
                    isGaslessAvailable: false
                )
            case .battery:
                let tonProofToken = try tonProofTokenService.getWalletToken(wallet)
                let batteryConfig = try await batteryService.loadBatteryConfig(wallet: wallet)
                guard let excessAddress = try? batteryConfig.excessAddress else { throw TransferError.noExcessesAddress }
                return try await emulateWithBattery(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: excessAddress,
                    tonProofToken: tonProofToken,
                    transferType: .battery(excessAddress: excessAddress)
                )
            case .gasless:
                let tonProofToken = try tonProofTokenService.getWalletToken(wallet)
                let batteryConfig = try await batteryService.loadBatteryConfig(wallet: wallet)
                guard let excessesAddress = try? batteryConfig.excessAddress else { throw TransferError.noExcessesAddress }
                return try await emulateWithGasless(
                    wallet: wallet,
                    transfer: transfer,
                    excessAddress: excessesAddress,
                    tonProofToken: tonProofToken,
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

    func isGaslessAvailable(wallet: Wallet, transfer: Transfer) async -> Bool {
        guard !configuration.flag(\.gaslessDisabled, network: wallet.network) else { return false }

        let tonProofToken = try? tonProofTokenService.getWalletToken(wallet)
        let isGaslessToken = await isGaslessToken(wallet: wallet, transfer: transfer)
        let batteryConfig = try? await batteryService.loadBatteryConfig(wallet: wallet)

        guard wallet.isGaslessAvailable,
              tonProofToken != nil,
              let _ = try? batteryConfig?.excessAddress,
              isGaslessToken
        else {
            return false
        }
        return true
    }

    func isRelayerAvailable(
        wallet: Wallet,
        transfer: Transfer
    ) async -> Bool {
        let tonProofToken = try? tonProofTokenService.getWalletToken(wallet)
        guard let tonProofToken else { return false }

        let isBalanceAvailable: () async -> Bool = {
            await isBatteryBalanceEnable(wallet: wallet, tonProofToken: tonProofToken)
        }
        switch transfer {
        case .ton:
            return false
        case .jetton:
            let isBalanceAvailable = await isBalanceAvailable()
            return wallet.isBatteryEnable && wallet.batterySettings.isJettonTransactionEnable && isBalanceAvailable
        case .nft:
            let isBalanceAvailable = await isBalanceAvailable()
            return wallet.isBatteryEnable && wallet.batterySettings.isNFTTransactionEnable && isBalanceAvailable
        case .stonfiSwap:
            let isBalanceAvailable = await isBalanceAvailable()
            return wallet.isBatteryEnable && wallet.batterySettings.isSwapTransactionEnable && isBalanceAvailable
        case let .signRaw(_, isForceRelayer):
            return isForceRelayer
        case .renewDNS:
            return false
        case .nativeSwap:
            let isBalanceAvailable = await isBalanceAvailable()
            return wallet.isBatteryEnable
                && wallet.batterySettings.isSwapTransactionEnable
                && isBalanceAvailable
        }
    }

    func isBatteryBalanceEnable(wallet: Wallet, tonProofToken: String) async -> Bool {
        do {
            let batteryBalance = try await batteryService.loadBatteryBalance(wallet: wallet, tonProofToken: tonProofToken)
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
        tonProofToken: String,
        transferType: TransferType
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
                    boc: signed.toBoc().base64EncodedString(),
                    tonProofToken: tonProofToken
                )
                if transactionInfo.isBatteryAvailable {
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
        tonProofToken: String,
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
            tonProofToken: tonProofToken,
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
        case let .stonfiSwap(signRawRequest):
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
                    timeout: safelyTimeout
                )
            } catch {
                throw .failedToCreateTransferData(
                    message: "failed to build native swap transfer data due to error: \(error.localizedDescription)"
                )
            }
            return transferData
        case let .signRaw(signRawRequest, _):
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
            let payloads = model.messages.map { message in
                TransferData.TonConnect.Payload(
                    value: BigInt(message.sendAmount) ?? 0,
                    recipientAddress: message.targetAddress,
                    stateInit: nil,
                    payload: Data(hex: message.payload)?.base64EncodedString()
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
        transferType: TransferType
    ) async throws -> TransferData.Transfer {
        let payloads = try await getTonconnectPayloads(wallet: wallet, signRawRequest: signRawRequest, transferType: transferType)

        return TransferData.Transfer.tonConnect(
            TransferData.TonConnect(
                payloads: payloads,
                sender: signRawRequest.from
            )
        )
    }

    private func getTonconnectPayloads(wallet: Wallet, signRawRequest: SignRawRequest, transferType: TransferType) async throws -> [TransferData.TonConnect.Payload] {
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
            if let payload = $0.payload, let excessesAddress = transferType.excessAddress {
                var payloadCell = try Cell.fromBase64(src: payload.fixBase64())
                payloadCell = try rebuildPayloadWithExcessesAddress(payload: payloadCell, excessesAddress)
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

    private func rebuildPayloadWithExcessesAddress(payload: Cell, _ excessesAddress: Address) throws -> Cell {
        let payloadSlice = try payload.toSlice()
        guard let opcode = try? payloadSlice.loadUint(bits: 32),
              opcode <= Int32.max
        else {
            return payload
        }
        let builder = Builder()

        switch Int32(opcode) {
        case OpCodes.JETTON_TRANSFER:
            try builder.store(uint: OpCodes.JETTON_TRANSFER, bits: 32)
            try builder.store(uint: payloadSlice.loadUint(bits: 64), bits: 64)
            try builder.store(payloadSlice.loadCoins())
            try builder.store(payloadSlice.loadType() as Address)
            let _: TonSwift.AnyAddress = try payloadSlice.loadType()
            while payloadSlice.remainingRefs > 0 {
                let forwardCell = try payloadSlice.loadRef()
                let rebuildedRef = try rebuildPayloadWithExcessesAddress(payload: forwardCell, excessesAddress)
                try builder.store(ref: rebuildedRef)
            }
            try builder.store(excessesAddress)
            try builder.store(bits: payloadSlice.loadBits(payloadSlice.remainingBits))
        default:
            return payload
        }

        return try builder.endCell()
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
