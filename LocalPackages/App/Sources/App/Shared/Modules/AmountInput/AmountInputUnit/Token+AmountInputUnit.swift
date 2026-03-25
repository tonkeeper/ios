import KeeperCore

extension TonToken: AmountInputUnit {
    var inputSymbol: AmountInputSymbol {
        .text(self.symbol)
    }

    var fractionalDigits: Int {
        self.fractionDigits
    }
}

extension Token: AmountInputUnit {
    var fractionalDigits: Int {
        self.fractionDigits
    }

    var inputSymbol: AmountInputSymbol {
        .text(self.symbol)
    }
}
