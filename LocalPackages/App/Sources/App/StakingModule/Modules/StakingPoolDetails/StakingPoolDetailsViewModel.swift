import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt
import TKLocalize

protocol StakingPoolDetailsModuleOutput: AnyObject {
  var didSelectPool: ((StackingPoolInfo) -> Void)? { get set }
  var didOpenURL: ((URL) -> Void)? { get set }
  var didOpenURLInApp: ((URL, String?) -> Void)? { get set }
  var didClose: (() -> Void)? { get set }
}

protocol StakingPoolDetailsModuleInput: AnyObject {
  
}

protocol StakingPoolDetailsViewModel: AnyObject {
  var title: String { get }
  var buttonTitle: String { get }
  var listViewModel: StakingDetailsListView.Model { get }
  var description: NSAttributedString { get }
  var linksViewModel: StakingDetailsLinksView.Model { get }
  
  func viewDidLoad()
  func didTapChooseButton()
  func didTapCloseButton()
}

final class StakingPoolDetailsViewModelImplementation: StakingPoolDetailsViewModel, StakingPoolDetailsModuleOutput {
  
  private let pool: StakingListPool
  private let listViewModelBuilder: StakingListViewModelBuilder
  private let linksViewModelBuilder: StakingLinksViewModelBuilder
  
  init(pool: StakingListPool,
       listViewModelBuilder: StakingListViewModelBuilder,
       linksViewModelBuilder: StakingLinksViewModelBuilder) {
    self.pool = pool
    self.listViewModelBuilder = listViewModelBuilder
    self.linksViewModelBuilder = linksViewModelBuilder
  }
  
  // MARK: - StakingPoolDetailsModuleOutput
  
  var didSelectPool: ((StackingPoolInfo) -> Void)?
  var didOpenURLInApp: ((URL, String?) -> Void)?
  var didOpenURL: ((URL) -> Void)?
  var didClose: (() -> Void)?
  
  // MARK: - StakingViewModel
  
  var title: String {
    pool.pool.name
  }
  
  var buttonTitle: String {
    TKLocales.StakingPoolDetails.choose
  }
  
  var listViewModel: StakingDetailsListView.Model {
    listViewModelBuilder.build(stakingPoolInfo: pool.pool, isMaxAPY: pool.isMaxAPY)
  }
  
  var description: NSAttributedString {
    String.description.withTextStyle(.body3, color: .Text.tertiary, alignment: .left, lineBreakMode: .byWordWrapping)
  }
  
  var linksViewModel: StakingDetailsLinksView.Model {
    linksViewModelBuilder.buildModel(
      poolInfo: pool.pool,
      openURL: { [weak self] url in
        self?.didOpenURL?(url)
      },
      openURLInApp: { [weak self] url in
        self?.didOpenURLInApp?(url, nil)
      }
    )
  }
  
  func viewDidLoad() {}
  
  func didTapCloseButton() {
    didClose?()
  }
  
  func didTapChooseButton() {
    didSelectPool?(pool.pool)
  }
}

private extension String {
  static let mostProfitableTag = TKLocales.StakingPoolDetails.maxApy
  static let apy = TKLocales.StakingPoolDetails.apy
  static let minimalDeposit = TKLocales.StakingPoolDetails.minimalDeposit
  static let description = TKLocales.StakingPoolDetails.description
}
