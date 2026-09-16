import Foundation
import KeeperCore

public final class ChartFormatter {
    private let amountFormatter: AmountFormatter
    private let signedAmountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter

    init(
        dateFormatter: DateFormatter,
        amountFormatter: AmountFormatter,
        signedAmountFormatter: AmountFormatter
    ) {
        self.dateFormatter = dateFormatter
        self.dateFormatter.locale = Locale.current
        self.amountFormatter = amountFormatter
        self.signedAmountFormatter = signedAmountFormatter
    }

    public func formatInformationTimeInterval(
        _ timeInterval: TimeInterval,
        period: Period
    ) -> String? {
        let dateFormat: String
        switch period {
        case .hour: dateFormat = "E',' d MMM HH:mm"
        case .day: dateFormat = "E',' d MMM HH:mm"
        case .week: dateFormat = "E',' d MMM HH:mm"
        case .month: dateFormat = "E',' d MMM"
        case .halfYear: dateFormat = "yyyy E',' d MMM"
        case .year: dateFormat = "yyyy E',' d MMM"
        }

        dateFormatter.dateFormat = dateFormat

        return dateFormatter.string(from: Date(timeIntervalSince1970: timeInterval))
    }

    public func formatXAxis(timeInterval: TimeInterval, period: Period) -> String? {
        let dateFormat: String
        switch period {
        case .hour: dateFormat = "HH:mm"
        case .day: dateFormat = "HH:mm"
        case .week: dateFormat = "dd MMM"
        case .month: dateFormat = "dd MMM"
        case .halfYear: dateFormat = "dd MMM"
        case .year: dateFormat = "dd MMM"
        }

        dateFormatter.dateFormat = dateFormat

        return dateFormatter.string(from: Date(timeIntervalSince1970: timeInterval))
    }

    public func mapMaxMinValue(value: Double, currency: Currency) -> String {
        amountFormatter.format(
            decimal: Decimal(floatLiteral: value),
            accessory: .fiat(currency),
            style: .compact
        )
    }

    public func formatValue(coordinate: Coordinate, currency: Currency) -> String {
        amountFormatter.format(
            decimal: Decimal(coordinate.y),
            accessory: .fiat(currency),
            style: .compact
        )
    }

    public func formatDiff(diff: Double) -> String {
        signedAmountFormatter.format(
            decimal: Decimal(floatLiteral: diff),
            style: .percent
        )
    }

    public func formatCurrencyDiff(diff: Double, currency: Currency) -> String {
        amountFormatter.format(
            decimal: Decimal(abs(diff)),
            accessory: .fiat(currency),
            style: .compact
        )
    }
}
