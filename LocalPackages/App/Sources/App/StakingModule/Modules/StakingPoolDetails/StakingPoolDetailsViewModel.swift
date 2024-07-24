import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt

protocol StakingPoolDetailsModuleOutput: AnyObject {
  var didSelectPool: ((StackingPoolInfo) -> Void)? { get set }
  var didOpenURL: ((URL) -> Void)? { get set }
  var didOpenURLInApp: ((URL, String?) -> Void)? { get set }
}

protocol StakingPoolDetailsModuleInput: AnyObject {
  
}

protocol StakingPoolDetailsViewModel: AnyObject {
  var title: String { get }
  var buttonTitle: String { get }
  var listViewModel: StakingDetailsListView.Model { get }
  var description: NSAttributedString { get }
  var linksViewModel: StakingPoolDetailsLinksView.Model { get }
  
  func viewDidLoad()
  func didTapChooseButton()
}

final class StakingPoolDetailsViewModelImplementation: StakingPoolDetailsViewModel, StakingPoolDetailsModuleOutput {
  
  private let pool: StakingListPool
  private let decimalFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  init(pool: StakingListPool,
       decimalFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.pool = pool
    self.decimalFormatter = decimalFormatter
    self.amountFormatter = amountFormatter
  }
  
  // MARK: - StakingPoolDetailsModuleOutput
  
  var didSelectPool: ((StackingPoolInfo) -> Void)?
  var didOpenURLInApp: ((URL, String?) -> Void)?
  var didOpenURL: ((URL) -> Void)?
  
  // MARK: - StakingViewModel
  
  var title: String {
    pool.pool.name
  }
  
  var buttonTitle: String {
    "Choose"
  }
  
  var listViewModel: StakingDetailsListView.Model {
    
    let percentFormatted = decimalFormatter.format(amount: pool.pool.apy, maximumFractionDigits: 2)
    let percentValue = "≈ \(percentFormatted)%"
    let minimumFormatted = amountFormatter.formatAmount(
      BigUInt(
        UInt64(pool.pool.minStake)
      ),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    )
    
    var apyTag: TKUITagView.Configuration?
    if pool.isMaxAPY {
      apyTag = TKUITagView.Configuration(
        text: .mostProfitableTag,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.16)
      )
    }
    
    return StakingDetailsListView.Model(
      items: [
        StakingDetailsListView.ItemView.Model(
          title: String.apy.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          tag: apyTag,
          value: percentValue.withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
        ),
        StakingDetailsListView.ItemView.Model(
          title: String.minimalDeposit.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          tag: nil,
          value: minimumFormatted.withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
        )
      ]
    )
  }
  
  var description: NSAttributedString {
    String.description.withTextStyle(.body3, color: .Text.tertiary, alignment: .left, lineBreakMode: .byWordWrapping)
  }
  
  var linksViewModel: StakingPoolDetailsLinksView.Model {
    var linkItems = [StakingPoolDetailsLinksView.Model.LinkItem]()
    if let url = URL(string: pool.pool.implementation.urlString),
       let host = url.host {
      let urlButton = StakingPoolDetailsLinksView.Model.LinkItem(title: host, icon: .TKUIKit.Icons.Size16.globe) { [weak self] in
        self?.didOpenURLInApp?(url, "...")
      }
      linkItems.append(urlButton)
    }
    
    for social in pool.pool.implementation.socials {
      guard let url = URL(string: social),
            let host = url.host else {
        continue
      }
      let icon: UIImage
      let title: String
      let action: () -> Void
      switch host {
      case "t.me":
        icon = .TKUIKit.Icons.Size16.telegram
        title = "Community"
        action = { [weak self] in
          self?.didOpenURL?(url)
        }
      case "twitter.com":
        icon = .TKUIKit.Icons.Size16.twitter
        title = "Twitter"
        action = { [weak self] in
          self?.didOpenURL?(url)
        }
      default:
        continue
      }
      
      let button = StakingPoolDetailsLinksView.Model.LinkItem(title: title, icon: icon, action: action)
      linkItems.append(button)
    }
    
    let tonviewerUrlString = "https://tonviewer.com/\(pool.pool.address.toRaw())"
    if let tonviewerUrl = URL(string: tonviewerUrlString) {
      let urlButton = StakingPoolDetailsLinksView.Model.LinkItem(title: "tonviewer.com", icon: .TKUIKit.Icons.Size16.magnifyingGlass) { [weak self] in
        self?.didOpenURLInApp?(tonviewerUrl, "...")
      }
      linkItems.append(urlButton)
    }
    
    return StakingPoolDetailsLinksView.Model(
      header: TKListTitleView.Model(title: "Links", textStyle: .h3),
      linkItems: linkItems
    )
  }
  
  func viewDidLoad() {
    
  }
  
  func didTapChooseButton() {
    didSelectPool?(pool.pool)
  }
}

private extension StakingPoolDetailsViewModelImplementation {
}

private extension String {
  static let mostProfitableTag = "MAX APY"
  static let apy = "APY"
  static let minimalDeposit = "Minimal Deposit"
  static let description = "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience."
}
