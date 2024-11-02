import KeeperCore

extension Token: AmountInputUnit {
  var inputSymbol: AmountInputSymbol {
    .text(self.symbol)
  }
  
  var fractionalDigits: Int {
    self.fractionDigits
  }
}
