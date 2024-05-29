import Foundation
import KeeperCore
import TKUIKit
import UIKit
import TKCore

protocol StakingInfoModuleOutput: AnyObject {
    var didSelectUrl: ((URL) -> Void)? { get set }
    var didSelectPool: ((PoolImplementation) -> Void)? { get set }
}

protocol StakingInfoModuleInput: AnyObject {
}

protocol StakingInfoViewModel: AnyObject {
    var didUpdateModel: (([StakingInfoSection]) -> Void)? { get set }
    
    func viewDidLoad()
    func didTapContinueButton()
}

enum StakingInfoSection: Hashable, CustomStringConvertible {
    case info(items: [StakingInfoCell.Model])
    case social(items: [StakingInfoSocialCell.Model])
    
    var description: String {
        switch self {
        case .info:
            return ""
        case .social:
            return "Links"
        }
    }
}

final class StakingInfoViewModelImplementation: StakingInfoViewModel, StakingInfoModuleOutput, StakingInfoModuleInput {
    
    // MARK: - StakingInfoModuleOutput
    
    var didSelectUrl: ((URL) -> Void)?
    var didSelectPool: ((PoolImplementation) -> Void)?
    
    // MARK: - StakingInfoModuleInput
    
    // MARK: - StakingInfoViewModel
    
    var didUpdateModel: (([StakingInfoSection]) -> Void)?
    
    func viewDidLoad() {
        didUpdateModel?(createSections(self.pool))
    }
    
    func didTapContinueButton() {
        didSelectPool?(self.pool)
    }
    
    // MARK: - Dependencies
    
    private let pool: PoolImplementation
    
    init(pool: PoolImplementation) {
        self.pool = pool
    }
}

private extension StakingInfoViewModelImplementation {
    func createSections(_ pool: PoolImplementation) -> [StakingInfoSection] {
        var tagModel: TKUITagView.Configuration?
        
        if pool.pools.contains(where: { $0.isMax }) {
            tagModel = .init(text: "MAX", textColor: .Accent.green, backgroundColor: .Accent.green.withAlphaComponent(0.16))
        }
        
        let apy = String(format: "%.2f", pool.pools.first?.apy ?? 0)
        let apyItem = StakingInfoCell.Model(
            identifier: pool.name,
            cellContentModel: .init(title: "APY", description: "≈ \(apy)%", tagModel: tagModel)
        )
        
        let deposit = pool.pools.first?.minStake.toTon() ?? "0"
        let depositItem = StakingInfoCell.Model(
            identifier: "Minimal deposit",
            cellContentModel: .init(title: "Minimal deposit", description: "\(deposit) TON", tagModel: nil)
        )
        
        let socials = [pool.url] + pool.socials
        let socialItems = socials.compactMap { social in
            let attributedTitle = social.social.name.withTextStyle(.label2, color: .Button.secondaryForeground)
            
            let contentModel = StakingInfoSocialCellContentView.Model(
                tokenModel: .init(
                    iconModel: .image(social.social.icon),
                    title: attributedTitle,
                    accessoryType: nil,
                    highlithedColor: .Button.secondaryBackgroundHighlighted,
                    normalColor: .Button.secondaryBackground
                ),
                didSelect: { [weak self] in
                    if let url = URL(string: social) {
                        self?.didSelectUrl?(url)
                    }
                }
            )
            
            return StakingInfoSocialCell.Model(
                identifier: social,
                cellContentModel: contentModel
            )
        }
        
        return [.info(items: [apyItem, depositItem]), .social(items: socialItems)]
    }
}

private extension String {
    var social: (icon: UIImage, name: String) {
        var icon: UIImage?
        var name: String?
        if let url = URL(string: self), let lowercasedHost = url.host?.lowercased() {
            if lowercasedHost.contains("t.me") {
                name = "Community"
            } else if lowercasedHost.contains("twitter") {
                name = "Twitter"
            } else {
                name = lowercasedHost
            }
        }
        let resultIcon = (icon ?? .TKUIKit.Icons.Size16.globe)
            .withTintColor(
                .Text.primary,
                renderingMode: .alwaysOriginal
            )
            .withAlignmentRectInsets(.init(top: -3, left: -3, bottom: -3, right: -3))
        return (resultIcon, name ?? self)
    }
}
