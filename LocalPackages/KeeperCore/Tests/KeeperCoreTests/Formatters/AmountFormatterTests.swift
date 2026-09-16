import BigInt
@testable import KeeperCore
import XCTest

final class AmountFormatterTests: XCTestCase {
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

    private func makeFormatter(
        localeIdentifier: String = "en_US_POSIX",
        style: AmountDisplayStyle? = nil,
        signPolicy: AmountSignPolicy = .none,
        space: String = "\u{2009}"
    ) -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: localeIdentifier)
        if let style {
            configuration.style = style
        }
        configuration.signPolicy = signPolicy
        configuration.space = space
        return AmountFormatter(configuration: configuration)
    }

    private func decimal(_ string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
