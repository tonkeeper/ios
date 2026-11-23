import Foundation
import OpenAPIRuntime
import TKBatteryAPI

public protocol BatteryPurchaseService {
    func cachedAssetRechargeMethods(wallet: Wallet) -> [BatteryAssetRechargeMethod]
    func loadAssetRechargeMethods(wallet: Wallet) async throws -> [BatteryAssetRechargeMethod]
    func estimatePurchase(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> Components.Schemas.PurchaseBatteryEstimateResponse
    func emulatePurchase(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> Components.Schemas.PurchaseBatteryEmulateResponse
}

public protocol BatteryPurchasing {
    func estimate(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> BatteryPurchaseQuote
    func emulate(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> BatteryPurchaseReview
    func send(wallet: Wallet, review: BatteryPurchaseReview, passcodeProvider: @escaping () async -> String?) async throws -> String?
}

public final class BatteryPurchaser: BatteryPurchasing {
    typealias Sign = (Wallet, BatteryPurchaseRequest, BatteryPurchaseReview, @escaping () async -> String?, () async throws -> BatteryPurchaseReview) async throws -> (Data, BatteryPurchaseReview)
    private let service: BatteryPurchaseService
    private let relayer: EVMGaslessRelaying
    private let sign: Sign

    init(service: BatteryPurchaseService, relayer: EVMGaslessRelaying, sign: @escaping Sign) {
        self.service = service
        self.relayer = relayer
        self.sign = sign
    }

    public func estimate(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> BatteryPurchaseQuote {
        let response = try await service.estimatePurchase(wallet: wallet, request: request)
        try Self.check(request, chain: response.chain_id, asset: response.asset_id, sender: response.sender_address, amount: response.amount)
        try Self.checkFee(response.fee, charges: response.charges, gross: response.gross_charges, chainId: request.method.chainId)
        return try Self.quote(charges: response.charges, gross: response.gross_charges, receiver: response.funds_receiver)
    }

    public func emulate(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> BatteryPurchaseReview {
        let requestedAt = Date()
        let response = try await service.emulatePurchase(wallet: wallet, request: request)
        try Self.check(request, chain: response.chain_id, asset: response.asset_id, sender: response.sender_address, amount: response.amount)
        try Self.checkFee(response.fee, charges: response.charges, gross: response.gross_charges, chainId: request.method.chainId)
        guard response.expires_at > response.created_at else { throw BatteryPurchaseError.expired }
        return try BatteryPurchaseReview(
            quote: Self.quote(charges: response.charges, gross: response.gross_charges, receiver: response.funds_receiver),
            request: request, response: response, receivedAt: requestedAt
        )
    }

    public func send(wallet: Wallet, review: BatteryPurchaseReview, passcodeProvider: @escaping () async -> String?) async throws -> String? {
        try Task.checkCancellation()
        let (signed, fresh) = try await sign(wallet, review.request, review, passcodeProvider) {
            try await self.emulate(wallet: wallet, request: review.request)
        }
        try Task.checkCancellation()
        guard !fresh.isExpired(at: Date()) else { throw BatteryPurchaseError.expired }
        do {
            return try await relayer.send(wallet: wallet, signedOperation: signed)
        } catch let error as EVMGaslessRelayerError {
            switch error {
            case .quoteExpired: throw BatteryPurchaseError.expired
            // Every attempt is built again, so one the relayer may have broadcast is not retried.
            case .rejected(_, true): throw BatteryPurchaseError.outcomeUnknown(fresh)
            case .rejected, .malformedEnvelope: throw BatteryPurchaseError.rejected
            }
        } catch {
            if let localError = Self.preSendError(error) { throw localError }
            // After handing the signed operation to the relayer, losing its answer is not a refusal.
            throw BatteryPurchaseError.outcomeUnknown(fresh)
        }
    }

    private static func preSendError(_ error: Error) -> Error? {
        if error is BatteryAuthorizationError { return error }
        if let error = error as? BatteryAPI.ApiError, case .badUrl = error { return error }
        if let error = error as? URLError {
            return [.notConnectedToInternet, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost].contains(error.code) ? error : nil
        }
        if let error = error as? ClientError, error.response == nil {
            return preSendError(error.underlyingError)
        }
        if let error = error as? BatteryAPI.ApiError, case let .unknown(underlying?) = error {
            return preSendError(underlying)
        }
        return nil
    }

    static func checkFee(_ fee: Components.Schemas.GaslessV2Fee, charges: Int64, gross: Int64, chainId: String) throws {
        guard charges >= 0, gross >= charges, fee._type == .value,
              fee.asset_id == "battery/" + (chainId.split(separator: "/").last.map(String.init) ?? ""),
              fee.data.amount.flatMap(Int64.init) == gross - charges else { throw BatteryPurchaseError.invalidQuote }
    }

    static func checkFresh(_ fresh: BatteryPurchaseReview, against shown: BatteryPurchaseReview) throws {
        guard fresh.request == shown.request else { throw BatteryPurchaseError.invalidQuote }
        guard fresh.quote.charges > 0,
              fresh.quote.charges >= shown.quote.charges,
              BatteryAssetRechargeMethod.sameAddress(fresh.quote.fundsReceiver, shown.quote.fundsReceiver)
        else {
            throw BatteryPurchaseError.changedQuote(fresh)
        }
    }

    static func check(_ request: BatteryPurchaseRequest, chain: String, asset: String, sender: String, amount: String) throws {
        guard request.amount > 0,
              request.method.chainId == chain,
              BatteryAssetRechargeMethod.sameAsset(request.method.assetId, asset),
              BatteryAssetRechargeMethod.sameAddress(request.sender, sender),
              amount == request.amount.description else { throw BatteryPurchaseError.invalidQuote }
    }

    static func quote(charges: Int64, gross: Int64, receiver: String) throws -> BatteryPurchaseQuote {
        guard charges >= 0, gross >= charges, !receiver.isEmpty else { throw BatteryPurchaseError.invalidQuote }
        return BatteryPurchaseQuote(charges: charges, grossCharges: gross, fundsReceiver: receiver)
    }
}
