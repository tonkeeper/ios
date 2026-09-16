import SwapAPI

public struct MultichainSwapHumanSummary: Sendable, Hashable {
    public var action: String
    public var spendAsset: String
    public var spendAmount: String
    public var receiveAsset: String
    public var receiveAmount: String?
    public var recipientAddress: String?
    public var depositAddress: String?
    public var memo: String?
    public var protocolSlug: String?
    public var approvalSpender: String?
    public var approvalAmount: String?
    public var warnings: [String]?

    public init(
        action: String,
        spendAsset: String,
        spendAmount: String,
        receiveAsset: String,
        receiveAmount: String? = nil,
        recipientAddress: String? = nil,
        depositAddress: String? = nil,
        memo: String? = nil,
        protocolSlug: String? = nil,
        approvalSpender: String? = nil,
        approvalAmount: String? = nil,
        warnings: [String]? = nil
    ) {
        self.action = action
        self.spendAsset = spendAsset
        self.spendAmount = spendAmount
        self.receiveAsset = receiveAsset
        self.receiveAmount = receiveAmount
        self.recipientAddress = recipientAddress
        self.depositAddress = depositAddress
        self.memo = memo
        self.protocolSlug = protocolSlug
        self.approvalSpender = approvalSpender
        self.approvalAmount = approvalAmount
        self.warnings = warnings
    }
}

extension MultichainSwapHumanSummary {
    init(api: SwapAPI.Components.Schemas.CrossSwapHumanSummary) {
        self.init(
            action: api.action,
            spendAsset: api.spend_asset,
            spendAmount: api.spend_amount,
            receiveAsset: api.receive_asset,
            receiveAmount: api.receive_amount,
            recipientAddress: api.recipient_address,
            depositAddress: api.deposit_address,
            memo: api.memo,
            protocolSlug: api._protocol,
            approvalSpender: api.approval_spender,
            approvalAmount: api.approval_amount,
            warnings: api.warnings
        )
    }
}
