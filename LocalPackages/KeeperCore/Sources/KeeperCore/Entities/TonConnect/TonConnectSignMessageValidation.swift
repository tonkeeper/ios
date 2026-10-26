import Foundation
import TonSwift

@frozen public enum TonConnectSignMessageValidationError: Swift.Error, Equatable {
    case notSupported
    case invalidMessages
    case expired
    case networkMismatch
    case addressMismatch

    public var errorCode: TonConnect.SendResponseError.ErrorCode {
        switch self {
        case .notSupported:
            return .methodNotSupported
        case .invalidMessages, .expired, .networkMismatch, .addressMismatch:
            return .badRequest
        }
    }

    public var message: String {
        switch self {
        case .notSupported:
            return "Method not supported"
        case .invalidMessages:
            return "Invalid messages"
        case .expired:
            return "Request expired"
        case .networkMismatch:
            return "Wrong network"
        case .addressMismatch:
            return "Wrong address"
        }
    }
}

@frozen public enum TonConnectSignMessageValidation {
    public static func validate(
        _ request: SignRawRequest,
        wallet: Wallet,
        isSignMessageEnabled: Bool,
        sendService: SendService
    ) async throws(TonConnectSignMessageValidationError) {
        try await validate(
            request,
            wallet: wallet,
            isSignMessageEnabled: isSignMessageEnabled,
            now: sendService.getTimeoutSafely(wallet: wallet, TTL: 0)
        )
    }

    public static func validate(
        _ request: SignRawRequest,
        wallet: Wallet,
        isSignMessageEnabled: Bool,
        now: UInt64
    ) throws(TonConnectSignMessageValidationError) {
        guard isSignMessageEnabled, wallet.isTonConnectSignMessageAvailable else {
            throw .notSupported
        }

        let walletAddress: Address
        let maxMessages: Int
        do {
            walletAddress = try wallet.address
            maxMessages = try wallet.contract.maxMessages
        } catch {
            throw .notSupported
        }

        guard !request.messages.isEmpty,
              request.messages.count <= maxMessages,
              request.messages.allSatisfy(\.address.isFriendly)
        else {
            throw .invalidMessages
        }
        if let validUntil = request.validUntil, validUntil <= now {
            throw .expired
        }
        if let network = request.network, network != String(wallet.network.rawValue) {
            throw .networkMismatch
        }
        if let from = request.from, from != walletAddress {
            throw .addressMismatch
        }
    }
}

private extension AnyAddress {
    var isFriendly: Bool {
        guard case .friendlyAddress = self else {
            return false
        }
        return true
    }
}
