import UIKit
import TKUIKit
import TKCore
import KeeperCore

struct CurrencyPickerSection: Hashable {
    struct Item: Equatable, Hashable {
        let model: SettingsCell.Model
        let currency: Currency
    }
    let items: [Item]
}

protocol CurrencyPickerModuleOutput: AnyObject {
    var didSelectCurrency: ((Currency) -> Void)? { get set }
}

protocol CurrencyPickerModuleInput: AnyObject {
    
}

protocol CurrencyPickerViewModel: AnyObject {
    var didUpdateModel: ((CurrencyPickerSection) -> Void)? { get set }
    var initialSelectedCurrency: Currency? { get }
    
    func viewDidLoad()
}

final class CurrencyPickerViewModelImplementation: CurrencyPickerViewModel, CurrencyPickerModuleInput, CurrencyPickerModuleOutput {
    
    // MARK: - CurrencyPickerModuleOutput
    
    var didSelectCurrency: ((Currency) -> Void)?
            
    // MARK: - CurrencyPickerViewModel
    
    var didUpdateModel: ((CurrencyPickerSection) -> Void)?
    
    let initialSelectedCurrency: Currency?
    
    func viewDidLoad() {
        didUpdateModel?(createSection())
    }
    
    // MARK: - Dependencies
    
    private let settingsController: SettingsController
    
    init(
        selectedCurrency: Currency?,
        settingsController: SettingsController
    ) {
        self.initialSelectedCurrency = selectedCurrency
        self.settingsController = settingsController
    }
}

private extension CurrencyPickerViewModelImplementation {
    func createSection() -> CurrencyPickerSection {
        let currencies = settingsController.getAvailableCurrencies()
        let items: [CurrencyPickerSection.Item] = currencies.map { currency in
            let title = NSMutableAttributedString()
            
            let code = "\(currency.code) ".withTextStyle(
                .label1,
                color: .Text.primary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            
            let name = currency.title.withTextStyle(
                .body1,
                color: .Text.secondary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            
            title.append(code)
            title.append(name)
            
            let model = SettingsCell.Model(
                identifier: currency.title,
                isSelectable: true,
                selectionHandler: { [weak self] in
                    self?.didSelectCurrency?(currency)
                },
                cellContentModel: SettingsCellContentView.Model(
                    title: title
                )
            )
            
            return .init(model: model, currency: currency)
        }
        return CurrencyPickerSection(items: items)
    }
}
