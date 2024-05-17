import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingOptionDetailsModuleOutput: AnyObject {
  var didChooseOption: ((OptionItem) -> Void)? { get set }
}

protocol StakingOptionDetailsViewModel: AnyObject {
  var didUpdateTitle: ((String) -> Void)? { get set }
  var didUpdateModel: ((StakingOptionDetailsView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakingOptionDetailsViewModelImplementation: StakingOptionDetailsViewModel, StakingOptionDetailsModuleOutput {
  
  // MARK: - StakingOptionDetailsModuleOutput
  
  var didChooseOption: ((OptionItem) -> Void)?
  
  // MARK: - StakingOptionDetailsViewModel
  
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateModel: ((StakingOptionDetailsView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitle?(item.title)
    
    let model = StakingOptionDetailsView.Model.init(
      textList: [(.apy, "≈ \(item.apyPercents)"), (.minDeposit, item.minDepositAmount)],
      hintText: .hint,
      subtitle: .links,
      linkButtonModels: [
        [
          createConfiguration(kind: .tonstakers),
          createConfiguration(kind: .twitter)
        ],
        [
          createConfiguration(kind: .community),
          createConfiguration(kind: .tonviewer)
        ]
      ],
      chooseButtonConfiguration: createChooseButtonConfiguration()
    ) { [weak self] linkButtonKind in
      guard let self, let url = linkButtonKind.url else { return }

      self.urlOpener.open(url: url)
    }
    
    didUpdateModel?(model)
  }
  
  // MARK: - Dependencies
  
  private let item: OptionItem
  private let urlOpener: URLOpener
  
  init(item: OptionItem, urlOpener: URLOpener) {
    self.item = item
    self.urlOpener = urlOpener
  }
}

// MARK: - Private methods

private extension StakingOptionDetailsViewModelImplementation {
  func createConfiguration(kind: LinkButtonKind) -> StakingOptionDetailsView.Model.LinkButtonModel {
    var configuration = TKButton.Configuration()
    
    let styledTitle = kind.title.withTextStyle(.label2, color: .Button.secondaryForeground)
    configuration.content.title = .attributedString(styledTitle)
    configuration.iconTintColor = .Button.secondaryForeground
    configuration.iconPosition = .left
    configuration.content.icon = kind.image
    configuration.spacing = 8
    configuration.contentPadding = .actionButtonContentInsets
    configuration.backgroundColors = [.normal: .Button.secondaryBackground]
    configuration.contentAlpha = [.highlighted:  0.48]
    
    return .init(kind: kind, configuration: configuration)
  }
  
  func createChooseButtonConfiguration() -> TKButton.Configuration {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    
    configuration.content.title = .plainString(.chooseButtonTitle)
    configuration.action = { [weak self] in
      guard let self else { return }
      
      self.didChooseOption?(self.item)
    }
    
    return configuration
  }
}

private extension String {
  static let apy = "APY"
  static let minDeposit = "Minimum deposit"
  static let hint = "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience."
  static let tonstakers = "tonstalers.com"
  static let twitter = "Twitter"
  static let community = "Community"
  static let tonviewer = "tonviewer.com"
  static let links = "Links"
  static let chooseButtonTitle = "Choose"
  
}

private extension LinkButtonKind {
  var title: String {
    switch self {
    case .tonstakers:
      return .tonstakers
    case .twitter:
      return .twitter
    case .community:
      return .community
    case .tonviewer:
      return .tonviewer
    }
  }

  var image: UIImage {
    switch self {
    case .tonstakers:
      return .TKUIKit.Icons.Size16.globe
    case .twitter:
      return .TKUIKit.Icons.Size16.twitter
    case .community:
      return .TKUIKit.Icons.Size16.telegram
    case .tonviewer:
      return .TKUIKit.Icons.Size16.magnifyingGlass
    }
  }
  
  var url: URL? {
    switch self {
    case .tonstakers:
      return URL(string: "https://tonstakers.com")
    case .twitter:
      return URL(string: "https://twitter.com/tonkeeper")
    case .community:
      return URL(string: "https://t.me/tonkeeper_news")
    case .tonviewer:
      return URL(string: "https://tonviewer.com")
    }
  }
}

private extension UIEdgeInsets {
  static let actionButtonContentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
}
