import BigInt
import KeeperCore
import TKUIKit
import TKCore
import UIKit

enum BuySellOperatorSection: Hashable {
    case currency(BuySellCurrencyCell.Model)
    case operators(items: [BuySellOperatorCell.Model])
}

protocol BuySellOperatorModuleInput: AnyObject {
    func setCurrency(currency: Currency)
}

protocol BuySellOperatorModuleOutput: AnyObject {
    var didTapCurrencyPicker: ((_ selectedCurrency: Currency) -> Void)? { get set }
    var didTapOperator: ((BuySellItemModel, Currency) -> Void)? { get set }
    
    var didUpdateIsContinueButtonLoading: ((Bool) -> Void)? { get set }
    
    var didTapBack: (() -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set}
}

protocol BuySellOperatorViewModel: AnyObject {
    func viewDidLoad()
    func didTapBackButton()
    func didTapCloseButton()
    
    var didUpdateCurrency: ((BuySellOperatorSection) -> Void)? { get set }
    var didUpdateOperators: (([BuySellOperatorSection]) -> Void)? { get set }
}

final class BuySellOperatorViewModelImplementation: BuySellOperatorViewModel, BuySellOperatorModuleOutput, BuySellOperatorModuleInput {
    
    // MARK: - BuySellOperatorModuleOutput
    
    var didTapCurrencyPicker: ((Currency) -> Void)?
    var didTapOperator: ((BuySellItemModel, Currency) -> Void)?
    
    var didUpdateIsContinueButtonLoading: ((Bool) -> Void)?
    
    var didTapBack: (() -> Void)?
    var didTapClose: (() -> Void)?
    
    // MARK: - BuySellOperatorModuleInput
    
    func setCurrency(currency: Currency) {
        Task { [weak self] in
            guard let self else { return }
            self.currency = currency
            let currencyItem = await self.createBuySellCurrencyItem(currency: currency)
            self.didUpdateCurrency?(.currency(currencyItem))
            if let itemModel {
                self.didTapOperator?(itemModel, self.currency ?? .USD)
            }
        }
    }
    
    // MARK: - BuySellOperatorViewModel
    
    var didUpdateCurrency: ((BuySellOperatorSection) -> Void)?
    var didUpdateOperators: (([BuySellOperatorSection]) -> Void)?
    
    func didTapBackButton() {
        didTapBack?()
    }
    
    func didTapCloseButton() {
        didTapClose?()
    }
    
    func viewDidLoad() {
        Task { [weak self] in
            guard let self else { return }
            self.didUpdateIsContinueButtonLoading?(true)
            let currentCurrency = await self.settingsController.activeCurrency()
            self.currency = currentCurrency
            let currencyItem = await self.createBuySellCurrencyItem(currency: currentCurrency)
            DispatchQueue.main.async {
                self.didUpdateCurrency?(.currency(currencyItem))
                self.operatorsController.didUpdateMethods = { methods in
                    let operatorItems: [BuySellOperatorCell.Model] = methods
                        .flatMap { $0 }
                        .compactMap { method in
                            return self.mapBuySellOperatorItem(method)
                        }
                    DispatchQueue.main.async {
                        self.didUpdateOperators?([.operators(items: operatorItems)])
                        self.didUpdateIsContinueButtonLoading?(operatorItems.isEmpty)
                    }
                }
            }
            await self.operatorsController.start()
        }
    }
    
    // MARK: - State
    
    private var itemModel: BuySellItemModel?
    private var currency: Currency?
    
    // MARK: - Dependencies
    
    private let imageLoader = ImageLoader()
    private let operatorsController: OperatorsController
    private let settingsController: SettingsController
    
    // MARK: - Init
    
    init(
        operatorsController: OperatorsController,
        settingsController: SettingsController
    ) {
        self.operatorsController = operatorsController
        self.settingsController = settingsController
    }
}

private extension BuySellOperatorViewModelImplementation {
    func createBuySellCurrencyItem(currency: Currency) async -> BuySellCurrencyCell.Model {
        let contentModel = BuySellCurrencyCellContentView.Model(
            title: currency.code,
            description: currency.title
        )
        
        return  BuySellCurrencyCell.Model(
            identifier: currency.code,
            selectionHandler: { [weak self] in
                self?.didTapCurrencyPicker?(currency)
            },
            cellContentModel: contentModel
        )
    }
    
    func mapBuySellOperatorItem(_ item: BuySellItemModel) -> BuySellOperatorCell.Model {
        let task = TKCore.ImageDownloadTask { [weak self] imageView, size, cornerRadius in
            guard let self else { return nil }
            return self.imageLoader.loadImage(
                url: item.iconURL,
                imageView: imageView,
                size: size,
                cornerRadius: cornerRadius
            )
        }
        
        let iconModel = TKListItemIconImageView.Model(
            image: .asyncImage(task),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44)
        )
        
        let title = item.title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        let description = item.description?.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
        
        
        let leftModel = TKListItemContentStackView.Model(
            titleSubtitleModel: .init(title: title, tagModel: nil, subtitle: nil),
            description: description
        )
        
        let contentModel = BuySellOperatorCellContentView.Model(
            iconModel: iconModel,
            contentModel: .init(
                leftContentStackViewModel: leftModel,
                rightContentStackViewModel: nil
            )
        )
        
        return BuySellOperatorCell.Model(
            identifier: item.id,
            selectionHandler: { [weak self] in
                guard let self else { return }
                self.itemModel = item
                self.didTapOperator?(item, self.currency ?? .USD)
            },
            cellContentModel: contentModel
        )
    }
}
