import BigInt
import KeeperCore
import TKUIKit
import TKCore
import UIKit

struct StakingAmountInputModel {
    let convertedValue: String
    let inputValue: String
    let inputSymbol: String
    let maximumFractionDigits: Int
    let remainingAttributedText: NSAttributedString
    let isContinueButtonEnabled: Bool
}

struct StakingAmountOptionSection: Hashable {
    let items: [StakingAmountOptionCell.Model]
}

protocol StakingAmountModuleOutput: AnyObject {
    var didSelectOption: ((PoolImplementation) -> Void)? { get set }
    var didTapContinue: ((StakingModel) -> Void)? { get set }
}

protocol StakingAmountModuleInput: AnyObject {
    func selectOption(_ option: PoolImplementation)
}

protocol StakingAmountViewModel: AnyObject {
    var didUpdateInputConvertedValue: ((String) -> Void)? { get set}
    var didUpdateInput: ((StakingAmountInputModel) -> Void)? { get set }
    var didUpdateOptions: ((StakingAmountOptionSection) -> Void)? { get set }
    
    func viewDidLoad()
    func didEditInput(_ input: String?)
    func toggleInputMode()
    func toggleMax()
    func didTapContinueButton()
}

final class StakingAmountViewModelImplementation: StakingAmountViewModel, StakingAmountModuleOutput, StakingAmountModuleInput {
    
    // MARK: - StakingAmountModuleOutput
    
    var didSelectOption: ((PoolImplementation) -> Void)?
    var didTapContinue: ((StakingModel) -> Void)?
    
    // MARK: - StakingAmountModuleInput
    
    func selectOption(_ option: PoolImplementation) {
        self.selectedOption = option
    }
    
    // MARK: - StakingAmountViewModel
    
    var didUpdateInputConvertedValue: ((String) -> Void)?
    var didUpdateInput: ((StakingAmountInputModel) -> Void)?
    var didUpdateOptions: ((StakingAmountOptionSection) -> Void)?
    
    func viewDidLoad() {
        stakingAmountController.didUpdateModel = { [weak self] model in
            DispatchQueue.main.async {
                self?.tokenAmount = model.tokenAmount
                self?.didUpdateInput?(Self.createInputModel(model))
            }
        }
        
        stakingAmountController.shouldUpdateSendTokenInput = { [weak self] text in
            DispatchQueue.main.async {
                self?.didUpdateInputConvertedValue?(text)
            }
        }
        
        stakingOptionsController.didUpdateModel = { [weak self] model in
            guard let self else { return }
            var poolImplementation: PoolImplementation?
            if let pool = model.first(where: { $0.implementationType == .liquidTF }) {
                poolImplementation = pool
            } else if let pool = model.first {
                poolImplementation = pool
            }
            let poolInfos = poolImplementation?.pools.first
            poolImplementation?.pools = [poolInfos].compactMap { $0 }
            poolImplementation?.maxPoolApy = poolInfos?.apy ?? 0
            self.selectedOption = poolImplementation
        }
        
        stakingAmountController.start()
        stakingOptionsController.start()
        stakingAmountController.setSendInput("0")
    }
    
    func didEditInput(_ input: String?) {
        stakingAmountController.setSendInput(input ?? "0")
    }
    
    func toggleInputMode() {
        stakingAmountController.swapTokens()
    }
    
    func toggleMax() {
        stakingAmountController.toggleMax()
    }
    
    func didTapContinueButton() {
        let pool = selectedOption
        let inputAmount: BigUInt?
        let inputText: String
        let convertedText: String
        
        let stakingAmountControllerModel = stakingAmountController.getModel()
        
        if stakingAmountController.isTokenInput {
            inputAmount = stakingAmountController.getSendInputAmount()
            inputText = stakingAmountControllerModel.sendTokenAmount + " " + (stakingAmountControllerModel.sendToken?.tokenSym ?? "")
            convertedText = "$ " + stakingAmountControllerModel.receiveTokenAmount
        } else {
            inputAmount = stakingAmountController.getReceiveInputAmount()
            inputText = stakingAmountControllerModel.receiveTokenAmount + " " + (stakingAmountControllerModel.receiveToken?.tokenSym ?? "")
            convertedText = "$ " + stakingAmountControllerModel.sendTokenAmount
        }
        
        if let pool, let inputAmount {
            let stakingModel = StakingModel(
                wallet: stakingAmountController.wallet,
                pool: pool,
                inputText: inputText,
                convertedText: convertedText,
                amount: inputAmount,
                token: .ton
            )
            didTapContinue?(stakingModel)
        }
    }
    
    // MARK: - State
    
    var selectedOption: PoolImplementation? {
        didSet {
            updateOptions()
        }
    }
    
    var tokenAmount: String? {
        didSet {
            updateOptions()
        }
    }
    
    private func updateOptions() {
        if let selectedOption, let tokenAmount {
            DispatchQueue.main.async { [weak self] in
                self?.didUpdateOptions?(Self.createOptionsSection(
                    pool: selectedOption,
                    tokenAmount: tokenAmount,
                    didSelect: {
                        self?.didSelectOption?(selectedOption)
                    }
                ))
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let stakingAmountController: StakingAmountController
    private let stakingOptionsController: StakingOptionsController
    
    // MARK: - Init
    
    init(
        stakingAmountController: StakingAmountController,
        stakingOptionsController: StakingOptionsController
    ) {
        self.stakingAmountController = stakingAmountController
        self.stakingOptionsController = stakingOptionsController
    }
}

private extension StakingAmountViewModelImplementation {
    static func createOptionsSection(
        pool: PoolImplementation,
        tokenAmount: String,
        didSelect: (() -> Void)?
    ) -> StakingAmountOptionSection {
        let iconModel = TKListItemIconImageView.Model(
            image: .image(pool.image),
            tintColor: .clear,
            backgroundColor: .clear,
            size: .init(width: 44, height: 44)
        )
        
        let apy = String(format: "%.2f", pool.pools.first?.apy ?? 0)
        let tokenAmount = tokenAmount.replacingOccurrences(of: " ", with: "")
        let convertedAmount = (Double(tokenAmount) ?? 0) * (pool.pools.first?.apy ?? 0) / 100
        let description = "APY ≈ \(apy)%" + " · " + String(format: "%.2f", convertedAmount) + " TON"
        
        var tagModel: TKUITagView.Configuration?
        if pool.pools.contains(where: { $0.isMax }) {
            tagModel = .init(text: "MAX APY", textColor: .Accent.green, backgroundColor: .Accent.green.withAlphaComponent(0.16))
        }
        
        let contentModel = StakingAmountOptionCellContentView.Model(
            iconModel: iconModel,
            title: pool.name,
            subtitle: description,
            tagModel: tagModel
        )
        
        let model = StakingAmountOptionCell.Model(
            identifier: "",
            selectionHandler: { didSelect?() },
            cellContentModel: contentModel
        )
        
        return StakingAmountOptionSection(items: [model])
    }
    
    static func createInputModel(_ model: StakingAmountController.Model) -> StakingAmountInputModel {
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
        
        return StakingAmountInputModel(
            convertedValue: convertedValue,
            inputValue: inputValue,
            inputSymbol: inputSymbol,
            maximumFractionDigits: maximumFractionDigits,
            remainingAttributedText: remainingAttributedText,
            isContinueButtonEnabled: isContinueButtonEnabled
        )
    }
}

private extension PoolImplementation {
    var image: UIImage {
        let lowercasedName = name.lowercased()
        
        switch lowercasedName {
        case "ton nominators":
            return .TKUIKit.Icons.Size44.tonNominators
        case "ton whales":
            return .TKUIKit.Icons.Size44.tonWhales
        case "bemo":
            return .TKUIKit.Icons.Size44.bemo
        case "tonstakers":
            return .TKUIKit.Icons.Size44.tonStakers
        default:
            return .TKUIKit.Icons.Size44.staking
        }
    }
}
