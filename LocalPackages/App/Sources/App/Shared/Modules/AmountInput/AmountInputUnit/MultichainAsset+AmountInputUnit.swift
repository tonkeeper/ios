import KeeperCore

extension MultichainAsset: AmountInputUnit {
    var inputSymbol: AmountInputSymbol {
        .text(asset.symbol)
    }

    var fractionalDigits: Int {
        asset.decimals
    }

    var symbol: String {
        asset.symbol
    }
}
