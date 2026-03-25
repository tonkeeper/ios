import BigInt
import Foundation
import TonSwift

public enum Deeplink: Equatable {
    public struct TransferData: Equatable {
        public let recipient: String
        public let amount: BigUInt?
        public let comment: String?
        public let jettonAddress: Address?
        public let expirationTimestamp: Int64?
        public let successReturn: URL?
    }

    public struct RawTransferData: Equatable {
        public let recipient: String
        public let amount: BigUInt?
        public let jettonAddress: Address?
        public let bin: String?
        public let stateInit: String?
        public let expirationTimestamp: Int64?
    }

    public enum Transfer: Equatable {
        case sendTransfer(TransferData)
        case signRawTransfer(RawTransferData)
    }

    public struct SwapData: Equatable {
        public let fromToken: String?
        public let toToken: String?
    }

    public struct Battery: Equatable {
        public let promocode: String?
        public let masterJettonAddress: Address?
    }

    case transfer(Transfer)
    case buyTon
    case staking
    case pool(Address)
    case exchange(provider: String?)
    case swap(SwapData)
    case action(eventId: String)
    case publish(sign: Data)
    case externalSign(ExternalSignDeeplink)
    case tonconnect(TonConnectPayload)
    case dapp(URL)
    case battery(Battery)
    case browser
    case story(storyId: String)
    case receive
    case backup
}

public enum ExternalSignDeeplink: Equatable {
    case link(publicKey: TonSwift.PublicKey, name: String)
}
