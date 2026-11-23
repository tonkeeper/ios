import BigInt
import Foundation
import KeeperCoreComponents
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
    func loadBatteryConfig(wallet: Wallet) async throws -> TKBatteryAPI.Components.Schemas.Config
    func loadTransactionInfo(wallet: Wallet, boc: String) async throws -> (info: TonAPI.Components.Schemas.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?)
    func loadGasslessCommission(
        wallet: Wallet,
        jettonMasterAddress: String,
        boc: String
    ) async throws -> String
    /// Returns the hash of the message the relayer sent for `boc`, when it names one.
    @discardableResult
    func sendTransaction(
        wallet: Wallet,
        boc: String,
        proof: String?,
        headers: [String: String]
    ) async throws -> String?
    func makePurchase(wallet: Wallet, transactionId: String, promocode: String?) async throws -> TKBatteryAPI.Components.Schemas.iOSBatteryPurchaseStatus
    func loadPurchases(wallet: Wallet) async throws -> [BatteryPurchase]
    func migrateBattery(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        proof: BatteryMigrationProof
    ) async throws -> TKBatteryAPI.Components.Schemas.BatteryMigration
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
    ) async throws -> TKBatteryAPI.Components.Schemas.EstimatedTronTx
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

/// The battery's gasless 2.0 relayer, authenticated the way `BatteryService` is.
protocol BatteryGaslessService {
    func gaslessConfig() async throws -> TKBatteryAPI.Components.Schemas.GaslessV2Config
    func estimateGasless(
        wallet: Wallet,
        request: TKBatteryAPI.Components.Schemas.GaslessV2EstimateRequest
    ) async throws -> TKBatteryAPI.Components.Schemas.GaslessV2EstimateResponse
    func emulateGasless(
        wallet: Wallet,
        request: TKBatteryAPI.Components.Schemas.GaslessV2EmulateRequest
    ) async throws -> TKBatteryAPI.Components.Schemas.GaslessV2EmulateResponse
    func sendGasless(
        wallet: Wallet,
        request: TKBatteryAPI.Components.Schemas.GaslessV2SendRequest
    ) async throws -> TKBatteryAPI.Components.Schemas.GaslessV2SendResponse
}

public extension BatteryService {
    @discardableResult
    func sendTransaction(
        wallet: Wallet,
        boc: String,
        proof: String? = nil
    ) async throws -> String? {
        try await sendTransaction(
            wallet: wallet,
            boc: boc,
            proof: proof,
            headers: [:]
        )
    }
}

final class BatteryServiceImplementation: BatteryService, BatteryGaslessService, BatteryPurchaseService {
    private let batteryAPIProvider: BatteryAPIProvider
    private let rechargeMethodsRepository: BatteryRechargeMethodsRepository
    private let assetMethodsVault: FileSystemVault<[BatteryAssetRechargeMethod], String>?
    private let authorizationService: BatteryAuthorizationService

    init(
        batteryAPIProvider: BatteryAPIProvider,
        rechargeMethodsRepository: BatteryRechargeMethodsRepository,
        authorizationService: BatteryAuthorizationService,
        assetMethodsVault: FileSystemVault<[BatteryAssetRechargeMethod], String>? = nil
    ) {
        self.batteryAPIProvider = batteryAPIProvider
        self.rechargeMethodsRepository = rechargeMethodsRepository
        self.authorizationService = authorizationService
        self.assetMethodsVault = assetMethodsVault
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

    func loadBatteryConfig(wallet: Wallet) async throws -> TKBatteryAPI.Components.Schemas.Config {
        try await api(for: wallet.network)
            .getBatteryConfig()
    }

    func loadTransactionInfo(
        wallet: Wallet,
        boc: String
    ) async throws -> (info: TonAPI.Components.Schemas.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?) {
        let api = try api(for: wallet.network)
        let response = try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.emulate(authorization: authorization, boc: boc)
        }

        let result = try JSONDecoder().decode(TonAPI.Components.Schemas.MessageConsequences.self, from: response.responseData)
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
    ) async throws -> String? {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.sendMessage(
                authorization: authorization,
                boc: boc,
                proof: proof,
                extraHeaders: headers
            )
        }
    }

    func makePurchase(wallet: Wallet, transactionId: String, promocode: String?) async throws -> TKBatteryAPI.Components.Schemas.iOSBatteryPurchaseStatus {
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

    func migrateBattery(
        from sourceWallet: Wallet,
        to destinationWallet: Wallet,
        proof: BatteryMigrationProof
    ) async throws -> TKBatteryAPI.Components.Schemas.BatteryMigration {
        let api = try api(for: sourceWallet.network)
        let fromAddress = try sourceWallet.tonMigrationAccountId()
        return try await authorizationService.withMigrationAuthorization(
            from: sourceWallet,
            to: destinationWallet,
            validateDestination: { authorization in
                _ = try await api.getBalance(authorization: authorization)
            }
        ) { authorization in
            try await api.migrateBattery(
                authorization: authorization,
                proof: proof.signature,
                fromAddress: fromAddress
            )
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
    ) async throws -> TKBatteryAPI.Components.Schemas.EstimatedTronTx {
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

    func loadAssetRechargeMethods(wallet: Wallet) async throws -> [BatteryAssetRechargeMethod] {
        guard wallet.isMultichain else { return [] }
        let methods = try await api(for: wallet.network).rechargeMethods(includeRechargeOnly: false, multichain: true)
            .compactMap(BatteryAssetRechargeMethod.init)
        try? assetMethodsVault?.saveItem(methods, key: "battery_asset_methods_v1_" + String(wallet.network.rawValue))
        return methods
    }

    func cachedAssetRechargeMethods(wallet: Wallet) -> [BatteryAssetRechargeMethod] {
        guard wallet.isMultichain else { return [] }
        return (try? assetMethodsVault?.loadItem(key: "battery_asset_methods_v1_" + String(wallet.network.rawValue))) ?? []
    }

    func estimatePurchase(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> TKBatteryAPI.Components.Schemas.PurchaseBatteryEstimateResponse {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.purchaseBatteryEstimate(authorization: authorization, request: request.apiRequest)
        }
    }

    func emulatePurchase(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> TKBatteryAPI.Components.Schemas.PurchaseBatteryEmulateResponse {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.purchaseBatteryEmulate(authorization: authorization, request: request.apiRequest)
        }
    }

    func gaslessConfig() async throws -> TKBatteryAPI.Components.Schemas.GaslessV2Config {
        try await api(for: .mainnet).gaslessConfig()
    }

    func estimateGasless(
        wallet: Wallet,
        request: TKBatteryAPI.Components.Schemas.GaslessV2EstimateRequest
    ) async throws -> TKBatteryAPI.Components.Schemas.GaslessV2EstimateResponse {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.gaslessEstimate(authorization: authorization, request: request)
        }
    }

    func emulateGasless(
        wallet: Wallet,
        request: TKBatteryAPI.Components.Schemas.GaslessV2EmulateRequest
    ) async throws -> TKBatteryAPI.Components.Schemas.GaslessV2EmulateResponse {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.gaslessEmulate(authorization: authorization, request: request)
        }
    }

    func sendGasless(
        wallet: Wallet,
        request: TKBatteryAPI.Components.Schemas.GaslessV2SendRequest
    ) async throws -> TKBatteryAPI.Components.Schemas.GaslessV2SendResponse {
        let api = try api(for: wallet.network)
        return try await authorizationService.withAuthorization(for: wallet) { authorization in
            try await api.gaslessSend(authorization: authorization, request: request)
        }
    }
}

extension TKBatteryAPI.Components.Schemas.Config {
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
