@preconcurrency import BigInt

extension OperationIntent {
    /// What a send is held to: the amount of the asset the user confirmed sending to `recipient`,
    /// and the fee a relayer takes in a token besides it.
    static func send(
        _ amount: BigUInt,
        of asset: MultichainAssetDetails,
        to recipient: String?,
        fee: Spend? = nil
    ) -> OperationIntent {
        .wallet(spending: [Spend(amount, of: asset)], relayerFee: fee, to: recipient)
    }
}

extension OperationIntent.Spend {
    init(_ amount: BigUInt, of asset: MultichainAssetDetails) {
        self.init(assetId: asset.assetId, symbol: asset.symbol, decimals: asset.decimals, amount: amount)
    }

    /// A relayer's fee in a token at the most the app lets it rise to past the `confirmed` one.
    static func relayerFee(_ confirmed: BigUInt, in asset: MultichainAssetDetails) -> Self {
        Self(MultichainSwapBatteryFeeRules.toleratedRequote(of: confirmed), of: asset)
    }
}
