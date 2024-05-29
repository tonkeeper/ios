//
//  File.swift
//  
//
//  Created by Marina on 27.05.2024.
//

import Foundation

// FIXME: DISCLAMER: THIS MODULE IS NOT FINISHED
class BuySellViewModel : ObservableObject {
    
    @Published var showPaymentOperators: Bool = false
    @Published var showCurrencies: Bool = false
    @Published var showOperator: Bool = false
    // First screen
    @Published var currentOperation: OperationType = .buy
    @Published var selectedPayment: PaymentType = .creditCard
    // First & Last screen // FIXME: Remove dev vars
    @Published var amountOfTons: String = "50"
    @Published var amountOfTonsDec: Decimal = 50
    @Published var amountOfTonsOld: String = "50"
    @Published var isUpdatingFields: Bool = false
    // Last screen // FIXME: Remove dev vars
    @Published var amountOfSelectedCurrency: String = "" // TODO: Count
    @Published var amountOfSelectedCurrencyDec: Decimal = 0
    @Published var amountOfSelectedCurrencyOld: String = "" 
    // Payment operators screen // FIXME: Remove hardcoded after API added
    @Published var currencies: [Currency] = [
        Currency(name: "United States Dollar", code: "USD"),
        Currency(name: "Euro", code: "EUR"),
        Currency(name: "Russian Ruble", code: "RUB"),
        Currency(name: "Armenian Dram", code: "AMD"),
        Currency(name: "United Kingdom Pound", code: "GBR"),
        Currency(name: "Swiss Franc", code: "CHF"),
        Currency(name: "China Yuan", code: "CNY"),
        Currency(name: "South Korea Won", code: "KRW"),
        Currency(name: "Indonesian Rupiah", code: "IDR"),
        Currency(name: "Indian Rupee", code: "INR"),
        Currency(name: "Japanese Yen", code: "JPY")
    ]
    @Published var selectedCurrency: Currency = Currency(name: "United States Dollar", code: "USD")
    @Published var operators: [Operator] = [
        Operator(name: "Mercuryo", course: 2330.01),
        Operator(name: "Dreamwalkers", course: 2470.01),
        Operator(name: "Neocrypto", course: 2475.01),
        Operator(name: "Transak", course: 2570.01)
    ]
    @Published var selectedOperator = Operator(name: "Mercuryo", course: 2330.01)
    // Cources
    private var bestCourse: Decimal {
        var max: Decimal = Decimal.greatestFiniteMagnitude
        for operatorr in operators {
            if operatorr.course < max { max = operatorr.course }
        }
        return max
    }
    func getBestCourse() -> Decimal {
        return bestCourse
    }    
    // MARK: Custom Types
    enum PaymentType : CaseIterable {
        case creditCard
        case creditCardRUB
        case CryptoCurrency
        case ApplePay
        
        var text: [String] {
            switch self {
            case .creditCard: ["Credit Card"]
            case .creditCardRUB: ["Credit Card", "RUB"]
            case .CryptoCurrency: ["Cryptocurrency"]
            case .ApplePay: ["Apple Pay"]
            }
        }
        
        var icons: [String] {
            switch self {
            case .creditCard: ["PaymentIcons/Mastercard", "PaymentIcons/Visa"]
            case .creditCardRUB: ["PaymentIcons/Mir"]
            case .CryptoCurrency: ["PaymentIcons/Crypto"]
            case .ApplePay: ["PaymentIcons/ApplePay"]
            }
        }
        
        var availableForSell: Bool {
            switch self {
            case .creditCard, .creditCardRUB, .CryptoCurrency: true
            case .ApplePay: false
            }
        }
    }
    enum OperationType : String, CaseIterable {
        case buy
        case sell
    }
    enum TextFieldType : String, CaseIterable {
        case pay
        case get
    }
    struct Currency : Hashable {
        let name: String
        let code: String
    }
    struct Operator: Hashable {
        let name: String
        let course: Decimal
    }
    // MARK: WARNING: THIS CODE WAS NOT FINISHED, REFACTORED, CLEANED, SHOULDN'T BE USED
    // MARK: Formatting
    private var decimalSeparator: String = Locale.current.decimalSeparator == "," ? "," : "."
    private var groupingSeparator: String = Locale.current.decimalSeparator == "," ? " " : "," 
    private var formatter = NumberFormatter()
    public func getDecimalSeparator() -> String {
        return decimalSeparator
    }
    private func getVisualFormatter(minFractionDigits: Int, maxFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfUp
        formatter.locale = Locale.current
        formatter.decimalSeparator = decimalSeparator
        formatter.groupingSeparator = groupingSeparator
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.groupingSize = 3
        return formatter
    }
    func updateOtherField(wasTonUpdated: Bool) {
        var multiplyedOnCourse: Decimal = 0
        if wasTonUpdated {
            multiplyedOnCourse = amountOfTonsDec //* selectedOperator.course
        } else {
            multiplyedOnCourse = amountOfSelectedCurrencyDec // / selectedOperator.course
        }
        if wasTonUpdated {
            //if multiplyedOnCourse != amountOfSelectedCurrencyDec {
                amountOfSelectedCurrency = formatDecimalToStr(multiplyedOnCourse, minFractionDigits: 0, maxFractionDigits: 10)
                amountOfSelectedCurrencyOld = amountOfSelectedCurrency
           // }
        } else {
           // if multiplyedOnCourse != amountOfTonsDec {
                amountOfTons = formatDecimalToStr(multiplyedOnCourse, minFractionDigits: 0, maxFractionDigits: 10)
                amountOfTonsOld = amountOfTons
           // }
        }
    }
    func formatNumberStr(_ text: String, _ oldText: String, minFractionDigits: Int, maxFractionDigits: Int, isTon: Bool) -> String {
        guard text != "" else { return "" }
        // Validation
        let allowedCharacters = CharacterSet(charactersIn: "0123456789., ")
        let decimalCount = text.filter{ $0 == Character(decimalSeparator) }.count
        // Method rangeOfCharacter returns nil if there's no symbols except for allowed, otherwise returns number of the first of forbidden
        guard text.rangeOfCharacter(from: allowedCharacters.inverted) == nil && decimalCount <= 1 else { return oldText }
        // Formatting
        let cleanText = text.replacingOccurrences(of: groupingSeparator, with: "")
        
        let formatter = getVisualFormatter(minFractionDigits: minFractionDigits, maxFractionDigits: maxFractionDigits)
//        
//        if isTon {
//            amountOfTonsDec = formatStrToDecimal(cleanText, minFractionDigits: 0, maxFractionDigits: 10)
//        } else {
//            amountOfSelectedCurrencyDec = formatStrToDecimal(cleanText, minFractionDigits: 0, maxFractionDigits: 10)
//        }
        
        if let number = formatter.number(from: cleanText) {
            // Saving the separator
            var suffix = ""
            // Is the first index where the decimalseparator found in text == last ?
            if let firstIndex: String.Index = text.firstIndex(of: Character(decimalSeparator)) {
                let index: Int = text.distance(from: text.startIndex, to: firstIndex)
                suffix = (index == text.count - 1 ? decimalSeparator : "")
            }
            // Saving meaningless zeros in fraction
            let components = cleanText.components(separatedBy: decimalSeparator)
            var fractionStr: String = ""
            if components.count == 2 {
                if let fraction = formatter.number(from: components[1]), fraction == 0 {
                    suffix = decimalSeparator
                    fractionStr = components[1]
                }
            }            
            
            if let formatted = formatter.string(for: number) {
                return "\(formatted)\(suffix)\(fractionStr)"
            }
            return ""
        }
        return text
    }
    
    func formatDecimalToStr(_ number: Decimal, minFractionDigits: Int, maxFractionDigits: Int) -> String {
        let formatter = getVisualFormatter(minFractionDigits: minFractionDigits, maxFractionDigits: maxFractionDigits)
        if let formatted = formatter.string(for: NSDecimalNumber(decimal: number)) {
            return formatted
        }
        return "0"
    }
    
    func formatStrToDecimal(_ text: String, minFractionDigits: Int, maxFractionDigits: Int) -> Decimal {
        guard text != "" else { return 0 }
        let cleanText = text.replacingOccurrences(of: groupingSeparator, with: "")
        return NSDecimalNumber(string: cleanText).decimalValue
    }
}
