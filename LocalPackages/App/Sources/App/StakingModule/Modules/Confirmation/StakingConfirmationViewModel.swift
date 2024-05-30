import Foundation
import TKUIKit
import UIKit
import KeeperCore
import BigInt
import TonSwift

protocol StakingConfirmationModuleOutput: AnyObject {
    var didFinish: (() -> Void)? { get set }
}

protocol StakingConfirmationViewModel: AnyObject {
    var didUpdateModel: ((StakingConfirmationModel) -> Void)? { get set }
    var didUpdateButtons: ((TKSuccessFlowView.State) -> Void)? { get set }
    
    func viewDidLoad()
    func prepareStaking()
}

struct StakingConfirmationModel {
    let sections: [StakingConfirmationSection]
}

enum StakingConfirmationSection: Hashable {
    case title(item: StakingConfirmationTitleCell.Model)
    case info(items: [StakingConfirmationCell.Model])
}

final class StakingConfirmationViewModelImplementation: StakingConfirmationViewModel, StakingConfirmationModuleOutput {
    
    // MARK: - StakingOptionsModuleOutput
    
    var didFinish: (() -> Void)?
        
    // MARK: - StakingOptionsViewModel
    
    var didUpdateModel: ((StakingConfirmationModel) -> Void)?
    var didUpdateButtons: ((TKSuccessFlowView.State) -> Void)?
    
    func viewDidLoad() {
        didUpdateModel?(createModel())
    }
    
    func prepareStaking() {
        Task {
            let isSuccess = await self.sendTransaction()
            await MainActor.run { [weak self] in
                if isSuccess {
                    self?.didUpdateButtons?(.success)
                    Task {
                        try await Task.sleep(nanoseconds: 1_500_000_000)
                        self?.didFinish?()
                    }
                } else {
                    self?.didUpdateButtons?(.content)
                }
            }
        }
    }
    
    private func sendTransaction() async -> Bool {
        do {
            try await sendConfirmationController.sendTransaction()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Dependencies
    
    private let stakingModel: StakingModel
    private let sendConfirmationController: SendConfirmationController
        
    init(
        stakingModel: StakingModel,
        sendConfirmationController: SendConfirmationController
    ) {
        self.stakingModel = stakingModel
        self.sendConfirmationController = sendConfirmationController
    }
}

private extension StakingConfirmationViewModelImplementation {
    func createModel() -> StakingConfirmationModel {
        let sections = createOptionItemSections()
        return StakingConfirmationModel(sections: sections)
    }
    
    func createOptionItemSections() -> [StakingConfirmationSection] {
        let wallet = stakingModel.wallet
        let walletContentModel = StakingConfirmationCellContentView.Model(
            title: "Wallet",
            subtitle: wallet.model.emoji + " " + wallet.model.label,
            description: nil
        )
        let walletModel = StakingConfirmationCell.Model(
            identifier: "wallet",
            cellContentModel: walletContentModel
        )
        
        let pool = stakingModel.pool
        let recipientContentModel = StakingConfirmationCellContentView.Model(
            title: "Recipient",
            subtitle: pool.name,
            description: nil
        )
        let recipientModel = StakingConfirmationCell.Model(
            identifier: "recipient",
            cellContentModel: recipientContentModel
        )
        
        let apy = pool.pools.first?.apy ?? 0
        let apyString = String(format: "%.2f", apy)
        let apyContentModel = StakingConfirmationCellContentView.Model(
            title: "APY",
            subtitle: "≈ \(apyString)%",
            description: nil
        )
        let apyModel = StakingConfirmationCell.Model(
            identifier: "apy",
            cellContentModel: apyContentModel
        )
        
        let feeContentModel = StakingConfirmationCellContentView.Model(
            title: "Fee",
            subtitle: "≈ 0.01 TON",
            description: "$ 0.01"
        )
        let feeModel = StakingConfirmationCell.Model(
            identifier: "fee",
            cellContentModel: feeContentModel
        )
        
        let infoItems = [walletModel, recipientModel, apyModel, feeModel]
        
        let inputText = stakingModel.inputText
        let convertedText = stakingModel.convertedText
        
        let titleItem = StakingConfirmationTitleCell.Model(
            identifier: "title",
            isHighlightable: false,
            isSelectable: false,
            cellContentModel: .init(
                image: pool.image,
                title: inputText,
                topDescription: "Deposit",
                bottomDescription: convertedText
            )
        )
        return [
            StakingConfirmationSection.title(item: titleItem),
            StakingConfirmationSection.info(items: infoItems)
        ]
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
