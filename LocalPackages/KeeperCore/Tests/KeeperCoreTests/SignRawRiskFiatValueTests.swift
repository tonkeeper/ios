import BigInt
import Foundation
@testable import KeeperCore
import TonAPI
import TonSwift
import XCTest

final class SignRawRiskFiatValueTests: XCTestCase {
    private let address = "0:" + String(repeating: "1", count: 64)

    func test_batteryServerTotalWithUnspecifiedCurrency_isNotUsed() throws {
        var input = risk(ton: 0)
        input.totalEquivalent = 12.5

        XCTAssertNil(try SignRawRiskFiatValue.serverTotal(risk: input, transferType: .battery(excessAddress: Address.parse(address))))
        XCTAssertEqual(SignRawRiskFiatValue.serverTotal(risk: input, transferType: .default), 12.5)
    }

    func test_invalidServerTotals_stayUnavailable() {
        for value: Float in [-1, .nan, .infinity] {
            var input = risk(ton: 0)
            input.totalEquivalent = value

            XCTAssertNil(SignRawRiskFiatValue.serverTotal(risk: input, transferType: .default))
        }
    }

    func test_batteryJettonTransferWithoutServerTotal_pricesTonAndJettons() throws {
        let total = try XCTUnwrap(SignRawRiskFiatValue.calculate(
            risk: risk(ton: 50_000_000, jettons: [jetton(quantity: "2500000")]),
            rates: rates(ton: 2, jetton: 1),
            currency: .USD
        ))

        XCTAssertEqual(total, 2.6, accuracy: 0.000_001)
    }

    func test_zeroTon_doesNotRequireTonRate() throws {
        let total = try XCTUnwrap(SignRawRiskFiatValue.calculate(
            risk: risk(ton: 0, jettons: [jetton(quantity: "2500000")]),
            rates: rates(ton: nil, jetton: 1),
            currency: .USD
        ))

        XCTAssertEqual(total, 2.5, accuracy: 0.000_001)
    }

    func test_missingJettonRate_doesNotReturnPartialTonTotal() {
        XCTAssertNil(SignRawRiskFiatValue.calculate(
            risk: risk(ton: 50_000_000, jettons: [jetton(quantity: "2500000")]),
            rates: rates(ton: 2, jetton: nil),
            currency: .USD
        ))
    }

    func test_missingDisplayCurrency_doesNotUseDifferentCurrency() {
        XCTAssertNil(try SignRawRiskFiatValue.calculate(
            risk: risk(ton: 50_000_000),
            rates: rates(ton: 2, jetton: nil),
            currency: XCTUnwrap(Currency(code: "EUR"))
        ))
    }

    func test_friendlyJettonRateAddress_matchesRawRiskAddress() throws {
        let friendly = try Address.parse(address).toFriendly().toString()
        let total = try XCTUnwrap(SignRawRiskFiatValue.calculate(
            risk: risk(ton: 0, jettons: [jetton(quantity: "2500000")]),
            rates: Rates(ton: [], usdt: [], jettonRates: [friendly: [rate(1)]]),
            currency: .USD
        ))

        XCTAssertEqual(total, 2.5, accuracy: 0.000_001)
    }

    func test_zeroQuantity_doesNotRequireJettonRate() {
        XCTAssertEqual(SignRawRiskFiatValue.calculate(
            risk: risk(ton: 0, jettons: [jetton(quantity: "0")]),
            rates: rates(ton: nil, jetton: nil),
            currency: .USD
        ), 0)
    }

    func test_nftRisk_doesNotShowTokenSubtotalAsFullValue() {
        var input = risk(ton: 50_000_000)
        input.nfts = [.init(
            address: address,
            index: 1,
            verified: true,
            metadata: .init(),
            approvedBy: .init(value1: []),
            trust: .whitelist
        )]

        XCTAssertNil(SignRawRiskFiatValue.calculate(
            risk: input,
            rates: rates(ton: 2, jetton: nil),
            currency: .USD
        ))
    }

    func test_invalidQuantityOrRate_doesNotUnderstateRisk() {
        for quantity in ["-1", "invalid"] {
            XCTAssertNil(SignRawRiskFiatValue.calculate(
                risk: risk(ton: 0, jettons: [jetton(quantity: quantity)]),
                rates: rates(ton: nil, jetton: 1),
                currency: .USD
            ))
        }
        for invalidRate: Decimal in [0, -1, .nan] {
            XCTAssertNil(SignRawRiskFiatValue.calculate(
                risk: risk(ton: 1),
                rates: rates(ton: invalidRate, jetton: nil),
                currency: .USD
            ))
        }
    }

    private func risk(ton: Int64, jettons: [TonAPI.Components.Schemas.JettonQuantity] = []) -> TonAPI.Components.Schemas.Risk {
        .init(transferAllRemainingBalance: false, gram: ton, jettons: jettons, nfts: [])
    }

    private func jetton(quantity: String) -> TonAPI.Components.Schemas.JettonQuantity {
        .init(
            quantity: quantity,
            walletAddress: .init(address: address, isScam: false, isWallet: true),
            jetton: .init(address: address, name: "Test", symbol: "TEST", decimals: 6, image: "", verification: .whitelist, score: 100)
        )
    }

    private func rates(ton: Decimal?, jetton: Decimal?) -> Rates {
        Rates(ton: ton.map { [rate($0)] } ?? [], usdt: [], jettonRates: jetton.map { [address: [rate($0)]] } ?? [:])
    }

    private func rate(_ value: Decimal) -> Rates.Rate {
        .init(currency: .USD, rate: value, diff24h: nil)
    }
}
