import Foundation

public struct TronUSDTTransactionConfirmationState {
    public struct Resources {
        public let energy: Int
        public let bandwidth: Int

        public init(energy: Int, bandwidth: Int) {
            self.energy = energy
            self.bandwidth = bandwidth
        }

        public static let empty = Resources(energy: 0, bandwidth: 0)
    }

    public var extraState: TransactionConfirmationModel.ExtraState = .loading
    public var extraOptions: [TransactionConfirmationModel.ExtraOption] = []
    public var availableTypes: [TransactionConfirmationModel.ExtraType] = []
    public var preferredExtraType: TransactionConfirmationModel.ExtraType?
    public var resources: Resources = .empty
    public var tonFeeAddress: String?

    public init() {}

    public var selectedExtraType: TransactionConfirmationModel.ExtraType {
        if let preferredExtraType, availableTypes.contains(preferredExtraType) {
            return preferredExtraType
        }

        if case let .extra(extra) = extraState {
            return extra.value.extraType
        }

        return availableTypes.first ?? .battery
    }
}
