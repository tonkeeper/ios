import KeeperCore

extension Currency: AmountInputUnit {
    var inputSymbol: AmountInputSymbol {
        .text(self.code)
    }

    var fractionalDigits: Int {
        2
    }
}

extension RemoteCurrency: AmountInputUnit {
    var symbol: String {
        Currency(code: self.code)?.symbol ?? self.code
    }

    var inputSymbol: AmountInputSymbol {
        .text(self.code)
    }

    var fractionalDigits: Int {
        2
    }
}
