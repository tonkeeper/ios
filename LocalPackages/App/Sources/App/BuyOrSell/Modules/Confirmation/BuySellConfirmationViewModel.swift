import KeeperCore
import BigInt
import TKUIKit
import TKCore
import UIKit

protocol BuySellConfirmationModuleOutput: AnyObject {
    var didUpdateIsContinueButtonLoading: ((Bool) -> Void)? { get set }
}

protocol BuySellConfirmationModuleInput: AnyObject {
}

protocol BuySellConfirmationViewModel: AnyObject {
    var didUpdateInputValue: ((String) -> Void)? { get set }
    var didUpdateConvertedValue: ((String) -> Void)? { get set }
    
    var didUpdateInputModel: ((ConfirmationInputController.Model) -> Void)? { get set }
    var didUpdateItemModel: ((BuySellConfirmationView.Model) -> Void)? { get set }
    
    func viewDidLoad()
    func didEditTopInput(_ input: String?)
    func didEditBottomInput(_ input: String?)
}

final class BuySellConfirmationViewModelImplementation: BuySellConfirmationViewModel, BuySellConfirmationModuleOutput, BuySellConfirmationModuleInput {
    
    // MARK: - BuySellConfirmationModuleOutput
    
    var didUpdateIsContinueButtonLoading: ((Bool) -> Void)?
    
    // MARK: - BuySellConfirmationModuleInput
    
    // MARK: - BuySellConfirmationViewModel
    
    var didUpdateInputValue: ((String) -> Void)?
    var didUpdateConvertedValue: ((String) -> Void)?
    
    var didUpdateInputModel: ((ConfirmationInputController.Model) -> Void)?
    var didUpdateItemModel: ((BuySellConfirmationView.Model) -> Void)?
    
    func viewDidLoad() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.didUpdateItemModel?(self.createItemModel(self.itemModel))
        }
        
        confirmationInputController.didUpdateModel = { [weak self] model in
            guard let self else { return }
            DispatchQueue.main.async {
                self.didUpdateIsContinueButtonLoading?(model.isLoading)
                self.didUpdateInputModel?(model)
            }
        }
        
        confirmationInputController.shouldUpdateSendTokenInput = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async {
                self.didUpdateInputValue?(text)
            }
        }
        
        confirmationInputController.shouldUpdateReceiveTokenInput = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async {
                self.didUpdateConvertedValue?(text)
            }
        }
        
        confirmationInputController.updateCurency(currency: self.currency) {}
                
        if type == .buy {
            confirmationInputController.setReceiveToken(.ton)
            confirmationInputController.setSendToken(ConfirmationInputController.currencyToken(currency: currency))
        } else if type == .sell {
            confirmationInputController.setSendToken(.ton)
            confirmationInputController.setReceiveToken(ConfirmationInputController.currencyToken(currency: currency))
        }
        confirmationInputController.setSendInput("0")
        confirmationInputController.setReceiveInput("0")
    }
    
    func didEditTopInput(_ input: String?) {
        confirmationInputController.setSendInput(input ?? "0")
    }
    
    func didEditBottomInput(_ input: String?) {
        confirmationInputController.setReceiveInput(input ?? "0")
    }
    
    // MARK: - Dependencies
    
    private let itemModel: BuySellItemModel
    private let confirmationInputController: ConfirmationInputController
    private let currency: Currency
    private let type: BuySellConfirmationType
    
    private let imageLoader = ImageLoader()
    
    init(
        itemModel: BuySellItemModel,
        type: BuySellConfirmationType,
        currency: Currency,
        confirmationInputController: ConfirmationInputController
    ) {
        self.itemModel = itemModel
        self.confirmationInputController = confirmationInputController
        self.currency = currency
        self.type = type
    }
}

private extension BuySellConfirmationViewModelImplementation {
    func createItemModel(_ model: BuySellItemModel) -> BuySellConfirmationView.Model {
        let task = TKCore.ImageDownloadTask { [weak self] imageView, size, cornerRadius in
            guard let self else { return nil }
            return self.imageLoader.loadImage(
                url: model.iconURL,
                imageView: imageView,
                size: size,
                cornerRadius: 0
            )
        }
        
        let imageModel = BuySellConfirmationImageView.Model(
            image: .asyncImage(task),
            tintColor: .clear,
            backgroundColor: .clear,
            size: .init(width: 96, height: 96)
        )
        
        return BuySellConfirmationView.Model(
            imageModel: imageModel,
            title: model.title,
            subtitle: model.description ?? "Instantly buy with a credit card"
        )
    }
}
