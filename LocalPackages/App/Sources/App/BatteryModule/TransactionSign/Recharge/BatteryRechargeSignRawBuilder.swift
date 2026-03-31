import BigInt
import Foundation
import KeeperCore
import TonSwift

struct BatteryRechargeSignRawBuilder {
    enum Error: Swift.Error {
        case noJettonWalletAddress
    }

    private let wallet: Wallet
    private let payload: BatteryRechargePayload
    private let batteryService: BatteryService
    private let sendService: SendService
    private let tonProofTokenService: TonProofTokenService
    private let configuration: Configuration

    init(
        wallet: Wallet,
        payload: BatteryRechargePayload,
        batteryService: BatteryService,
        sendService: SendService,
        tonProofTokenService: TonProofTokenService,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.payload = payload
        self.batteryService = batteryService
        self.sendService = sendService
        self.tonProofTokenService = tonProofTokenService
        self.configuration = configuration
    }

    func getSignRawRequest() async throws -> Transfer {
        let config = try await batteryService.loadBatteryConfig(wallet: wallet)
        let batteryBalance = await getBatteryBalance(wallet: wallet)
        let rechargeMethod = await getRechargeMethod(wallet: wallet, token: payload.token)
        _ = await getRechargeMethodMaxInputAmount(
            rechargeMethod: rechargeMethod,
            batteryMaxInputAmount: configuration.batteryMaxInputAmount(network: wallet.network)
        )

        let amountDecimalNumber = NSDecimalNumber.fromBigUInt(
            value: payload.amount,
            decimals: payload.token.fractionDigits
        )

        let fundReceiver = config.fund_receiver
        let toAddress = try AnyAddress(rawAddress: fundReceiver)
        let validUntil = await sendService.getTimeoutSafely(wallet: wallet, TTL: UInt64(abs(config.message_ttl)))
        let isForceRelayer = isForceRelayer(
            batteryBalance: batteryBalance,
            rechargeMethod: rechargeMethod,
            amount: amountDecimalNumber
        )

        let batteryPayload = createBatteryPayload(
            recipientAddress: payload.recipient?.recipientAddress.address, promocode: payload.promocode
        )

        let request = try SignRawRequest(
            messages: createMessages(
                toAddress: toAddress,
                batteryPayload: batteryPayload
            ),
            validUntil: validUntil,
            from: wallet.address,
            messagesVariants: nil
        )

        return .signRaw(request, forceRelayer: isForceRelayer)
    }

    private func createMessages(
        toAddress: KeeperCore.AnyAddress,
        batteryPayload: Cell?
    ) throws -> [SignRawRequestMessage] {
        switch payload.token {
        case .ton:
            try createTonMessages(
                toAddress: toAddress,
                batteryPayload: batteryPayload
            )
        case let .jetton(jettonItem):
            try createJettonMessages(
                toAddress: toAddress,
                jettonItem: jettonItem,
                batteryPayload: batteryPayload
            )
        }
    }

    private func createTonMessages(
        toAddress: KeeperCore.AnyAddress,
        batteryPayload: Cell?
    ) throws -> [SignRawRequestMessage] {
        return [
            SignRawRequestMessage(
                address: toAddress,
                amount: UInt64(payload.amount),
                stateInit: nil,
                payload: try? batteryPayload?.toBoc().base64EncodedString()
            ),
        ]
    }

    private func createJettonMessages(
        toAddress: KeeperCore.AnyAddress,
        jettonItem: JettonItem,
        batteryPayload: Cell?
    ) throws -> [SignRawRequestMessage] {
        guard let jettonWalletAddress = jettonItem.walletAddress else {
            throw Error.noJettonWalletAddress
        }
        let jettonTransferData = try JettonTransferData(
            queryId: UInt64(UnsignedTransferBuilder.newWalletQueryId()),
            amount: payload.amount,
            toAddress: toAddress.address,
            responseAddress: wallet.address,
            forwardAmount: BigUInt(stringLiteral: "1"),
            forwardPayload: batteryPayload,
            customPayload: nil
        )
        return try [
            SignRawRequestMessage(
                address: .address(jettonWalletAddress),
                amount: 100_000_000,
                stateInit: nil,
                payload: Builder().store(jettonTransferData).endCell().toBoc().base64EncodedString()
            ),
        ]
    }

    private func getRechargeMethodMaxInputAmount(
        rechargeMethod: BatteryRechargeMethod?,
        batteryMaxInputAmount: NSDecimalNumber
    ) -> NSDecimalNumber {
        guard let rechargeMethod else { return 0 }
        return batteryMaxInputAmount.dividing(by: rechargeMethod.rate)
    }

    private func getBatteryBalance(wallet: Wallet) async -> BatteryBalance {
        do {
            let tonProof = try tonProofTokenService.getWalletToken(wallet)
            return try await batteryService.loadBatteryBalance(wallet: wallet, tonProofToken: tonProof)
        } catch {
            return BatteryBalance.empty
        }
    }

    private func getRechargeMethod(wallet: Wallet, token: TonToken) async -> BatteryRechargeMethod? {
        let methods = await {
            do {
                return try await batteryService.loadRechargeMethods(wallet: wallet, includeRechargeOnly: true)
            } catch {
                return []
            }
        }()
        return methods.first(where: { method in
            switch token {
            case .ton:
                method.token == .ton
            case let .jetton(jettonItem):
                method.jettonMasterAddress == jettonItem.jettonInfo.address
            }
        })
    }

    private func isForceRelayer(
        batteryBalance: BatteryBalance,
        rechargeMethod: BatteryRechargeMethod?,
        amount: NSDecimalNumber
    ) -> Bool {
        switch payload.token {
        case .ton:
            return false
        case .jetton:
            if batteryBalance.balanceDecimalNumber.compare(0) == .orderedDescending {
                return true
            } else if let minBootstrapValue = rechargeMethod?.minBootstrapValue {
                return minBootstrapValue.compare(amount) != .orderedDescending
            } else {
                return false
            }
        }
    }

    private func createBatteryPayload(
        recipientAddress: Address? = nil,
        promocode: String? = nil
    ) -> Cell? {
        do {
            let builder = Builder()
            try builder.store(uint: Int32.batteryPayloadOpcode, bits: 32)
            if let recipientAddress {
                try builder.store(bit: true)
                try builder.store(recipientAddress)
            } else {
                try builder.store(bit: false)
            }
            if let promocode, !promocode.isEmpty, let promocodeData = promocode.data(using: .utf8) {
                try builder.store(bit: true)
                try builder.store(data: promocodeData)
            } else {
                try builder.store(bit: false)
            }
            return try builder.endCell()
        } catch {
            return nil
        }
    }
}

private extension Int32 {
    static let batteryPayloadOpcode = 0xB7B2_515F
}
