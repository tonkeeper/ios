import Foundation
import TKLogging

private let realtimeDisabledError = "realtime_disabled"

enum RealtimeTokenResult: Equatable {
    case token(String)
    case forbidden
    case disabledByBackend
    case failure(message: String)
}

struct RealtimeTokenSource {
    private let clientAPI: MultichainClientAPI

    init(clientAPI: MultichainClientAPI) {
        self.clientAPI = clientAPI
    }

    func connectionToken() async -> RealtimeTokenResult {
        do {
            return try .token(await clientAPI.getRealtimeConnectionToken())
        } catch {
            return mapError(error)
        }
    }

    func subscriptionToken(walletId: String) async -> RealtimeTokenResult {
        do {
            return try .token(await clientAPI.getWalletRealtimeToken(walletId: walletId))
        } catch {
            return mapError(error)
        }
    }

    private func mapError(_ error: Error) -> RealtimeTokenResult {
        guard let error = error as? MultichainClientAPIError else {
            return .failure(message: error.localizedDescription)
        }
        switch error {
        case .forbidden:
            return .forbidden
        case let .badStatus(message) where message.contains(realtimeDisabledError):
            Log.multichain.w("Realtime is disabled on the backend")
            return .disabledByBackend
        case let .badStatus(message):
            return .failure(message: message)
        case let .unauthorized(message):
            return .failure(message: message)
        case .cancelled:
            return .failure(message: "cancelled")
        case let .connectionError(underlying):
            return .failure(message: underlying?.localizedDescription ?? "connectionError")
        case let .badResponse(underlying):
            return .failure(message: underlying?.localizedDescription ?? "badResponse")
        case let .undocumented(statusCode):
            return .failure(message: "undocumented \(statusCode)")
        }
    }
}
