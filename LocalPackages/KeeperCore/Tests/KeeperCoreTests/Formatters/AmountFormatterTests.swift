import BigInt
@testable import KeeperCore
import XCTest

final class AmountFormatterTests: XCTestCase {
    func testNaNDisplaysUnavailableAmount() {
        let formatter = makeFormatter(signPolicy: .always)
        let styles: [AmountDisplayStyle] = [.regular, .compact, .exactValue, .fiatBalance, .percent]

        for style in styles {
            XCTAssertEqual(formatter.format(decimal: .nan, accessory: .fiat(Currency.USD), style: style), "—")
        }
        XCTAssertEqual(formatter.string(for: NSDecimalNumber.notANumber), "—")

        let header = formatter.formatBalanceHeaderAmount(decimal: .nan, accessory: .fiat(Currency.USD))
        XCTAssertEqual(header.fullText, "—")
        XCTAssertEqual(header.numberParts, [.init(text: "—", role: .primary)])
        XCTAssertNil(header.leadingAccessory)
        XCTAssertNil(header.trailingAccessory)
    }

    func testExactDecimalFormattingPreservesAllDigits() {
        let formatter = makeFormatter(groupDigits: false)
        let values = [
            "12345678901234567890.123456789012345678",
            "0." + String(repeating: "0", count: 80) + "1",
        ]

        for value in values {
            XCTAssertEqual(formatter.format(decimal: decimal(value), style: .exactValue), value)
        }
    }

    func testCompactDecimalFormattingDoesNotRoundAcrossMagnitudeBoundary() {
        let formatter = makeFormatter()

        XCTAssertEqual(formatter.format(decimal: decimal("999999.999999999999999999")), "999 999.99")
        XCTAssertEqual(
            formatter.format(decimal: decimal("0." + String(repeating: "0", count: 80) + "1")),
            "< 0.00000001"
        )
    }

    func testExactBaseUnitFormattingPreservesUntrimmedFraction() {
        let formatter = AmountFormatter(configuration: .init(trimTrailingZeros: false))

        XCTAssertEqual(formatter.format(amount: BigUInt(1_230_000), fractionDigits: 6, style: .exactValue), "1.230000")
        XCTAssertEqual(formatter.format(amount: BigUInt(0), fractionDigits: 6, style: .exactValue), "0.000000")
    }

    func testRegularTokenFormatting() {
        let formatter = makeFormatter(style: .regular, space: " ")

        XCTAssertEqual(formatter.format(amount: BigUInt(0), fractionDigits: 9), "0")
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "1"), fractionDigits: 8, accessory: .tokenSymbol("BTC")),
            "0.00000001 BTC"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "6830"), fractionDigits: 6, accessory: .tokenSymbol("TSLAX")),
            "0.00683 TSLAX"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "1234567890"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "1.23456789 TON"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "3520000"), fractionDigits: 6, accessory: .tokenSymbol("USDT")),
            "3.52 USDT"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "10000000000"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "10 TON"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "10000000000000"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "10 000 TON"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "2345000000000"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "2 345 TON"
        )
    }

    func testRegularTokenDoesNotDisplaySmallNonZeroBalanceAsZero() {
        let formatter = makeFormatter(style: .regular, space: " ")

        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "1"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "0.000000001 TON"
        )
    }

    func testRegularFormattingUsesThreeSignificantFractionDigitsForValuesLowerThanOne() {
        let formatter = makeFormatter(style: .regular, space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("0.000004027645372645327")), "0.00000402")
        XCTAssertEqual(formatter.format(decimal: decimal("0.0200002")), "0.02")
        XCTAssertEqual(formatter.format(decimal: decimal("0.0000303000000001")), "0.0000303")
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.00000000000000000000000000101")),
            "0.00000000000000000000000000101"
        )
    }

    func testRegularFormattingUsesEightFractionDigitsForValuesGreaterThanOne() {
        let formatter = makeFormatter(style: .regular, space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("1.23456789")), "1.23456789")
        XCTAssertEqual(formatter.format(decimal: decimal("3.567890129")), "3.56789012")
        XCTAssertEqual(formatter.format(decimal: decimal("12.1000000000002343")), "12.1")
        XCTAssertEqual(formatter.format(decimal: decimal("12.0000004")), "12.0000004")
    }

    func testCompactFormattingUsesTwoFractionDigitsForValuesGreaterThanOne() {
        let formatter = makeFormatter(space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("1.23456789"), style: .compact), "1.23")
        XCTAssertEqual(formatter.format(decimal: decimal("3.567890129"), style: .compact), "3.56")
        XCTAssertEqual(formatter.format(decimal: decimal("12.1000000000002343"), style: .compact), "12.1")
        XCTAssertEqual(formatter.format(decimal: decimal("12.0000004"), style: .compact), "12")
        XCTAssertEqual(formatter.format(decimal: decimal("999.999999999"), style: .compact), "999.99")
    }

    /// `.compact` collapses large amounts onto M/B/T (product spec); the balance header keeps its
    /// own K/M/B/T/Q tiers.
    func testCompactFormattingShortensLargeValues() {
        let formatter = makeFormatter(space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("5123456"), style: .compact), "5.12M")
        XCTAssertEqual(formatter.format(decimal: decimal("45123456789"), style: .compact), "45.12B")
        XCTAssertEqual(formatter.format(decimal: decimal("5123456789012"), style: .compact), "5.12T")
        XCTAssertEqual(formatter.format(decimal: decimal("999999"), style: .compact), "999 999")
        XCTAssertEqual(formatter.format(decimal: decimal("999999999.999"), style: .compact), "999.99M")
    }

    func testCompactFormattingUsesThreeSignificantFractionDigitsForValuesLowerThanOne() {
        let formatter = makeFormatter(space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("0.000004027645372645327"), style: .compact), "0.00000402")
        XCTAssertEqual(formatter.format(decimal: decimal("0.0200002"), style: .compact), "0.02")
        XCTAssertEqual(formatter.format(decimal: decimal("0.00000001"), style: .compact), "0.00000001")
    }

    func testCompactFormattingCapsValuesLowerThanOneAtEightFractionDigits() {
        let formatter = makeFormatter(space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("0.000000012345"), style: .compact), "0.00000001")
        XCTAssertEqual(formatter.format(decimal: decimal("0.000000001"), style: .compact), "< 0.00000001")
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.00000000000000000000000000101"), style: .compact),
            "< 0.00000001"
        )
    }

    func testCompactFormattingShowsLessThanMinimumForEighteenDecimalsDust() {
        let formatter = makeFormatter(space: " ")
        let signedFormatter = makeFormatter(signPolicy: .always, space: " ")

        XCTAssertEqual(
            formatter.format(
                amount: BigUInt(stringLiteral: "1"),
                fractionDigits: 18,
                accessory: .tokenSymbol("ETH"),
                style: .compact
            ),
            "< 0.00000001 ETH"
        )
        XCTAssertEqual(
            signedFormatter.format(
                amount: BigUInt(stringLiteral: "1"),
                fractionDigits: 18,
                accessory: .tokenSymbol("ETH"),
                isNegative: true,
                style: .compact
            ),
            "\u{2212} < 0.00000001 ETH"
        )
    }

    func testDefaultStyleUsesCompactRules() {
        let formatter = makeFormatter(space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("1.23456789")), "1.23")
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "1234567890"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "1.23 TON"
        )
    }

    func testCurrencySymbolControlsAccessorySpace() {
        let formatter = makeFormatter(space: " ")
        let thinSpaceSymbols = ["€", "ብር", "R$", "AU$"]
        let regularSpaceSymbols = ["KSh", "TON", "Br"]

        for symbol in thinSpaceSymbols {
            let currency = AmountCurrency(symbol: symbol, currencyDisplayType: .token)
            XCTAssertEqual(
                formatter.format(decimal: decimal("1.23"), accessory: .token(currency)),
                "1.23\u{2009}\(symbol)"
            )
        }

        for symbol in regularSpaceSymbols {
            let currency = AmountCurrency(symbol: symbol, currencyDisplayType: .fiat)
            XCTAssertEqual(
                formatter.format(decimal: decimal("1.23"), accessory: .fiat(currency)),
                "1.23 \(symbol)"
            )
        }
    }

    func testRegularTokenUsesLocaleDecimalSeparatorAndSpaceGrouping() {
        let formatter = makeFormatter(localeIdentifier: "ru_RU", style: .regular, space: " ")

        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "1234567890"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "1,23456789 TON"
        )
        XCTAssertEqual(
            formatter.format(amount: BigUInt(stringLiteral: "10000000000000"), fractionDigits: 9, accessory: .tokenSymbol("TON")),
            "10 000 TON"
        )
    }

    func testFiatBalanceFormatting() {
        let formatter = makeFormatter()

        XCTAssertEqual(
            formatter.format(decimal: decimal("0"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}0.00"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.009"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "< $\u{2009}0.01"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("2069.879"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}2 069.87"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("3.5"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}3.50"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("10.00"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}10.00"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.10"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}0.10"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.019"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}0.01"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("999.999"), accessory: .fiat(Currency.USD), style: .fiatBalance),
            "$\u{2009}999.99"
        )
    }

    func testFiatBalanceUsesCurrencyDisplayTypeForPrecision() {
        let formatter = makeFormatter()
        let configuredFormatter = makeFormatter(style: .fiatBalance)
        let tokenCurrency = AmountCurrency(symbol: "TON", currencyDisplayType: .token)
        let fiatCurrency = AmountCurrency(symbol: "$", symbolOnLeft: true, currencyDisplayType: .fiat)

        XCTAssertEqual(
            formatter.format(decimal: decimal("0"), accessory: .token(tokenCurrency), style: .fiatBalance),
            "0.00000000 TON"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.000000009"), accessory: .token(tokenCurrency), style: .fiatBalance),
            "< 0.00000001 TON"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("3.567890129"), accessory: .fiat(tokenCurrency), style: .fiatBalance),
            "3.56789012 TON"
        )
        XCTAssertEqual(
            configuredFormatter.format(decimal: decimal("999.999999999"), accessory: .token(tokenCurrency)),
            "999.99999999 TON"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("3.567890129"), accessory: .token(fiatCurrency), style: .fiatBalance),
            "$\u{2009}3.56"
        )
    }

    func testFiatPriceAndFeeUseTokenRulesForRegularStyle() {
        let formatter = makeFormatter()

        XCTAssertEqual(
            formatter.format(decimal: decimal("0"), accessory: .fiat(Currency.USD), style: .regular),
            "$\u{2009}0"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.009"), accessory: .fiat(Currency.USD), style: .regular),
            "$\u{2009}0.009"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("3.567890123"), accessory: .fiat(Currency.USD), style: .regular),
            "$\u{2009}3.56789012"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("0.000000001"), accessory: .fiat(Currency.USD), style: .regular),
            "$\u{2009}0.000000001"
        )
    }

    /// The balance header still builds its text from the local fiat-balance rules while every other
    /// `.fiatBalance` render goes through ChainKit, so the two paths have to agree digit for digit.
    func testBalanceHeaderFullTextMatchesFiatBalanceFormatting() {
        let formatter = makeFormatter(space: " ")
        let cases: [(String, AmountAccessoryType)] = [
            ("0", .fiat(Currency.USD)),
            ("0.001", .fiat(Currency.USD)),
            ("0.01", .fiat(Currency.USD)),
            ("2069.879", .fiat(Currency.USD)),
            ("7362.45", .fiat(Currency.RUB)),
            ("19999999.99", .fiat(Currency.RUB)),
            ("999999999.999", .fiat(Currency.USD)),
            ("-12.345", .fiat(Currency.USD)),
            ("0", .tokenSymbol("TON")),
            ("0.000000001", .tokenSymbol("TON")),
            ("1.123456789", .tokenSymbol("TON")),
            ("-0.5", .tokenSymbol("TON")),
        ]

        for (value, accessory) in cases {
            XCTAssertEqual(
                formatter.formatBalanceHeaderAmount(decimal: decimal(value), accessory: accessory).fullText,
                formatter.format(decimal: decimal(value), accessory: accessory, style: .fiatBalance),
                "Balance header and .fiatBalance disagree on \(value)"
            )
        }
    }

    func testBalanceHeaderAmountSplitsFractionAndAccessory() {
        let formatter = makeFormatter(space: " ")

        let rub = formatter.formatBalanceHeaderAmount(
            decimal: decimal("7362.45"),
            accessory: .fiat(Currency.RUB)
        )
        XCTAssertNil(rub.leadingAccessory)
        XCTAssertEqual(rub.trailingAccessory, "₽")
        XCTAssertEqual(
            rub.numberParts,
            [
                BalanceHeaderAmountFormat.NumberPart(text: "7 362", role: .primary),
                BalanceHeaderAmountFormat.NumberPart(text: ".45", role: .fraction),
            ]
        )
        XCTAssertEqual(rub.fullText, "7 362.45\u{2009}₽")
        XCTAssertNil(rub.tooltipText)
        XCTAssertEqual(rub.textSize, .regular)

        let usd = formatter.formatBalanceHeaderAmount(
            decimal: decimal("7362.45"),
            accessory: .fiat(Currency.USD)
        )
        XCTAssertEqual(usd.leadingAccessory, "$")
        XCTAssertNil(usd.trailingAccessory)
        XCTAssertEqual(
            usd.numberParts,
            [
                BalanceHeaderAmountFormat.NumberPart(text: "7 362", role: .primary),
                BalanceHeaderAmountFormat.NumberPart(text: ".45", role: .fraction),
            ]
        )
        XCTAssertEqual(usd.fullText, "$\u{2009}7 362.45")
    }

    func testBalanceHeaderAmountUsesReducedTextSizeForMillionsBeforeCompactThreshold() {
        let formatter = makeFormatter(space: " ")

        let amount = formatter.formatBalanceHeaderAmount(
            decimal: decimal("8456362.45"),
            accessory: .fiat(Currency.RUB)
        )

        XCTAssertEqual(amount.textSize, .reduced)
        XCTAssertNil(amount.tooltipText)
        XCTAssertEqual(
            amount.numberParts,
            [
                BalanceHeaderAmountFormat.NumberPart(text: "8 456 362", role: .primary),
                BalanceHeaderAmountFormat.NumberPart(text: ".45", role: .fraction),
            ]
        )
    }

    func testBalanceHeaderAmountUsesCompactDisplayWithFullTooltipForTenMillionsAndMore() {
        let formatter = makeFormatter(space: " ")

        let millions = formatter.formatBalanceHeaderAmount(
            decimal: decimal("26666666.45"),
            accessory: .fiat(Currency.RUB)
        )
        XCTAssertNil(millions.leadingAccessory)
        XCTAssertEqual(millions.trailingAccessory, "₽")
        XCTAssertEqual(
            millions.numberParts,
            [
                BalanceHeaderAmountFormat.NumberPart(text: "26.6M", role: .primary),
            ]
        )
        XCTAssertEqual(millions.fullText, "26 666 666.45\u{2009}₽")
        XCTAssertEqual(millions.tooltipText, "26 666 666.45\u{2009}₽")
        XCTAssertEqual(millions.textSize, .regular)

        let billions = formatter.formatBalanceHeaderAmount(
            decimal: decimal("1250000000"),
            accessory: .fiat(Currency.RUB)
        )
        XCTAssertEqual(
            billions.numberParts,
            [
                BalanceHeaderAmountFormat.NumberPart(text: "1.2B", role: .primary),
            ]
        )
        XCTAssertEqual(billions.fullText, "1 250 000 000.00\u{2009}₽")
        XCTAssertEqual(billions.tooltipText, "1 250 000 000.00\u{2009}₽")
    }

    func testBalanceHeaderAmountCompactDisplayRoundsDown() {
        let formatter = makeFormatter(space: " ")

        XCTAssertEqual(
            formatter
                .formatBalanceHeaderAmount(decimal: decimal("19999999.99"), accessory: .fiat(Currency.RUB))
                .numberParts,
            [
                BalanceHeaderAmountFormat.NumberPart(text: "19.9M", role: .primary),
            ]
        )
    }

    func testPercentFormatting() {
        let formatter = makeFormatter()
        let signedFormatter = makeFormatter(signPolicy: .always)

        XCTAssertEqual(formatter.format(decimal: decimal("24.008940"), style: .percent), "24.01\u{2009}%")
        XCTAssertEqual(formatter.format(decimal: decimal("12.345"), style: .percent), "12.35\u{2009}%")
        XCTAssertEqual(formatter.format(decimal: decimal("12.30"), style: .percent), "12.3\u{2009}%")
        XCTAssertEqual(formatter.format(decimal: decimal("12"), style: .percent), "12\u{2009}%")
        XCTAssertEqual(formatter.format(decimal: decimal("0.009"), style: .percent), "0\u{2009}%")
        XCTAssertEqual(signedFormatter.format(decimal: decimal("7.329"), style: .percent), "+\u{2009}7.33\u{2009}%")
        XCTAssertEqual(signedFormatter.format(decimal: decimal("-7.329"), style: .percent), "\u{2212}\u{2009}7.33\u{2009}%")
        XCTAssertEqual(signedFormatter.format(decimal: decimal("-0.009"), style: .percent), "0\u{2009}%")
        XCTAssertEqual(signedFormatter.format(decimal: decimal("0"), style: .percent), "0\u{2009}%")
    }

    func testPercentUsesLocaleDecimalSeparator() {
        let formatter = makeFormatter(localeIdentifier: "ru_RU", space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("12.345"), style: .percent), "12,35 %")
    }

    func testDefaultLocaleUsesAppPreferredLocalization() {
        let locale = AmountFormatter.Configuration.makeLocale(
            preferredLocalizations: ["en"],
            developmentLocalization: nil,
            fallback: Locale(identifier: "ru_RU")
        )

        XCTAssertEqual(locale.decimalSeparator, ".")
    }

    func testDefaultLocaleFallsBackToDevelopmentLocalizationForBase() {
        let locale = AmountFormatter.Configuration.makeLocale(
            preferredLocalizations: ["Base"],
            developmentLocalization: "en",
            fallback: Locale(identifier: "ru_RU")
        )

        XCTAssertEqual(locale.decimalSeparator, ".")
    }

    func testInputFormattingDoesNotGroupDigitsAndUsesLocaleDecimalSeparator() {
        let englishFormatter = makeFormatter(localeIdentifier: "en_US_POSIX")
        let russianFormatter = makeFormatter(localeIdentifier: "ru_RU")
        let amount = BigUInt(stringLiteral: "80000140000000")

        XCTAssertEqual(
            englishFormatter.formatInput(amount: amount, fractionDigits: 9),
            "80000.14"
        )
        XCTAssertEqual(
            russianFormatter.formatInput(amount: amount, fractionDigits: 9),
            "80000,14"
        )
    }

    func testInputFormattingUsesFractionDigitsAsMinorUnitScale() {
        let formatter = makeFormatter(localeIdentifier: "en_US_POSIX")
        let amount = BigUInt(stringLiteral: "12345")

        XCTAssertEqual(
            formatter.formatInput(amount: amount, fractionDigits: 0),
            "12345"
        )
        XCTAssertEqual(
            formatter.formatInput(amount: amount, fractionDigits: 2),
            "123.45"
        )
        XCTAssertEqual(
            formatter.formatInput(amount: amount, fractionDigits: 6),
            "0.012345"
        )
        XCTAssertEqual(
            formatter.formatInput(amount: amount, fractionDigits: 9),
            "0.000012345"
        )
    }

    func testAmountInputNormalizerAcceptsBothDecimalSeparators() {
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("12.43241", decimalSeparator: ","),
            "12,43241"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("12,43241", decimalSeparator: "."),
            "12.43241"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("80 000.14", decimalSeparator: "."),
            "80000.14"
        )
    }

    func testAmountInputNormalizerConvertsArabicLocaleDigitsToAscii() {
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("\u{0661}", decimalSeparator: "."),
            "1"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("\u{0661}\u{0662}\u{0663}.\u{0664}\u{0665}", decimalSeparator: "."),
            "123.45"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("\u{0660}\u{0660}\u{0661}", decimalSeparator: ","),
            "0,01"
        )
    }

    func testAmountInputNormalizerAcceptsArabicDecimalSeparator() {
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("\u{0661}\u{066B}\u{0662}\u{0663}", decimalSeparator: "."),
            "1.23"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("\u{0661}\u{066B}\u{0662}\u{0663}", decimalSeparator: ","),
            "1,23"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("\u{0661}\u{060C}\u{0662}\u{0663}", decimalSeparator: "."),
            "1.23"
        )
    }

    func testAmountInputNormalizerAddsLeadingZeroForDecimalSeparator() {
        XCTAssertEqual(
            AmountInputFormatter.normalizedString(".", decimalSeparator: "."),
            "0."
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString(",", decimalSeparator: ","),
            "0,"
        )
    }

    func testAmountInputNormalizerInterpretsLeadingZeroInputAsFractionalShortcut() {
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("0", decimalSeparator: "."),
            "0."
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("0000", decimalSeparator: "."),
            "0.000"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("01", decimalSeparator: "."),
            "0.1"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("001", decimalSeparator: "."),
            "0.01"
        )
        XCTAssertEqual(
            AmountInputFormatter.normalizedString("001", decimalSeparator: ","),
            "0,01"
        )
    }

    func testAmountInputParserIsDelimiterAgnostic() {
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "12.43241", targetFractionalDigits: 9).amount,
            BigUInt(stringLiteral: "12432410000")
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "12,43241", targetFractionalDigits: 9).amount,
            BigUInt(stringLiteral: "12432410000")
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: ".00012", targetFractionalDigits: 9).amount,
            BigUInt(stringLiteral: "120000")
        )
    }

    func testAmountInputParserConvertsArabicLocaleDigitsToAscii() {
        XCTAssertEqual(
            AmountInputFormatter.amount(
                from: "\u{0661}\u{0662}.\u{0663}\u{0664}",
                targetFractionalDigits: 2
            ).amount,
            BigUInt(1234)
        )
    }

    func testAmountInputParserAcceptsArabicDecimalSeparator() {
        XCTAssertEqual(
            AmountInputFormatter.amount(
                from: "\u{0661}\u{066B}\u{0662}\u{0663}",
                targetFractionalDigits: 2
            ).amount,
            BigUInt(123)
        )
    }

    func testAmountInputParserSupportsLeadingZeroFractionalShortcut() {
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "0", targetFractionalDigits: 9).amount,
            BigUInt(0)
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "01", targetFractionalDigits: 9).amount,
            BigUInt(stringLiteral: "100000000")
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "001", targetFractionalDigits: 9).amount,
            BigUInt(stringLiteral: "10000000")
        )
    }

    func testAmountInputParserDoesNotUseFractionalShortcutForZeroFractionDigits() {
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "01", targetFractionalDigits: 0).amount,
            BigUInt(1)
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "001", targetFractionalDigits: 0).amount,
            BigUInt(1)
        )
    }

    func testAmountInputParserUsesTargetFractionalDigitsAsMinorUnitScale() {
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "0.1", targetFractionalDigits: 2).amount,
            BigUInt(10)
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "0.1", targetFractionalDigits: 9).amount,
            BigUInt(stringLiteral: "100000000")
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "001", targetFractionalDigits: 2).amount,
            BigUInt(1)
        )
        XCTAssertEqual(
            AmountInputFormatter.amount(from: "0.12345", targetFractionalDigits: 2).amount,
            BigUInt(12)
        )
    }

    func testFormatDistinctlyKeepsCompactStyleWhenAmountsAlreadyDiffer() {
        let formatter = makeFormatter(style: .compact, space: " ")

        let (required, available) = formatter.formatDistinctly(
            BigUInt(stringLiteral: "1900000000"),
            BigUInt(stringLiteral: "1800000000"),
            fractionDigits: 9,
            accessory: .tokenSymbol("TON")
        )

        XCTAssertEqual(required, "1.9 TON")
        XCTAssertEqual(available, "1.8 TON")
    }

    func testFormatDistinctlyFallsBackToExactValueWhenCompactStyleCollidesDifferentAmounts() {
        let formatter = makeFormatter(style: .compact, space: " ")

        let (required, available) = formatter.formatDistinctly(
            BigUInt(stringLiteral: "1800000002"),
            BigUInt(stringLiteral: "1800000001"),
            fractionDigits: 9,
            accessory: .tokenSymbol("TON")
        )

        XCTAssertEqual(required, "1.800000002 TON")
        XCTAssertEqual(available, "1.800000001 TON")
    }

    func testFormatDistinctlySeparatesAmountsBelowCompactMinimum() {
        let formatter = makeFormatter(style: .compact, space: " ")

        let (required, available) = formatter.formatDistinctly(
            BigUInt(2),
            BigUInt(1),
            fractionDigits: 9,
            accessory: .tokenSymbol("TON")
        )

        XCTAssertEqual(required, "0.000000002 TON")
        XCTAssertEqual(available, "0.000000001 TON")
    }

    func testFormatDistinctlyKeepsEqualAmountsRenderedEqually() {
        let formatter = makeFormatter(style: .compact, space: " ")

        let (required, available) = formatter.formatDistinctly(
            BigUInt(stringLiteral: "1800000001"),
            BigUInt(stringLiteral: "1800000001"),
            fractionDigits: 9,
            accessory: .tokenSymbol("TON")
        )

        XCTAssertEqual(required, "1.8 TON")
        XCTAssertEqual(available, "1.8 TON")
    }

    /// `.compact` is rendered by ChainKit, so the locale decimal separator and the app's
    /// space grouping have to survive the round trip.
    func testCompactFormattingUsesLocaleDecimalSeparatorAndSpaceGrouping() {
        let formatter = makeFormatter(localeIdentifier: "ru_RU", space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("1.23456789"), style: .compact), "1,23")
        XCTAssertEqual(
            formatter.format(
                amount: BigUInt(stringLiteral: "1500000000000"),
                fractionDigits: 9,
                accessory: .tokenSymbol("TON"),
                style: .compact
            ),
            "1 500 TON"
        )
    }

    /// A locale that prints its own numerals must not leak them into the digit string: ChainKit's
    /// parser and the local digit rules both read ASCII only.
    func testFormattingWithNonLatinNumeralLocaleKeepsDigitsParsable() {
        let formatter = makeFormatter(localeIdentifier: "fa_IR", groupDigits: false)
        let arabicDecimalSeparator = "\u{066B}"

        XCTAssertEqual(
            formatter.format(decimal: decimal("1234.5678"), style: .exactValue),
            "1234" + arabicDecimalSeparator + "5678"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("1234.5678"), style: .compact),
            "1234" + arabicDecimalSeparator + "56"
        )
        XCTAssertEqual(
            formatter.format(decimal: decimal("1234.5678"), style: .regular),
            "1234" + arabicDecimalSeparator + "5678"
        )
    }

    func testCompactFormattingRespectsDisabledGrouping() {
        let formatter = makeFormatter(groupDigits: false, space: " ")

        XCTAssertEqual(formatter.format(decimal: decimal("1500"), style: .compact), "1500")
        XCTAssertEqual(formatter.format(decimal: decimal("0.000000001"), style: .compact), "< 0.00000001")
    }

    private func makeFormatter(
        localeIdentifier: String = "en_US_POSIX",
        style: AmountDisplayStyle? = nil,
        groupDigits: Bool = true,
        signPolicy: AmountSignPolicy = .none,
        space: String = "\u{2009}"
    ) -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: localeIdentifier)
        if let style {
            configuration.style = style
        }
        configuration.groupDigits = groupDigits
        configuration.signPolicy = signPolicy
        configuration.space = space
        return AmountFormatter(configuration: configuration)
    }

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
