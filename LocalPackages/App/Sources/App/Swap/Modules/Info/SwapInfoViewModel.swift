import KeeperCore
import TKUIKit
import UIKit
import TKCore
import TonSwift
import BigInt

protocol SwapInfoViewModel: AnyObject {
    var swapInfoController: SwapInfoController { get }
    
    func didTapSendTokenPickerButton()
    func didTapReceiveTokenPickerButton()
    func didTapSwapTokensButton()
    
    var didUpdateModel: ((SwapTokensContainerView.Model) -> Void)? { get set }
    var didUpdateContinueButton: ((TKButton.Configuration) -> Void)? { get set }
    
    var didUpdateSendToken: ((Token?) -> Void)? { get set }
    var didUpdateReceiveToken: ((Token?) -> Void)? { get set }
    
    var didUpdateSendTokenInput: ((String) -> Void)? { get set }
    var didUpdateReceiveTokenInput: ((String) -> Void)? { get set }
    
    func viewDidLoad()
    func viewWillAppear()
}

protocol SwapInfoModuleOutput: AnyObject {
    var currentTolerance: Int { get }
    var didTapTokenPicker: ((Wallet, Token, SwapInfoTokenType) -> Void)? { get set }
    var didTapSearchTokenPicker: ((SwapInfoTokenType) -> Void)? { get set }
    var didTapContinue: ((SwapModel) -> Void)? { get set }
}

protocol SwapInfoModuleInput: AnyObject {
    func setSendToken(token: Token)
    func setReceiveToken(token: Token)
    func setTolerance(toleance: Int)
}

enum SwapInfoTokenType {
    case send
    case receive
}

final class SwapInfoViewModelImplementation: SwapInfoViewModel, SwapInfoModuleInput, SwapInfoModuleOutput {
    
    // MARK: - SwapInfoModuleOutput
    
    var currentTolerance: Int { swapInfoController.tolerance }
    var didTapTokenPicker: ((Wallet, Token, SwapInfoTokenType) -> Void)?
    var didTapSearchTokenPicker: ((SwapInfoTokenType) -> Void)?
    var didTapContinue: ((SwapModel) -> Void)?
    
    // MARK: - SwapInfoModuleInput
    
    func setSendToken(token: Token) {
        swapInfoController.setSendToken(token)
    }
    
    func setReceiveToken(token: Token) {
        swapInfoController.setReceiveToken(token)
    }
    
    func setTolerance(toleance: Int) {
        swapInfoController.tolerance = toleance
    }
    
    // MARK: - SwapInfoViewModel
    
    var didUpdateSendToken: ((Token?) -> Void)?
    var didUpdateReceiveToken: ((Token?) -> Void)?
    
    var didUpdateSendTokenInput: ((String) -> Void)?
    var didUpdateReceiveTokenInput: ((String) -> Void)?
    
    var didUpdateModel: ((SwapTokensContainerView.Model) -> Void)?
    var didUpdateContinueButton: ((TKButton.Configuration) -> Void)?
    
    func didTapSendTokenPickerButton() {
        let sendToken = swapInfoController.getSendToken() ?? .jetton(.empty)
        guard let receiveToken = swapInfoController.getReceiveToken() else {
            didTapTokenPicker?(swapInfoController.wallet, sendToken, .send)
            return
        }
        let containsTokenInWallet = swapInfoController.containsTokenInWallet(token: receiveToken)
        if containsTokenInWallet {
            didTapSearchTokenPicker?(.send)
        } else {
            didTapTokenPicker?(swapInfoController.wallet, sendToken, .send)
        }
    }
    
    func didTapReceiveTokenPickerButton() {
        let receiveToken = swapInfoController.getReceiveToken() ?? .jetton(.empty)
        guard let sendToken = swapInfoController.getSendToken() else {
            didTapTokenPicker?(swapInfoController.wallet, receiveToken, .receive)
            return
        }
        let containsTokenInWallet = swapInfoController.containsTokenInWallet(token: sendToken)
        if containsTokenInWallet {
            didTapSearchTokenPicker?(.receive)
        } else {
            didTapTokenPicker?(swapInfoController.wallet, receiveToken, .receive)
        }
    }
    
    func didTapSwapTokensButton() {
        swapInfoController.swapTokens()
    }
    
    func viewDidLoad() {
        viewWillAppear()
        swapInfoController.start()
    }
    
    func viewWillAppear() {
        swapInfoController.didUpdateModel = { [weak self] model in
            guard let self else { return }
            DispatchQueue.main.async {
                let sendSwapTokensModel: SwapTokensContainerView.Model.Send
                if let sendToken = model.sendToken {
                    sendSwapTokensModel = .init(tokenModel: self.mapTokenModel(token: sendToken), balance: model.sendTokenBalance, state: .init(model.state))
                } else {
                    sendSwapTokensModel = .init(tokenModel: .chooseToken, balance: nil, state: .default)
                }
                
                let receiveSwapTokensModel: SwapTokensContainerView.Model.Receive
                if let receiveToken = model.receiveToken {
                    receiveSwapTokensModel = .init(
                        tokenModel: self.mapTokenModel(token: receiveToken),
                        balance: model.receiveTokenBalance,
                        state: .default,
                        rows: Self.mapRowsModel(model)
                    )
                } else {
                    receiveSwapTokensModel = .init(tokenModel: .chooseToken, balance: nil, state: .default, rows: [])
                }
                
                self.didUpdateModel?(.init(
                    isEnabled: !model.isLoading,
                    showsSwapButton: true,
                    sendSwapTokensModel: sendSwapTokensModel,
                    receiveSwapTokensModel: receiveSwapTokensModel)
                )
                
                self.didUpdateContinueButton?(
                    Self.mapButtonConfiguration(model: model) {
                        self.didTapContinueButton()
                    }
                )
            }
        }
        
        swapInfoController.didUpdateSendToken = didUpdateSendToken
        swapInfoController.didUpdateReceiveToken = didUpdateReceiveToken
        
        swapInfoController.shouldUpdateSendTokenInput = { [weak self] inputText in
            guard let self else { return }
            DispatchQueue.main.async {
                self.didUpdateSendTokenInput?(inputText)
            }
        }
        
        swapInfoController.shouldUpdateReceiveTokenInput = { [weak self] inputText in
            guard let self else { return }
            DispatchQueue.main.async {
                self.didUpdateReceiveTokenInput?(inputText)
            }
        }
        
    }
    
    private func didTapContinueButton() {
        if let swapModel = swapInfoController.getSwapModel() {
            didTapContinue?(swapModel)
        }
    }
    
    // MARK: - ImageLoader
    
    private let imageLoader = ImageLoader()
    
    // MARK: - Dependencies
        
    let swapInfoController: SwapInfoController
    
    init(swapInfoController: SwapInfoController) {
        self.swapInfoController = swapInfoController
    }
}

private extension SwapInfoViewModelImplementation {
    func mapTokenModel(token: Token) -> TKTokenTagView.Model {
        let iconModel: TKListItemIconImageView.Model.Image
        let titleText: String
        
        switch token {
        case .ton:
            let image = UIImage.TKUIKit.Icons.Size44.tonCurrency
            iconModel = .image(image)
            titleText = "TON"
        case .jetton(let jetton):
            let task = TKCore.ImageDownloadTask(
                closure: { [imageLoader] imageView, size, cornerRadius in
                    return imageLoader.loadImage(
                        url: jetton.jettonInfo.imageURL,
                        imageView: imageView,
                        size: size,
                        cornerRadius: cornerRadius
                    )
                }
            )
            iconModel = .asyncImage(task)
            titleText = jetton.jettonInfo.name
        }
        
        return .init(
            iconModel: iconModel,
            title: titleText.withTextStyle(.label1, color: .Button.tertiaryForeground),
            accessoryType: nil
        )
    }
    
    static func mapButtonConfiguration(model: SwapInfoModel, action: @escaping () -> Void) -> TKButton.Configuration {
        let title: String
        let category: TKActionButtonCategory
        let isEnabled: Bool
        
        switch model.state {
        case .insufficientBalance(let symbol):
            title = "Insufficient \(symbol) balance"
            category = .secondary
            isEnabled = false
        case .chooseToken:
            title = "Choose Token"
            category = .secondary
            isEnabled = false
        case .enterAmount:
            title = "Enter Amount"
            category = .secondary
            isEnabled = false
        case .continue:
            title = "Continue"
            category = .primary
            isEnabled = true
        }
        
        var configuration = TKButton.Configuration.actionButtonConfiguration(category: category, size: .large)
        configuration.content.title = .plainString(title)
        configuration.isEnabled = isEnabled && !model.isLoading
        configuration.action = { action() }
        return configuration
    }
    
    static func mapRowsModel(_ model: SwapInfoModel) -> [SwapTokensRowView.Model] {
        if model.transactionModel == nil || model.state != .continue { return [] }
        let transactionModel = model.transactionModel
        let isLoading = model.isLoading
        
        let rows: [SwapTokensRowView.Model] = [
            .init(title: "Price impact", titleAction: {}, content: isLoading ? .loader : .text(transactionModel?.priceImpact)),
            .init(title: "Minimum received", titleAction: {}, content: isLoading ? .loader : .text(transactionModel?.minimumReceived)),
            .init(title: "Liquidity provider fee", titleAction: {}, content: isLoading ? .loader : .text(transactionModel?.providerFee)),
            .init(title: "Blockchain fee", titleAction: nil, content: isLoading ? .loader : .text(transactionModel?.blockchainFee)),
            .init(title: "Route", titleAction: nil, content: isLoading ? .loader : .text(transactionModel?.route)),
            .init(title: "Provider", titleAction: nil, content: isLoading ? .loader : .text(transactionModel?.provider)),
        ]
        
        return rows
    }
}

private extension SwapTokensSingleView.Model.State {
    init(_ s: SwapInfoModelState) {
        if case .insufficientBalance = s {
            self = .error
        } else {
            self = .default
        }
    }
}
