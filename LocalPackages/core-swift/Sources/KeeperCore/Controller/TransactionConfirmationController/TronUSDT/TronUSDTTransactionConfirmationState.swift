import Foundation

struct TronUSDTTransactionConfirmationState {
    struct Resources {
        let energy: Int
        let bandwidth: Int

        static let empty = Resources(energy: 0, bandwidth: 0)
    }

    var extraState: TransactionConfirmationModel.ExtraState = .loading
    var extraOptions: [TransactionConfirmationModel.ExtraOption] = []
    var availableTypes: [TransactionConfirmationModel.ExtraType] = []
    var preferredExtraType: TransactionConfirmationModel.ExtraType?
    var resources: Resources = .empty
    var tonFeeAddress: String?

    var selectedExtraType: TransactionConfirmationModel.ExtraType {
        if let preferredExtraType, availableTypes.contains(preferredExtraType) {
            return preferredExtraType
        }

        if case let .extra(extra) = extraState {
            return extra.value.extraType
        }

        return availableTypes.first ?? .battery
    }
}
