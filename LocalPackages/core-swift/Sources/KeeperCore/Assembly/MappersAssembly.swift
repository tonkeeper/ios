import Foundation

public final class MappersAssembly {
  
  private let formattersAssembly: FormattersAssembly
  
  init(formattersAssembly: FormattersAssembly) {
    self.formattersAssembly = formattersAssembly
  }
  
  public var historyAccountEventMapper: AccountEventMapper {
    AccountEventMapper(
      dateFormatter: formattersAssembly.dateFormatter,
      amountFormatter: formattersAssembly.amountFormatter,
      amountMapper: SignedAccountEventAmountMapper(
        plainAccountEventAmountMapper: PlainAccountEventAmountMapper(
          amountFormatter: formattersAssembly.amountFormatter
        )
      )
    )
  }
  
  public var confirmationAccountEventMapper: AccountEventMapper {
    AccountEventMapper(
      dateFormatter: formattersAssembly.dateFormatter,
      amountFormatter: formattersAssembly.amountFormatter,
      amountMapper: PlainAccountEventAmountMapper(
        amountFormatter: formattersAssembly.amountFormatter
      )
    )
  }
}
