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
    var inputSymbol: AmountInputSymbol {
        .text(self.code)
    }

    var fractionalDigits: Int {
        2
    }
}
