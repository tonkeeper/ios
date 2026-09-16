@testable import App
import BigInt
@testable import KeeperCore
import TronSwift
import XCTest

final class BalanceItemModelsTests: XCTestCase {
    func test_zeroTronAssetsAreExcluded() {
        let items = BalanceItems(balance: makeBalance(), stackingPools: []).items

        XCTAssertFalse(items.contains(where: isTronUSDT))
        XCTAssertFalse(items.contains(where: isTronTRX))
    }

    func test_positiveTronAssetsAreIncluded() {
        let items = BalanceItems(
            balance: makeBalance(usdtAmount: 1, trxAmount: 1),
            stackingPools: []
        ).items

        XCTAssertTrue(items.contains(where: isTronUSDT))
        XCTAssertTrue(items.contains(where: isTronTRX))
    }
}

private extension BalanceItemModelsTests {
    func makeBalance(
        usdtAmount: BigUInt = 0,
        trxAmount: BigUInt = 0
    ) -> ConvertedBalance {
        ConvertedBalance(
            date: .distantPast,
            currency: .USD,
            tonBalance: ConvertedTonBalance(
                tonBalance: TonBalance(amount: 0),
                converted: 0,
                price: 0,
                diff: nil
            ),
            jettonsBalance: [],
            stackingBalance: [],
            tronUSDT: ConvertedBalanceTronUSDTItem(
                amount: usdtAmount,
                converted: 0,
                price: 0,
                diff: nil
            ),
            tronTRX: ConvertedBalanceTronTRXItem(
                amount: trxAmount,
                converted: 0,
                price: 0,
                diff: nil
            ),
            batteryBalance: nil
        )
    }

    func isTronUSDT(_ item: BalanceItem) -> Bool {
        if case .tronUSDT = item {
            return true
        }
        return false
    }

    func isTronTRX(_ item: BalanceItem) -> Bool {
        if case .tronTRX = item {
            return true
        }
        return false
    }
}
