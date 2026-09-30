import BigInt
import Foundation
@testable import KeeperCore
import TonSwift
import TronSwift
import XCTest

final class BalanceListOrderTests: XCTestCase {
    func test_assetKindsFollowTheProductOrder() {
        let items: [ProcessedBalanceItem] = [
            makeJetton(address: unverifiedAddress, verification: .none, converted: 900),
            makeEthena(converted: 10),
            makeStaking(pool: firstPoolAddress, converted: 20),
            makeTronTRX(converted: 30),
            makeJetton(address: whitelistAddress, verification: .whitelist, converted: 40),
            makeJetton(address: JettonMasterAddress.tonUSDT, verification: .whitelist, converted: 1),
            makeTronUSDT(converted: 2),
        ]

        let sorted = items.sorted(by: ProcessedBalanceItem.isOrderedBeforeInBalanceList)

        XCTAssertEqual(sorted.map(\.identifier), [
            USDT.address.base58,
            JettonMasterAddress.tonUSDT.toRaw(),
            firstPoolAddress.toRaw(),
            whitelistAddress.toRaw(),
            TRX.symbol,
            JettonMasterAddress.USDe.toRaw(),
            unverifiedAddress.toRaw(),
        ])
    }

    func test_trxAndUSDeCompeteWithWhitelistJettonsByFiatAmount() {
        let items: [ProcessedBalanceItem] = [
            makeJetton(address: whitelistAddress, verification: .whitelist, converted: 20),
            makeTronTRX(converted: 30),
            makeEthena(converted: 10),
        ]

        let sorted = items.sorted(by: ProcessedBalanceItem.isOrderedBeforeInBalanceList)

        XCTAssertEqual(sorted.map(\.identifier), [
            TRX.symbol,
            whitelistAddress.toRaw(),
            JettonMasterAddress.USDe.toRaw(),
        ])
    }

    func test_stakingsOutrankEveryJettonButTonUSDT() {
        let items: [ProcessedBalanceItem] = [
            makeJetton(address: whitelistAddress, verification: .whitelist, converted: 1000),
            makeStaking(pool: firstPoolAddress, converted: 1),
            makeJetton(address: JettonMasterAddress.tonUSDT, verification: .whitelist, converted: 1),
        ]

        let sorted = items.sorted(by: ProcessedBalanceItem.isOrderedBeforeInBalanceList)

        XCTAssertEqual(sorted.map(\.identifier), [
            JettonMasterAddress.tonUSDT.toRaw(),
            firstPoolAddress.toRaw(),
            whitelistAddress.toRaw(),
        ])
    }

    func test_stakingsAreOrderedByFiatAmount() {
        let items: [ProcessedBalanceItem] = [
            makeStaking(pool: firstPoolAddress, converted: 5),
            makeStaking(pool: secondPoolAddress, converted: 50),
        ]

        let sorted = items.sorted(by: ProcessedBalanceItem.isOrderedBeforeInBalanceList)

        XCTAssertEqual(sorted.map(\.identifier), [secondPoolAddress.toRaw(), firstPoolAddress.toRaw()])
    }

    func test_unverifiedJettonsKeepADeterministicOrderWithoutRates() {
        let items: [ProcessedBalanceItem] = [
            makeJetton(address: unverifiedAddress, verification: .none, converted: 0),
            makeJetton(address: graylistAddress, verification: .graylist, converted: 0),
        ]

        let expected = [graylistAddress.toRaw(), unverifiedAddress.toRaw()].sorted()

        XCTAssertEqual(
            items.sorted(by: ProcessedBalanceItem.isOrderedBeforeInBalanceList).map(\.identifier),
            expected
        )
        XCTAssertEqual(
            items.reversed().sorted(by: ProcessedBalanceItem.isOrderedBeforeInBalanceList).map(\.identifier),
            expected
        )
    }
}

private extension BalanceListOrderTests {
    var whitelistAddress: TonSwift.Address {
        try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000001")
    }

    var graylistAddress: TonSwift.Address {
        try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000002")
    }

    var unverifiedAddress: TonSwift.Address {
        try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000003")
    }

    var firstPoolAddress: TonSwift.Address {
        try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000004")
    }

    var secondPoolAddress: TonSwift.Address {
        try! TonSwift.Address.parse("0:0000000000000000000000000000000000000000000000000000000000000005")
    }

    func makeJetton(
        address: TonSwift.Address,
        verification: JettonInfo.Verification,
        converted: Decimal
    ) -> ProcessedBalanceItem {
        .jetton(makeJettonItem(address: address, verification: verification, converted: converted))
    }

    func makeJettonItem(
        address: TonSwift.Address,
        verification: JettonInfo.Verification,
        converted: Decimal
    ) -> ProcessedBalanceJettonItem {
        ProcessedBalanceJettonItem(
            id: address.toRaw(),
            jetton: JettonItem(
                jettonInfo: JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: address,
                    fractionDigits: 9,
                    name: address.toRaw(),
                    symbol: address.toRaw(),
                    verification: verification,
                    imageURL: nil
                ),
                walletAddress: address
            ),
            amount: BigUInt(1),
            fractionalDigits: 9,
            tag: nil,
            currency: .USD,
            converted: converted,
            price: 1,
            diff: nil,
            shouldCalculateInTotal: true
        )
    }

    func makeStaking(pool: TonSwift.Address, converted: Decimal) -> ProcessedBalanceItem {
        .staking(
            ProcessedBalanceStakingItem(
                id: pool.toRaw(),
                info: AccountStackingInfo(
                    pool: pool,
                    amount: 1,
                    pendingDeposit: 0,
                    pendingWithdraw: 0,
                    readyWithdraw: 0
                ),
                poolInfo: nil,
                jetton: nil,
                currency: .USD,
                amountConverted: converted,
                pendingDepositConverted: 0,
                pendingWithdrawConverted: 0,
                readyWithdrawConverted: 0,
                price: 1,
                shouldCalculateInTotal: true
            )
        )
    }

    func makeTronUSDT(converted: Decimal) -> ProcessedBalanceItem {
        .tronUSDT(
            ProcessedBalanceTronUSDTItem(
                id: USDT.address.base58,
                amount: BigUInt(1),
                trxAmount: BigUInt(1),
                fractionalDigits: 6,
                tag: nil,
                currency: .USD,
                converted: converted,
                price: 1,
                diff: nil,
                shouldCalculateInTotal: true
            )
        )
    }

    func makeTronTRX(converted: Decimal) -> ProcessedBalanceItem {
        .tronTRX(
            ProcessedBalanceTronTRXItem(
                id: TRX.symbol,
                amount: BigUInt(1),
                fractionalDigits: 6,
                currency: .USD,
                converted: converted,
                price: 1,
                diff: nil,
                shouldCalculateInTotal: true
            )
        )
    }

    func makeEthena(converted: Decimal) -> ProcessedBalanceItem {
        .ethena(
            ProcessedBalanceEthenaItem(
                usde: makeJettonItem(
                    address: JettonMasterAddress.USDe,
                    verification: .whitelist,
                    converted: converted
                ),
                stakedUsde: nil,
                amount: BigUInt(1),
                stakedAmount: 0,
                fractionalDigits: 6,
                tag: nil,
                currency: .USD,
                converted: converted,
                stakedConverted: 0,
                price: 1,
                diff: nil
            )
        )
    }
}
