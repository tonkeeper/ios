import BigInt
import Foundation
import TonSwift
import TronSwift

public struct TronUSDTFeeOptionsResolver {
    public struct Result {
        public let availableTypes: [TransactionConfirmationModel.ExtraType]
        public let selectedType: TransactionConfirmationModel.ExtraType
        public let extraOptions: [TransactionConfirmationModel.ExtraOption]
        public let selectedExtra: TransactionConfirmationModel.Extra
        public let resources: TronUSDTTransactionConfirmationState.Resources
        public let tonFeeAddress: String?
    }

    private let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func canSelect(extraType: TransactionConfirmationModel.ExtraType) -> Bool {
        switch extraType {
        case .default, .battery:
            return true
        case .gasless:
            return isTRXType(extraType)
        case .multichain:
            return false
        }
    }

    public func isTRXType(_ extraType: TransactionConfirmationModel.ExtraType) -> Bool {
        extraType.isTRXGasless
    }

    /// - Parameter requiresSelfPaidTRX: the transfer moves TRX itself, so its fee comes out of the
    /// same balance and is paid in TRX. Account creation forces the same thing on any transfer.
    public func resolve(
        estimate: TronTransferFeeEstimate,
        wallet: Wallet,
        preferredExtraType: TransactionConfirmationModel.ExtraType?,
        requiresSelfPaidTRX: Bool = false
    ) -> Result {
        let requiredTONAmountNano = estimate.requiredTONAmountNano

        let availableTypes = Self.availableTypes(
            isTRXOnlyRegion: configuration.isTRXOnlyRegion(network: wallet.network),
            isTONBillingAvailable: estimate.tonFeeAddress?.isEmpty == false && requiredTONAmountNano != nil,
            requiresSelfPaidTRX: requiresSelfPaidTRX || estimate.requiresSelfPaidTRX
        )
        let selectedType = resolveSelectedType(
            preferredExtraType: preferredExtraType,
            availableTypes: availableTypes
        )

        let extraOptions = availableTypes.map {
            TransactionConfirmationModel.ExtraOption(
                type: $0,
                value: makeExtraValue(type: $0, estimate: estimate, requiredTONAmountNano: requiredTONAmountNano)
            )
        }

        let selectedExtra = TransactionConfirmationModel.Extra(
            value: makeExtraValue(type: selectedType, estimate: estimate, requiredTONAmountNano: requiredTONAmountNano),
            kind: .fee
        )

        return Result(
            availableTypes: availableTypes,
            selectedType: selectedType,
            extraOptions: extraOptions,
            selectedExtra: selectedExtra,
            resources: .init(energy: estimate.energy, bandwidth: estimate.bandwidth),
            tonFeeAddress: estimate.tonFeeAddress
        )
    }

    /// A cost the sender has to pay in TRX leaves no room for a sponsor, so the relayer's options
    /// are dropped rather than quoted for a fee they cannot settle.
    static func availableTypes(
        isTRXOnlyRegion: Bool,
        isTONBillingAvailable: Bool,
        requiresSelfPaidTRX: Bool
    ) -> [TransactionConfirmationModel.ExtraType] {
        if isTRXOnlyRegion || requiresSelfPaidTRX {
            return [.gasless(token: trxFeeToken)]
        }
        var types: [TransactionConfirmationModel.ExtraType] = [.battery]
        if isTONBillingAvailable {
            types.append(.default)
        }
        types.append(.gasless(token: Self.trxFeeToken))
        return types
    }

    private func resolveSelectedType(
        preferredExtraType: TransactionConfirmationModel.ExtraType?,
        availableTypes: [TransactionConfirmationModel.ExtraType]
    ) -> TransactionConfirmationModel.ExtraType {
        if let preferredExtraType,
           availableTypes.contains(preferredExtraType),
           canSelect(extraType: preferredExtraType)
        {
            return preferredExtraType
        }

        return availableTypes.first ?? .battery
    }

    private func makeExtraValue(
        type: TransactionConfirmationModel.ExtraType,
        estimate: TronTransferFeeEstimate,
        requiredTONAmountNano: BigUInt?
    ) -> TransactionConfirmationModel.ExtraValue {
        switch type {
        case .battery:
            return .battery(charges: estimate.requiredBatteryCharges, excess: nil)
        case .default:
            return .default(amount: requiredTONAmountNano ?? 0)
        case let .gasless(token):
            if token.symbol?.uppercased() == TRX.symbol.uppercased() {
                return .gasless(token: Self.trxFeeToken, amount: estimate.selfPaidTRXSun)
            }
            return .battery(charges: estimate.requiredBatteryCharges, excess: nil)
        case let .multichain(token):
            return .multichain(token: token, amount: 0)
        }
    }

    public static let trxFeeToken: JettonInfo = JettonInfo(
        isTransferable: true,
        hasCustomPayload: false,
        address: try! Address.parse("0:0000000000000000000000000000000000000000000000000000000000000001"),
        fractionDigits: TRX.fractionDigits,
        name: TRX.name,
        symbol: TRX.symbol,
        verification: .whitelist,
        imageURL: nil
    )
}
