@preconcurrency import BigInt
import Foundation
import TonSwift

@frozen public enum Deeplink: Equatable {
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
        @frozen public enum Asset: Equatable, Sendable {
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

    /// A Solana Pay transfer request. `amount` counts whole units of the asset (SOL, not
    /// lamports), so it has an atomic value only once the asset's decimals are known.
    public struct SolanaTransferData: Equatable, Sendable {
        @frozen public enum Asset: Equatable, Sendable {
            case native
            case splToken(mint: String)

            public var assetId: String {
                switch self {
                case .native:
                    MultichainChain.sol.defaultSendAssetId
                case let .splToken(mint):
                    "sol/mainnet/spl/\(mint)"
                }
            }
        }

        public let recipient: String
        public let asset: Asset
        public let amount: DecimalAmount?

        public init(
            recipient: String,
            asset: Asset,
            amount: DecimalAmount?
        ) {
            self.recipient = recipient
            self.asset = asset
            self.amount = amount
        }
    }

    /// A plain decimal number of whole token units, such as `0.001`: no sign, exponent or
    /// grouping, and at least one digit before the separator.
    public struct DecimalAmount: Equatable, Sendable {
        private let digits: BigUInt
        private let fractionDigits: Int

        init?(_ string: String) {
            let parts = string.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let integer = String(parts[0])
            var fraction = parts.count == 2 ? String(parts[1]) : ""
            while fraction.hasSuffix("0") {
                fraction.removeLast()
            }
            guard !integer.isEmpty,
                  (integer + fraction).allSatisfy({ $0.isASCII && $0.isNumber }),
                  let digits = BigUInt(integer + fraction)
            else {
                return nil
            }
            self.digits = digits
            fractionDigits = fraction.count
        }

        /// `nil` when the amount is finer than `decimals` allow: it is never rounded.
        public func atomicUnits(decimals: Int) -> BigUInt? {
            guard fractionDigits <= decimals else {
                return nil
            }
            return digits * BigUInt(10).power(decimals - fractionDigits)
        }
    }

    @frozen public enum Transfer: Equatable {
        case sendTransfer(TransferData)
        case multichainSendTransfer(MultichainRecipientCandidates)
        case evmSendTransfer(EvmTransferData)
        case solanaSendTransfer(SolanaTransferData)
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

    @frozen public enum Perps: Equatable {
        case home
        case market(id: Int64)
        case autoClose(marketId: Int64)
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
    case perps(Perps)
    case history
}

@frozen public enum ExternalSignDeeplink: Equatable {
    case link(publicKey: TonSwift.PublicKey, name: String)
}
