import Foundation

public final class FormattersAssembly {
    public let amountFormatter: AmountFormatter = {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = .current
        configuration.space = String.Symbol.shortSpace
        return .init(configuration: configuration)
    }()

    public let signedAmountFormatter: AmountFormatter = {
        var configuration = AmountFormatter.Configuration()
        configuration.signPolicy = .always
        return .init(configuration: configuration)
    }()

    public var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        return dateFormatter
    }
}
