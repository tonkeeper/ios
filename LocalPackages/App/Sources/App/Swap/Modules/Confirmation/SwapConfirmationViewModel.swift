import Foundation
import KeeperCore
import TKUIKit
import TKCore
import UIKit

protocol SwapConfirmationModuleOutput: AnyObject {
    var didRequireConfirmation: (() async -> Bool)? { get set }
    var didFinish: (() -> Void?)? { get set }
}

protocol SwapConfirmationModuleInput: AnyObject {
}

protocol SwapConfirmationViewModel: AnyObject {
    var didUpdateSendToken: ((Token?) -> Void)? { get set }
    var didUpdateReceiveToken: ((Token?) -> Void)? { get set }
    
    var didUpdateSendTokenInput: ((String) -> Void)? { get set }
    var didUpdateReceiveTokenInput: ((String) -> Void)? { get set }
    
    var didUpdateModel: ((SwapTokensContainerView.Model) -> Void)? { get set }
    var didUpdateButtons: ((TKSuccessFlowView.State) -> Void)? { get set }
    
    func didTapConfirmButton()
    func viewWillAppear()
}

final class SwapConfirmationViewModelImplementation: SwapConfirmationViewModel, SwapConfirmationModuleOutput, SwapConfirmationModuleInput {
    
    // MARK: - SwapConfirmationModuleOutput
    
    var didRequireConfirmation: (() async -> Bool)?
    var didFinish: (() -> Void?)?
    
    // MARK: - SwapConfirmationModuleInput
    
    // MARK: - SwapConfirmationViewModel
    
    var didUpdateSendToken: ((Token?) -> Void)?
    var didUpdateReceiveToken: ((Token?) -> Void)?
    
    var didUpdateSendTokenInput: ((String) -> Void)?
    var didUpdateReceiveTokenInput: ((String) -> Void)?
    
    var didUpdateModel: ((SwapTokensContainerView.Model) -> Void)?
    var didUpdateButtons: ((TKSuccessFlowView.State) -> Void)?
    
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
                    isEnabled: false,
                    showsSwapButton: false,
                    sendSwapTokensModel: sendSwapTokensModel,
                    receiveSwapTokensModel: receiveSwapTokensModel)
                )
                
                self.didUpdateSendToken?(model.sendToken)
                self.didUpdateReceiveToken?(model.receiveToken)
                
                self.didUpdateSendTokenInput?(model.sendTokenAmount)
                self.didUpdateReceiveTokenInput?(model.receiveTokenAmount)
                
            }
        }
        
        swapInfoController.forceUpdate()
    }
    
    func didTapConfirmButton() {
        didUpdateButtons?(.loading)
        Task {
            let isSuccess = await self.sendTransaction()
            await MainActor.run {
                if isSuccess {
                    didUpdateButtons?(.success)
                } else {
                    didUpdateButtons?(.content)
                    Task {
                        try await Task.sleep(nanoseconds: 1_500_000_000)
                        didFinish?()
                    }
                }
            }
        }
    }
    
    private func sendTransaction() async -> Bool {
        if sendConfirmationController.isNeedToConfirm() {
            let isConfirmed = await didRequireConfirmation?() ?? false
            guard isConfirmed else { return false }
        }
        do {
            try await sendConfirmationController.sendTransaction()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Init
    
    private let imageLoader = ImageLoader()
    private let swapInfoController: SwapInfoController
    private let sendConfirmationController: SendConfirmationController
    
    init(
        swapInfoController: SwapInfoController,
        sendConfirmationController: SendConfirmationController
    ) {
        self.swapInfoController = swapInfoController
        self.sendConfirmationController = sendConfirmationController
    }
    
}

private extension SwapConfirmationViewModelImplementation {
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
