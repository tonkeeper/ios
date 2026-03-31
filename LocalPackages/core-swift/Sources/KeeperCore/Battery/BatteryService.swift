import BigInt
import Foundation
import TKBatteryAPI
import TonAPI
import TonSwift

enum BatteryServiceError: Swift.Error {
    case notSupported
}

public protocol BatteryService {
    func loadBatteryBalance(wallet: Wallet, tonProofToken: String) async throws -> BatteryBalance
    func loadRechargeMethods(
        wallet: Wallet,
        includeRechargeOnly: Bool
    ) async throws -> [BatteryRechargeMethod]
    func getRechargeMethods(wallet: Wallet, includeRechargeOnly: Bool) -> [BatteryRechargeMethod]
    func loadBatteryConfig(wallet: Wallet) async throws -> Components.Schemas.Config
    func loadTransactionInfo(wallet: Wallet, boc: String, tonProofToken: String) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?)
    func loadGasslessCommission(
        wallet: Wallet,
        tonProofToken: String,
        jettonMasterAddress: String,
        boc: String
    ) async throws -> String
    func sendTransaction(wallet: Wallet, boc: String, tonProofToken: String) async throws(BatteryAPI.ApiError)
    func makePurchase(wallet: Wallet, tonProofToken: String, transactionId: String, promocode: String?) async throws -> Components.Schemas.iOSBatteryPurchaseStatus
    func verifyPromocode(wallet: Wallet, promocode: String) async throws
}

final class BatteryServiceImplementation: BatteryService {
    private let batteryAPIProvider: BatteryAPIProvider
    private let rechargeMethodsRepository: BatteryRechargeMethodsRepository

    init(
        batteryAPIProvider: BatteryAPIProvider,
        rechargeMethodsRepository: BatteryRechargeMethodsRepository
    ) {
        self.batteryAPIProvider = batteryAPIProvider
        self.rechargeMethodsRepository = rechargeMethodsRepository
    }

    private func api(for network: Network) throws(BatteryAPI.ApiError) -> BatteryAPI {
        guard let api = batteryAPIProvider.api(network) else {
            throw .badUrl(underlying: BatteryServiceError.notSupported)
        }
        return api
    }

    func loadBatteryBalance(
        wallet: Wallet,
        tonProofToken: String
    ) async throws -> BatteryBalance {
        return try await api(for: wallet.network)
            .getBalance(tonProofToken: tonProofToken)
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
        boc: String,
        tonProofToken: String
    ) async throws -> (info: TonAPI.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?) {
        let response = try await api(for: wallet.network)
            .emulate(tonProofToken: tonProofToken, boc: boc)

        let result = try JSONDecoder().decode(MessageConsequences.self, from: response.responseData)
        return (result, response.isBatteryAvailable, response.excess)
    }

    func loadGasslessCommission(
        wallet: Wallet,
        tonProofToken: String,
        jettonMasterAddress: String,
        boc: String
    ) async throws -> String {
        return try await api(for: wallet.network)
            .gasslessEmulate(
                tonProofToken: tonProofToken,
                jettonMasterAddress: jettonMasterAddress,
                boc: boc
            )
    }

    func sendTransaction(wallet: Wallet, boc: String, tonProofToken: String) async throws(BatteryAPI.ApiError) {
        try await api(for: wallet.network)
            .sendMessage(tonProofToken: tonProofToken, boc: boc)
    }

    func makePurchase(wallet: Wallet, tonProofToken: String, transactionId: String, promocode: String?) async throws -> Components.Schemas.iOSBatteryPurchaseStatus {
        try await api(for: wallet.network)
            .makePurchase(tonProofToken: tonProofToken, transactionId: transactionId, promocode: promocode)
    }

    func verifyPromocode(wallet: Wallet, promocode: String) async throws {
        try await api(for: wallet.network)
            .verifyPromocode(promocode: promocode)
    }
}

extension Components.Schemas.Config {
    var excessAddress: Address {
        get throws {
            try Address.parse(excess_account)
        }
    }
}
