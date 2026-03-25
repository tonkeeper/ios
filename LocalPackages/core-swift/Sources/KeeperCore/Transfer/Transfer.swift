import BigInt
import Foundation
import TonSwift
import TronSwift

public enum Transfer {
    case ton(amount: BigUInt, recipient: TonRecipient, comment: String?)
    case jetton(JettonItem, transferAmount: BigUInt, amount: BigUInt, recipient: TonRecipient, comment: String?)
    case nft(NFT, transferAmount: BigUInt, recipient: TonRecipient, comment: String?)
    case stonfiSwap(SignRawRequest)
    case nativeSwap(SwapConfirmation)
    case signRaw(SignRawRequest, forceRelayer: Bool)
    case renewDNS(nft: NFT)

    public var messagesCount: Int {
        switch self {
        case let .stonfiSwap(request):
            return request.messages.count
        case let .signRaw(request, _):
            return request.messages.count
        case let .nativeSwap(request):
            return request.messages.count
        case .renewDNS:
            return 1
        case .ton, .jetton, .nft:
            return 1
        }
    }
}
