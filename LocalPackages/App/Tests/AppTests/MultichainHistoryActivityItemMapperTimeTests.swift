@testable import App
import Foundation
@testable import KeeperCore
import XCTest

@MainActor
final class MultichainHistoryActivityItemMapperTimeTests: XCTestCase {
    func test_timeOnly_isTheDefaultAndShowsJustTheClock() {
        let mapper = makeMapper()

        XCTAssertEqual(mapper.makeItem(activity: activity(at: pastYearDate)).time, "14:30")
    }

    func test_dateAndTime_addsTheYearOutsideTheCurrentOne() {
        let mapper = makeMapper(timeStyle: .dateAndTime)

        XCTAssertEqual(mapper.makeItem(activity: activity(at: pastYearDate)).time, "10 Oct 2020, 14:30")
    }

    func test_dateAndTime_keepsJustTheClockForToday() {
        let mapper = makeMapper(timeStyle: .dateAndTime)
        let now = Date()
        let formatter = makeDateFormatter()

        formatter.dateFormat = "HH:mm"
        XCTAssertEqual(mapper.makeItem(activity: activity(at: now)).time, formatter.string(from: now))
    }

    func test_dateAndTime_omitsTheYearInsideTheCurrentOne() throws {
        let mapper = makeMapper(timeStyle: .dateAndTime)
        let formatter = makeDateFormatter()
        let calendar = formatter.calendar ?? .current
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: Date()))
        // January 1st: yesterday falls in the previous year, so the sample moves one day forward instead.
        let sample = calendar.isDate(yesterday, equalTo: Date(), toGranularity: .year)
            ? yesterday
            : calendar.date(byAdding: .day, value: 1, to: Date())!

        formatter.dateFormat = "d MMM, HH:mm"
        XCTAssertEqual(mapper.makeItem(activity: activity(at: sample)).time, formatter.string(from: sample))
    }
}

private extension MultichainHistoryActivityItemMapperTimeTests {
    /// 2020-10-10 14:30:00 UTC
    var pastYearDate: Date {
        Date(timeIntervalSince1970: 1_602_340_200)
    }

    func makeMapper(timeStyle: MultichainHistoryActivityItemMapper.TimeStyle = .timeOnly) -> MultichainHistoryActivityItemMapper {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        return MultichainHistoryActivityItemMapper(
            amountFormatter: AmountFormatter(configuration: configuration),
            dateFormatter: makeDateFormatter(),
            timeStyle: timeStyle
        )
    }

    func makeDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }

    func activity(at blockTime: Date) -> MultichainActivity {
        MultichainActivity(
            activityType: .receive,
            status: .confirmed,
            blockTime: blockTime,
            blockNumber: nil,
            fromChain: nil,
            toChain: nil,
            walletAddress: "0xwallet",
            direction: .incoming,
            fromAddress: nil,
            toAddress: nil,
            outToken: nil,
            outAmount: nil,
            outAmountUsd: nil,
            inToken: nil,
            inAmount: nil,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: ["tx"],
            isRead: nil,
            perps: nil
        )
    }
}
