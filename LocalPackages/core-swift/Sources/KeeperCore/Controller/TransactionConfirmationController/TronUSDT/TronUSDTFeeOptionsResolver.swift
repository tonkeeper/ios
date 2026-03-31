import BigInt
import Foundation
import TonSwift
import TronSwift

struct TronUSDTFeeOptionsResolver {
    struct Result {
        let availableTypes: [TransactionConfirmationModel.ExtraType]
        let selectedType: TransactionConfirmationModel.ExtraType
        let extraOptions: [TransactionConfirmationModel.ExtraOption]
        let selectedExtra: TransactionConfirmationModel.Extra
        let resources: TronUSDTTransactionConfirmationState.Resources
        let tonFeeAddress: String?
    }

    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func canSelect(extraType: TransactionConfirmationModel.ExtraType) -> Bool {
        switch extraType {
        case .default, .battery:
            return true
        case .gasless:
            return isTRXType(extraType)
        }
    }

    func isTRXType(_ extraType: TransactionConfirmationModel.ExtraType) -> Bool {
        guard case let .gasless(token) = extraType else {
            return false
        }
        return token.symbol?.uppercased() == TRX.symbol.uppercased()
    }

    func resolve(
        estimate: TronTransferFeeEstimate,
        wallet: Wallet,
        preferredExtraType: TransactionConfirmationModel.ExtraType?
    ) -> Result {
        let requiredTONAmountNano = estimate.requiredTONAmountNano

        let availableTypes = makeAvailableTypes(
            isTRXOnlyRegion: configuration.isTRXOnlyRegion(network: wallet.network),
            isTONBillingAvailable: estimate.tonFeeAddress?.isEmpty == false && requiredTONAmountNano != nil
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

    private func makeAvailableTypes(
        isTRXOnlyRegion: Bool,
        isTONBillingAvailable: Bool
    ) -> [TransactionConfirmationModel.ExtraType] {
        if isTRXOnlyRegion {
            return [.gasless(token: Self.trxFeeToken)]
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
                return .gasless(token: Self.trxFeeToken, amount: estimate.requiredTRXSun)
            }
            return .battery(charges: estimate.requiredBatteryCharges, excess: nil)
        }
    }

    private static let trxFeeToken: JettonInfo = JettonInfo(
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
