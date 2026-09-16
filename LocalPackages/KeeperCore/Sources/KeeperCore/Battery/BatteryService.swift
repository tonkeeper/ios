import BigInt
import Foundation
import TKBatteryAPI
import TonAPI
import TonSwift

enum BatteryServiceError: Swift.Error {
    case notSupported
}

public protocol BatteryService {
    func loadBatteryBalance(wallet: Wallet) async throws -> BatteryBalance
    func loadRechargeMethods(
        wallet: Wallet,
        includeRechargeOnly: Bool
    ) async throws -> [BatteryRechargeMethod]
    func getRechargeMethods(wallet: Wallet, includeRechargeOnly: Bool) -> [BatteryRechargeMethod]
    func loadBatteryConfig(wallet: Wallet) async throws -> Components.Schemas.Config
    func loadTransactionInfo(wallet: Wallet, boc: String) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?)
    func loadGasslessCommission(
        wallet: Wallet,
        jettonMasterAddress: String,
        boc: String
    ) async throws -> String
    func sendTransaction(
        wallet: Wallet,
        boc: String,
        proof: String?,
        headers: [String: String]
    ) async throws
    func makePurchase(wallet: Wallet, transactionId: String, promocode: String?) async throws -> Components.Schemas.iOSBatteryPurchaseStatus
    func loadPurchases(wallet: Wallet) async throws -> [BatteryPurchase]
    func loadTronTransactions(
        wallet: Wallet,
        limit: Int,
        maxTimestamp: Int64?
    ) async throws -> [TronTransaction]
    func estimateTronTransaction(
        wallet: Wallet,
        tronAddress: String,
        energy: Int,
        bandwidth: Int
    ) async throws -> Components.Schemas.EstimatedTronTx
    func sendTronTransaction(
        wallet: Wallet,
        tronAddress: String,
        transaction: String,
        energy: Int,
        bandwidth: Int,
        instantFeeTransaction: String?,
        userPublicKey: String?
    ) async throws -> String
    func hasPendingTransactions(wallet: Wallet) async throws -> Bool
    func verifyPromocode(wallet: Wallet, promocode: String) async throws
}

public extension BatteryService {
    func sendTransaction(
        wallet: Wallet,
        boc: String,
        proof: String? = nil
    ) async throws {
        try await sendTransaction(
            wallet: wallet,
            boc: boc,
            proof: proof,
            headers: [:]
        )
    }
}

final class BatteryServiceImplementation: BatteryService {
    private let batteryAPIProvider: BatteryAPIProvider
    private let rechargeMethodsRepository: BatteryRechargeMethodsRepository
    private let authorizationService: BatteryAuthorizationService

    init(
        batteryAPIProvider: BatteryAPIProvider,
        rechargeMethodsRepository: BatteryRechargeMethodsRepository,
        authorizationService: BatteryAuthorizationService
    ) {
        self.batteryAPIProvider = batteryAPIProvider
        self.rechargeMethodsRepository = rechargeMethodsRepository
        self.authorizationService = authorizationService
    }

    private func api(for network: Network) throws(BatteryAPI.ApiError) -> BatteryAPI {
        guard let api = batteryAPIProvider.api(network) else {
            throw .badUrl(underlying: BatteryServiceError.notSupported)
        }
        return api
    }

    func loadBatteryBalance(wallet: Wallet) async throws -> BatteryBalance {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.getBalance(authorization: authorization)
        }
    }

    func loadRechargeMethods(
        wallet: Wallet,
        includeRechargeOnly: Bool
    ) async throws -> [BatteryRechargeMethod] {
        let methods = try await api(for: wallet.network)
            .getRechargeMethos(includeRechargeOnly: includeRechargeOnly)

        var ton = [BatteryRechargeMethod]()
        var usdt = [BatteryRechargeMethod]()
        var other = [BatteryRechargeMethod]()
        for method in methods {
            switch method.token {
            case .ton:
                ton.append(method)
            case let .jetton(jetton):
                if jetton.jettonMasterAddress == JettonMasterAddress.tonUSDT {
                    usdt.append(method)
                } else {
                    other.append(method)
                }
            }
        }

        let sortedMethods = usdt + other + ton

        try? rechargeMethodsRepository.saveRechargeMethods(
            _methods: sortedMethods,
            rechargeOnly: includeRechargeOnly,
            network: wallet.network
        )
        return sortedMethods
    }

    func getRechargeMethods(
        wallet: Wallet,
        includeRechargeOnly: Bool
    ) -> [BatteryRechargeMethod] {
        rechargeMethodsRepository.getRechargeMethods(
            rechargeOnly: includeRechargeOnly,
            network: wallet.network
        )
    }

    func loadBatteryConfig(wallet: Wallet) async throws -> Components.Schemas.Config {
        try await api(for: wallet.network)
            .getBatteryConfig()
    }

    func loadTransactionInfo(
        wallet: Wallet,
        boc: String
    ) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?) {
        let api = try api(for: wallet.network)
        let response = try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.emulate(authorization: authorization, boc: boc)
        }

        let result = try JSONDecoder().decode(MessageConsequences.self, from: response.responseData)
        return (result, response.isBatteryAvailable, response.excess)
    }

    func loadGasslessCommission(
        wallet: Wallet,
        jettonMasterAddress: String,
        boc: String
    ) async throws -> String {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.gasslessEmulate(
                authorization: authorization,
                jettonMasterAddress: jettonMasterAddress,
                boc: boc
            )
        }
    }

    func sendTransaction(
        wallet: Wallet,
        boc: String,
        proof: String?,
        headers: [String: String]
    ) async throws {
        let api = try api(for: wallet.network)
        try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.sendMessage(
                authorization: authorization,
                boc: boc,
                proof: proof,
                extraHeaders: headers
            )
        }
    }

    func makePurchase(wallet: Wallet, transactionId: String, promocode: String?) async throws -> Components.Schemas.iOSBatteryPurchaseStatus {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.makePurchase(
                authorization: authorization,
                transactionId: transactionId,
                promocode: promocode
            )
        }
    }

    func loadPurchases(wallet: Wallet) async throws -> [BatteryPurchase] {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.getPurchases(authorization: authorization)
        }
    }

    func loadTronTransactions(
        wallet: Wallet,
        limit: Int,
        maxTimestamp: Int64?
    ) async throws -> [TronTransaction] {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.getTronTransactions(
                authorization: authorization,
                limit: limit,
                maxTimestamp: maxTimestamp
            )
        }
    }

    func estimateTronTransaction(
        wallet: Wallet,
        tronAddress: String,
        energy: Int,
        bandwidth: Int
    ) async throws -> Components.Schemas.EstimatedTronTx {
        let api = try api(for: wallet.network)
        return try await authorizationService.withOptionalAuthorization(for: wallet) { authorization in
            try await api.getTronEstimate(
                authorization: authorization,
                address: tronAddress,
                energy: energy,
                bandwidth: bandwidth
            )
        }
    }

    func sendTronTransaction(
        wallet: Wallet,
        tronAddress: String,
        transaction: String,
        energy: Int,
        bandwidth: Int,
        instantFeeTransaction: String?,
        userPublicKey: String?
    ) async throws -> String {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.tronSend(
                authorization: authorization,
                wallet: tronAddress,
                tx: transaction,
                energy: energy,
                bandwidth: bandwidth,
                instantFeeTx: instantFeeTransaction,
                userPublicKey: userPublicKey
            )
        }
    }

    func hasPendingTransactions(wallet: Wallet) async throws -> Bool {
        let api = try api(for: wallet.network)
        let status = try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.getStatus(authorization: authorization)
        }
        return !status.pending_transactions.isEmpty
    }

    func verifyPromocode(wallet: Wallet, promocode: String) async throws {
        try await api(for: wallet.network)
            .verifyPromocode(promocode: promocode)
    }
}

extension Components.Schemas.Config {
    static let fallbackTransferCost = BigUInt(50_000_000)

    var excessAddress: Address {
        get throws {
            try Address.parse(excess_account)
        }
    }

    func transferCost(jettonMasterAddress: Address?) -> BigUInt {
        let tonString: String? = {
            if let jettonMasterAddress,
               let match = transfer_cost.jettons.first(where: {
                   (try? Address.parse($0.jetton_master)) == jettonMasterAddress
               })
            {
                return match.value
            }
            return transfer_cost._default
        }()
        guard let tonString else { return Self.fallbackTransferCost }
        return NSDecimalNumber(string: tonString).toNanoTonsBigUInt() ?? Self.fallbackTransferCost
    }
}
