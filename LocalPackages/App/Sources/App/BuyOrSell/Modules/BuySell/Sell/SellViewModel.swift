import UIKit
import KeeperCore
import BigInt

final class SellViewModelImplementation: BuySellViewModel, BuySellModuleOutput, BuySellModuleInput {
    
    // MARK: - BuySellModuleOutput
    
    // MARK: - BuySellModuleInput
    
    // MARK: - BuySellViewModel
    
    var didUpdateInputConvertedValue: ((String) -> Void)?
    var didUpdateInput: ((BuySellInputModel) -> Void)?
    var didUpdateMethods: ((BuySellMethodSection) -> Void)?
    
    func viewDidLoad() {
        sellInputController.didUpdateModel = { [weak self] model in
            DispatchQueue.main.async {
                self?.didUpdateInput?(Self.createInputModel(model))
            }
        }
        
        sellInputController.shouldUpdateSendTokenInput = { [weak self] text in
            DispatchQueue.main.async {
                self?.didUpdateInputConvertedValue?(text)
            }
        }
        
        didUpdateMethods?(createMethodsModel())
        sellInputController.start()
    }
    
    func didEditInput(_ input: String?) {
        sellInputController.setSendInput(input ?? "0")
    }
    
    func toggleInputMode() {
        sellInputController.swapTokens()
    }
    
    // MARK: - Dependencies
    
    private let sellInputController: SellInputController
    
    init(sellInputController: SellInputController) {
        self.sellInputController = sellInputController
    }
}

private extension SellViewModelImplementation {
    static func createInputModel(_ model: SellInputController.Model) -> BuySellInputModel {
        let convertedValue = "\(model.currencyAmount ?? "") \(model.currencySymbol ?? "")"
        let inputValue = model.tokenAmount ?? "0"
        let inputSymbol = model.tokenSymbol ?? ""
        let maximumFractionDigits = model.tokenFractionDigits ?? 0
        
        let remainingText: String
        let remainingColor: UIColor
        let isContinueButtonEnabled: Bool
        
        switch model.state {
        case .enterAmount(let available):
            remainingText = "Available: \(available)"
            remainingColor = .Text.secondary
            isContinueButtonEnabled = false
        case .remaining(let available):
            remainingText = "Available: \(available)"
            remainingColor = .Text.secondary
            isContinueButtonEnabled = true
        case .insufficientBalance:
            remainingText = "Insufficient balance"
            remainingColor = .Accent.red
            isContinueButtonEnabled = false
        }
        
        let remainingAttributedText = remainingText.withTextStyle(.body2, color: remainingColor)
        
        return BuySellInputModel(
            convertedValue: convertedValue,
            inputValue: inputValue,
            inputSymbol: inputSymbol,
            maximumFractionDigits: maximumFractionDigits,
            remainingAttributedText: remainingAttributedText,
            isContinueButtonEnabled: isContinueButtonEnabled
        )
    }
    
    func createMethodsModel() -> BuySellMethodSection {
        let creditCardContentModel = BuySellMethodCellContentView.Model.creditCard
        let creditCardModel = BuySellMethodCell.Model(
            identifier: "creditCard",
            selectionHandler: { [weak self] in
                
            },
            cellContentModel: creditCardContentModel
        )
        
        let mirCardContentModel = BuySellMethodCellContentView.Model.mirCard
        let mirCardModel = BuySellMethodCell.Model(
            identifier: "mirCard",
            selectionHandler: { [weak self] in
                
            },
            cellContentModel: mirCardContentModel
        )
        
        let cryptoCurrencyContentModel = BuySellMethodCellContentView.Model.cryptoCurrency
        let cryptoCurrencyModel = BuySellMethodCell.Model(
            identifier: "crypto",
            selectionHandler: { [weak self] in
                
            },
            cellContentModel: cryptoCurrencyContentModel
        )
        
        let appleCardContentModel = BuySellMethodCellContentView.Model.appleCard
        let appleCardModel = BuySellMethodCell.Model(
            identifier: "appleCard",
            selectionHandler: { [weak self] in
                
            },
            cellContentModel: appleCardContentModel
        )
        
        let items = [creditCardModel, mirCardModel, cryptoCurrencyModel, appleCardModel]
        return .init(items: items)
    }
}
