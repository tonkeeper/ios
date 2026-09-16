import Foundation

public final class MappersAssembly {
    private let formattersAssembly: FormattersAssembly

    init(formattersAssembly: FormattersAssembly) {
        self.formattersAssembly = formattersAssembly
    }

    public var historyAccountEventMapper: AccountEventMapper {
        AccountEventMapper(
            dateFormatter: formattersAssembly.dateFormatter,
            amountFormatter: formattersAssembly.signedAmountFormatter
        )
    }
}
