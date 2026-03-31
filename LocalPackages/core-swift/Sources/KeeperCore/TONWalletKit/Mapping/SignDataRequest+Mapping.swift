import Foundation
import TONWalletKit

public extension TonConnect.SignDataRequest {
    init(request: TONWalletSignDataRequest) {
        self = Self(
            params: TonConnectSignDataPayload(data: request.event.payload.data),
            id: request.event.id
        )
    }
}
