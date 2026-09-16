@testable import App
import BigInt
@testable import KeeperCore
import TKLocalize
import TonSwift
import TronSwift
import XCTest

final class WalletMigrationConfirmationMapperTests: XCTestCase {
    func test_batteryCreditTonTransferIsNotDisplayedAsOutgoingSend() throws {
        let sourceAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
        let destinationAddress = "0:0000000000000000000000000000000000000000000000000000000000000002"

        let sourceAccount = try WalletAccount(
            address: TonSwift.Address.parse(sourceAddress),
            name: nil,
            isScam: false,
            isWallet: true
        )
        let destinationAccount = try WalletAccount(
            address: TonSwift.Address.parse(destinationAddress),
            name: nil,
            isScam: false,
            isWallet: true
        )
        let batteryAccount = try WalletAccount(
            address: TonSwift.Address.parse("0:1000000000000000000000000000000000000000000000000000000000000000"),
            name: nil,
            isScam: false,
            isWallet: false
        )
        let jettonAddress = try TonSwift.Address.parse("0:2000000000000000000000000000000000000000000000000000000000000000")

        let sponsoredTransaction = WalletMigrationPreparedTransaction(
            seqno: 0,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "0",
                date: Date(timeIntervalSince1970: 0),
                account: sourceAccount,
                isScam: false,
                isInProgress: false,
                extra: .Fee(1000),
                excess: nil,
                progress: nil,
                actions: [
                    makeTonTransferAction(
                        sender: batteryAccount,
                        recipient: sourceAccount,
                        amount: 100_000_000,
                        amountTitle: "0.1 GRAM"
                    ),
                    makeJettonTransferAction(
                        sender: sourceAccount,
                        recipient: destinationAccount,
                        jettonAddress: jettonAddress,
                        amount: 1,
                        amountTitle: "1 DYOR"
                    ),
                ]
            ),
            totalFees: 1000,
            totalEquivalent: 0.53,
            sponsored: true
        )

        let sweepTransaction = WalletMigrationPreparedTransaction(
            seqno: 1,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "1",
                date: Date(timeIntervalSince1970: 0),
                account: sourceAccount,
                isScam: false,
                isInProgress: false,
                extra: .Fee(1000),
                excess: nil,
                progress: nil,
                actions: [
                    makeTonTransferAction(
                        sender: sourceAccount,
                        recipient: destinationAccount,
                        amount: 112_102_521,
                        amountTitle: "0.112102521 GRAM"
                    ),
                ]
            ),
            totalFees: 1000,
            totalEquivalent: 0.15,
            sponsored: false
        )

        let result = map(
            prepareResult: WalletMigrationPrepareResult(
                from: sourceAddress,
                to: destinationAddress,
                walletVersion: "v5R1",
                transactions: [sponsoredTransaction, sweepTransaction],
                batteryTransactions: [sponsoredTransaction, sweepTransaction],
                availableFeeMethods: [.battery(charges: 5)],
                availableTonNano: 112_102_521
            ),
            tonFeeMethod: .battery(charges: 5)
        )

        XCTAssertEqual(result.items.count, 2)
        XCTAssertTrue(result.items.contains { $0.amount.spans.map(\.text).joined() == "1 DYOR" })
        XCTAssertTrue(result.items.contains { $0.amount.spans.map(\.text).joined() == "0.112102521 GRAM" })
        XCTAssertFalse(result.items.contains { $0.amount.spans.map(\.text).joined() == "0.1 GRAM" })
    }

    func test_dustTrxIsHiddenWhenFeeCannotBeCovered() {
        let result = WalletMigrationConfirmationMapper.map(
            prepareResult: nil,
            tronPrepareResult: WalletMigrationTronPrepareResult(
                sourceAddress: "TX1vTqTiDUdS5tDgnYepNvFCeSTcKXWVXc",
                destinationAddress: "TX1vTqTiDUdS5tDgnYepNvFCeSTcKXWVXd",
                usdtAmount: 0,
                requiredTRXSun: 345_000,
                availableTRXSun: 15000,
                nativeRequiredTRXSun: 345_000,
                energy: 0,
                bandwidth: 345,
                trxBandwidth: 345,
                availableFeeMethods: [.trx(amountSun: 345_000)]
            ),
            tronFeeMethod: .trx(amountSun: 345_000),
            amountFormatter: amountFormatter,
            currency: .USD,
            isSecureMode: false,
            nftProvider: { _ in nil }
        )

        XCTAssertTrue(result.items.isEmpty)
        XCTAssertFalse(result.totalSummary.isEmpty)
    }

    func test_totalSummary_foldsTronAssetsIntoSingleFiatValue() {
        let result = map(
            prepareResult: makeTonResult(totalEquivalents: [100]),
            tronPrepareResult: makeTronResult(usdt: 7, trx: 10),
            usdtRate: makeRate(1),
            trxRate: makeRate(0.5)
        )

        XCTAssertEqual(result.totalSummary, expectedTotal(112))
        XCTAssertFalse(result.totalSummary.contains(USDT.symbol))
        XCTAssertFalse(result.totalSummary.contains(TRX.symbol))
    }

    func test_totalSummary_skipsTronAssetWithoutRate() {
        let result = map(
            prepareResult: makeTonResult(totalEquivalents: [100]),
            tronPrepareResult: makeTronResult(usdt: 7, trx: 10),
            usdtRate: nil,
            trxRate: makeRate(0.5)
        )

        XCTAssertEqual(result.totalSummary, expectedTotal(105))
    }

    func test_totalSummary_keepsTotalPrefixWithoutTonLeg() {
        let result = map(
            prepareResult: nil,
            tronPrepareResult: makeTronResult(usdt: 7, trx: 0),
            usdtRate: makeRate(1)
        )

        XCTAssertEqual(result.totalSummary, expectedTotal(7))
    }

    func test_totalSummary_sumsEveryTonTransaction() {
        let result = map(prepareResult: makeTonResult(totalEquivalents: [100, 20, 5]))

        XCTAssertEqual(result.totalSummary, expectedTotal(125))
    }

    func test_totalSummary_appendsNftCount() {
        let single = map(prepareResult: makeTonResult(totalEquivalents: [100], nftCount: 1))
        let multiple = map(prepareResult: makeTonResult(totalEquivalents: [100], nftCount: 3))

        XCTAssertEqual(
            single.totalSummary,
            "\(expectedTotal(100)) · \(TKLocales.Settings.Migration.nftCount(1))"
        )
        XCTAssertEqual(
            multiple.totalSummary,
            "\(expectedTotal(100)) · \(TKLocales.Settings.Migration.nftsCount(3))"
        )
    }

    func test_totalSummary_separatesNftCountLikeWalletPicker() {
        let result = map(prepareResult: makeTonResult(totalEquivalents: [100], nftCount: 2))

        XCTAssertTrue(result.totalSummary.contains(" · "))
        XCTAssertFalse(result.totalSummary.contains("+"))
    }

    func test_totalSummary_masksSingleValueInSecureMode() {
        let result = map(
            prepareResult: makeTonResult(totalEquivalents: [100]),
            tronPrepareResult: makeTronResult(usdt: 7, trx: 10),
            usdtRate: makeRate(1),
            trxRate: makeRate(0.5),
            isSecureMode: true
        )

        XCTAssertEqual(
            result.totalSummary,
            TKLocales.ConfirmSend.Risk.total(String.secureModeValueShort)
        )
    }

    func test_totalSummary_isEmptyWithoutPreparedLegs() {
        XCTAssertTrue(map(prepareResult: nil, tronPrepareResult: nil).totalSummary.isEmpty)
    }

    func test_totalSummary_followsSelectedTronFeeMethod() {
        let tron = makeTronResult(
            usdt: 7,
            trx: 10,
            usdtRequiredTRXSun: trxSun(4),
            availableFeeMethods: [.battery(charges: 5), .trx(amountSun: trxSun(4))]
        )

        let onBattery = map(
            prepareResult: nil,
            tronPrepareResult: tron,
            tronFeeMethod: .battery(charges: 5),
            usdtRate: makeRate(1),
            trxRate: makeRate(0.5)
        )
        let onTrx = map(
            prepareResult: nil,
            tronPrepareResult: tron,
            tronFeeMethod: .trx(amountSun: trxSun(4)),
            usdtRate: makeRate(1),
            trxRate: makeRate(0.5)
        )

        XCTAssertEqual(onBattery.totalSummary, expectedTotal(12))
        XCTAssertEqual(onTrx.totalSummary, expectedTotal(10))
    }

    func test_totalSummary_followsSelectedTonFeeMethod() {
        let ton = makeTonResult(
            totalEquivalents: [100],
            batteryTotalEquivalents: [120],
            availableFeeMethods: [.ton(amountNano: 1000), .battery(charges: 5)]
        )

        let onTon = map(prepareResult: ton, tonFeeMethod: .ton(amountNano: 1000))
        let onBattery = map(prepareResult: ton, tonFeeMethod: .battery(charges: 5))

        XCTAssertEqual(onTon.totalSummary, expectedTotal(100))
        XCTAssertEqual(onBattery.totalSummary, expectedTotal(120))
    }

    func test_items_followSelectedTonFeeMethod() {
        let ton = makeTonResult(
            totalEquivalents: [100],
            nftCount: 0,
            batteryTotalEquivalents: [120],
            batteryNftCount: 2,
            availableFeeMethods: [.ton(amountNano: 1000), .battery(charges: 5)]
        )

        XCTAssertEqual(map(prepareResult: ton, tonFeeMethod: .ton(amountNano: 1000)).items.count, 1)
        XCTAssertEqual(map(prepareResult: ton, tonFeeMethod: .battery(charges: 5)).items.count, 3)
    }

    func test_presentation_fallsBackToSelfTransactionsWhenBatteryTransactionsMissing() {
        let ton = makeTonResult(
            totalEquivalents: [100],
            availableFeeMethods: [.ton(amountNano: 1000), .battery(charges: 5)]
        )

        let mapped = map(prepareResult: ton, tonFeeMethod: .battery(charges: 5))

        XCTAssertEqual(mapped.totalSummary, expectedTotal(100))
        XCTAssertEqual(mapped.items.count, 1)
    }
}

private extension WalletMigrationConfirmationMapperTests {
    var recipient: String {
        "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    }

    func map(
        prepareResult: WalletMigrationPrepareResult?,
        tonFeeMethod: WalletMigrationPrepareResult.FeeMethod? = nil,
        tronPrepareResult: WalletMigrationTronPrepareResult? = nil,
        tronFeeMethod: WalletMigrationTronPrepareResult.FeeMethod? = nil,
        usdtRate: Rates.Rate? = nil,
        trxRate: Rates.Rate? = nil,
        isSecureMode: Bool = false
    ) -> WalletMigrationConfirmationMapper.Result {
        WalletMigrationConfirmationMapper.map(
            prepareResult: prepareResult,
            tonFeeMethod: tonFeeMethod,
            tronPrepareResult: tronPrepareResult,
            tronFeeMethod: tronFeeMethod,
            usdtRate: usdtRate,
            trxRate: trxRate,
            amountFormatter: amountFormatter,
            currency: .USD,
            isSecureMode: isSecureMode,
            nftProvider: { _ in nil }
        )
    }

    var amountFormatter: AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }

    func fiat(_ value: Decimal) -> String {
        amountFormatter.format(
            decimal: value,
            accessory: .fiat(Currency.USD),
            style: .fiatBalance
        )
    }

    func expectedTotal(_ value: Decimal) -> String {
        TKLocales.ConfirmSend.Risk.total(fiat(value))
    }

    func makeRate(_ rate: Decimal) -> Rates.Rate {
        Rates.Rate(currency: .USD, rate: rate, diff24h: nil)
    }

    func trxSun(_ trx: Int) -> BigUInt {
        BigUInt(trx) * TRX.sunPerTRX
    }

    func makeTonResult(
        totalEquivalents: [Double],
        nftCount: Int = 0,
        batteryTotalEquivalents: [Double]? = nil,
        batteryNftCount: Int = 0,
        availableFeeMethods: [WalletMigrationPrepareResult.FeeMethod] = [.ton(amountNano: 1000)]
    ) -> WalletMigrationPrepareResult {
        WalletMigrationPrepareResult(
            from: recipient,
            to: recipient,
            walletVersion: "v4R2",
            transactions: makePreparedTransactions(
                totalEquivalents: totalEquivalents,
                nftCount: nftCount,
                sponsored: false
            ),
            batteryTransactions: batteryTotalEquivalents.map {
                makePreparedTransactions(
                    totalEquivalents: $0,
                    nftCount: batteryNftCount,
                    sponsored: true
                )
            },
            availableFeeMethods: availableFeeMethods,
            availableTonNano: 1_000_000_000
        )
    }

    func makePreparedTransactions(
        totalEquivalents: [Double],
        nftCount: Int,
        sponsored: Bool
    ) -> [WalletMigrationPreparedTransaction] {
        totalEquivalents.enumerated().map { index, totalEquivalent in
            makePreparedTransaction(
                seqno: index,
                totalEquivalent: totalEquivalent,
                nftCount: index == 0 ? nftCount : 0,
                sponsored: sponsored
            )
        }
    }

    func makePreparedTransaction(
        seqno: Int,
        totalEquivalent: Double,
        nftCount: Int,
        sponsored: Bool
    ) -> WalletMigrationPreparedTransaction {
        let address = try! TonSwift.Address.parse(recipient)
        let account = WalletAccount(address: address, name: nil, isScam: false, isWallet: true)
        var actions = [makeTonTransferAction(account: account)]
        actions += (0 ..< nftCount).map { _ in
            makeNftTransferAction(account: account, nftAddress: address)
        }

        return WalletMigrationPreparedTransaction(
            seqno: seqno,
            boc: "te6cckEBAQEAAgAAAA==",
            event: AccountEvent(
                eventId: "\(seqno)",
                date: Date(timeIntervalSince1970: 0),
                account: account,
                isScam: false,
                isInProgress: false,
                extra: .Fee(1000),
                excess: nil,
                progress: nil,
                actions: actions
            ),
            totalFees: 1000,
            totalEquivalent: totalEquivalent,
            sponsored: sponsored
        )
    }

    func makeTonTransferAction(account: WalletAccount) -> AccountEventAction {
        makeTonTransferAction(
            sender: account,
            recipient: account,
            amount: 1_000_000_000,
            amountTitle: "1 TON"
        )
    }

    func makeTonTransferAction(
        sender: WalletAccount,
        recipient: WalletAccount,
        amount: Int64,
        amountTitle: String
    ) -> AccountEventAction {
        AccountEventAction(
            type: .tonTransfer(
                AccountEventAction.TonTransfer(
                    sender: sender,
                    recipient: recipient,
                    amount: amount,
                    comment: nil,
                    encryptedComment: nil
                )
            ),
            status: .ok,
            preview: makePreview(name: "TON", value: amountTitle, account: recipient)
        )
    }

    func makeJettonTransferAction(
        sender: WalletAccount,
        recipient: WalletAccount,
        jettonAddress: TonSwift.Address,
        amount: BigUInt,
        amountTitle: String
    ) -> AccountEventAction {
        let jettonInfo = JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: jettonAddress,
            fractionDigits: 9,
            name: "DYOR",
            symbol: "DYOR",
            verification: .none,
            imageURL: nil
        )
        return AccountEventAction(
            type: .jettonTransfer(
                AccountEventAction.JettonTransfer(
                    sender: sender,
                    recipient: recipient,
                    senderAddress: sender.address,
                    recipientAddress: recipient.address,
                    amount: amount,
                    jettonInfo: jettonInfo,
                    comment: nil,
                    encryptedComment: nil
                )
            ),
            status: .ok,
            preview: makePreview(name: "DYOR", value: amountTitle, account: recipient)
        )
    }

    func makeNftTransferAction(
        account: WalletAccount,
        nftAddress: TonSwift.Address
    ) -> AccountEventAction {
        AccountEventAction(
            type: .nftItemTransfer(
                AccountEventAction.NFTItemTransfer(
                    sender: account,
                    recipient: account,
                    nftAddress: nftAddress,
                    comment: nil,
                    payload: nil,
                    encryptedComment: nil
                )
            ),
            status: .ok,
            preview: makePreview(name: "NFT", value: nil, account: account)
        )
    }

    func makePreview(
        name: String,
        value: String?,
        account: WalletAccount
    ) -> AccountEventAction.SimplePreview {
        AccountEventAction.SimplePreview(
            name: name,
            description: "",
            image: nil,
            value: value,
            fiatValue: nil,
            valueImage: nil,
            accounts: [account]
        )
    }

    func makeTronResult(
        usdt: Int,
        trx: Int,
        usdtRequiredTRXSun: BigUInt = 0,
        availableFeeMethods: [WalletMigrationTronPrepareResult.FeeMethod] = [.battery(charges: 5)]
    ) -> WalletMigrationTronPrepareResult {
        WalletMigrationTronPrepareResult(
            sourceAddress: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
            destinationAddress: "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
            usdtAmount: BigUInt(usdt) * BigUInt(1_000_000),
            requiredTRXSun: 0,
            availableTRXSun: trxSun(trx),
            usdtRequiredTRXSun: usdtRequiredTRXSun,
            nativeRequiredTRXSun: 0,
            energy: 0,
            bandwidth: 0,
            availableFeeMethods: availableFeeMethods
        )
    }
}
