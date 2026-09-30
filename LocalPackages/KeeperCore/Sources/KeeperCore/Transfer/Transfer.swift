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
    case signRaw(SignRawRequest, forceRelayer: Bool, broadcast: Broadcast = .tonAPI)
    case renewDNS(nft: NFT)
    case multichainSwap(SignRawRequest)

    public enum Broadcast {
        case tonAPI
        case battery
    }

    /// An aggregator's swap payload already names the address its unspent TON returns to. Rewriting
    /// that to the relayer's excess address — which every other relayed transfer does — would hand
    /// the refund of a third-party swap to whoever paid its gas.
    var keepsPayloadExcessAddress: Bool {
        guard case .multichainSwap = self else {
            return false
        }
        return true
    }

    var broadcastsThroughBattery: Bool {
        guard case .signRaw(_, _, .battery) = self else {
            return false
        }
        return true
    }

    public var messagesCount: Int {
        switch self {
        case let .stonfiSwap(request), let .multichainSwap(request):
            return request.messages.count
        case let .signRaw(request, _, _):
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
