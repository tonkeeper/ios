@preconcurrency import BigInt
import Foundation
import TonSwift

public enum Deeplink: Equatable {
    public struct TransferData: Equatable {
        public let recipient: String
        public let amount: BigUInt?
        public let comment: String?
        public let jettonAddress: Address?
        /// Multichain asset the link pins, in catalog form (`ton/mainnet/coin`). Takes precedence
        /// over `jettonAddress`, which can only name a TON jetton.
        public let assetId: String?
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

    /// An ERC-681 transfer request. `chain` is nil when the link carried no `@chain_id`, which
    /// leaves the network — and therefore the token behind `contract` — undetermined.
    public struct EvmTransferData: Equatable, Sendable {
        public enum Asset: Equatable, Sendable {
            case native
            case erc20(contract: String)
        }

        public let recipient: String
        public let asset: Asset
        public let chain: MultichainChain?
        public let amount: BigUInt?

        public init(
            recipient: String,
            asset: Asset,
            chain: MultichainChain?,
            amount: BigUInt?
        ) {
            self.recipient = recipient
            self.asset = asset
            self.chain = chain
            self.amount = amount
        }
    }

    public enum Transfer: Equatable {
        case sendTransfer(TransferData)
        case multichainSendTransfer(MultichainRecipientCandidates)
        case evmSendTransfer(EvmTransferData)
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
    case staking
    case pool(Address)
    case swap(SwapData)
    case deposit(RampDeeplinkParameters)
    case withdraw(RampDeeplinkParameters)
    case action(eventId: String)
    case publish(sign: Data)
    case externalSign(ExternalSignDeeplink)
    case tonconnect(TonConnectPayload)
    case walletConnect(WalletConnectDeeplink)
    case dapp(URL)
    case battery(Battery)
    case browser(network: MultichainChain?)
    case migration
    case trading(gridID: String?)
    case tradeAsset(assetID: String)
    case story(storyId: String)
    case receive
    case backup
    case addWallet
    case main
    case raffle
}

public enum ExternalSignDeeplink: Equatable {
    case link(publicKey: TonSwift.PublicKey, name: String)
}
