import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKCore
import TKLocalize

protocol TokenDetailsModuleOutput: AnyObject {
  var didTapSend: ((KeeperCore.Token) -> Void)? { get set }
  var didTapReceive: ((KeeperCore.Token) -> Void)? { get set }
  var didTapBuyOrSell: (() -> Void)? { get set }
  var didTapSwap: ((KeeperCore.Token) -> Void)? { get set }
  var didOpenURL: ((URL) -> Void)? { get set }
}

protocol TokenDetailsViewModel: AnyObject {
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)? { get set }
  var didUpdateChartViewController: ((UIViewController) -> Void)? { get set }
  var didUpdateBannerItems: (([TokenDetailsBannerItem]) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapOpenDetails()
}

struct TokenDetailsModel {
  struct Button {
    let iconButton: IconButton
    let isEnable: Bool
  }
  struct Caption {
    let text: NSAttributedString
    let icon: UIImage?
    let action: (() -> Void)?
    
    init(text: NSAttributedString,
         icon: UIImage? = nil,
         action: (() -> Void)? = nil) {
      self.text = text
      self.icon = icon
      self.action = action
    }
  }
  enum Network {
    case ton
    case trc20
    case none
  }
  let title: String
  let caption: Caption?
  let image: TKImage
  let network: Network
  let tokenAmount: String
  let convertedAmount: String?
  let buttons: [Button]
  let bannerItems: [TokenDetailsBannerItem]
}

final class TokenDetailsViewModelImplementation: TokenDetailsViewModel, TokenDetailsModuleOutput {
  // MARK: - TokenDetailsModuleOutput
  
  var didTapSend: ((KeeperCore.Token) -> Void)?
  var didTapReceive: ((KeeperCore.Token) -> Void)?
  var didTapBuyOrSell: (() -> Void)?
  var didTapSwap: ((KeeperCore.Token) -> Void)?
  var didOpenURL: ((URL) -> Void)?
  
  // MARK: - TokenDetailsViewModel
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)?
  var didUpdateChartViewController: ((UIViewController) -> Void)?
  var didUpdateBannerItems: (([any TokenDetailsBannerItem]) -> Void)?
  
  func viewDidLoad() {
    setupObservations()
    setInitialState()
    setupChart()
  }
  
  func didTapOpenDetails() {
    guard let url = configurator.getDetailsURL() else { return }
    didOpenURL?(url)
  }
  
  // MARK: - State
  
  private let syncQueue = DispatchQueue(label: "TokenDetailsViewModelImplementationQueue")
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStore
  private let appSettingsStore: AppSettingsStore
  private let configurator: TokenDetailsConfigurator
  private let chartViewControllerProvider: (() -> UIViewController?)?
  
  // MARK: - Init
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStore,
       appSettingsStore: AppSettingsStore,
       configurator: TokenDetailsConfigurator,
       chartViewControllerProvider: (() -> UIViewController?)?) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.appSettingsStore = appSettingsStore
    self.configurator = configurator
    self.chartViewControllerProvider = chartViewControllerProvider
  }
}

private extension TokenDetailsViewModelImplementation {
  func setInitialState() {
    syncQueue.sync {
      let balance = balanceStore.getState()[wallet]?.balance
      let model = configurator.getTokenModel(balance: balance, isSecureMode: appSettingsStore.getState().isSecureMode)
      DispatchQueue.main.async {
        self.didUpdateModel(model)
      }
    }
  }
  
  func setupObservations() {
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateConvertedBalance(let wallet):
        guard wallet == observer.wallet else { return }
        observer.syncQueue.async {
          let balance = observer.balanceStore.getState()[wallet]?.balance
          let model = observer.configurator.getTokenModel(balance: balance, isSecureMode: observer.appSettingsStore.getState().isSecureMode)
          DispatchQueue.main.async {
            self.didUpdateModel(model)
          }
        }
      }
    }
  }
  
  func didUpdateModel(_ model: TokenDetailsModel) {
    setupTitleView(model: model)
    setupInformationView(model: model)
    setupButtonsView(model: model)
    setupBanners(model: model)
  }
  
  func setupTitleView(model: TokenDetailsModel) {
    didUpdateTitleView?(
      TKUINavigationBarTitleView.Model(
        title: model.title,
        caption: {
          guard let caption = model.caption else { return nil }
          return TKPlainButton.Model(title: caption.text, action: caption.action)
        }()
      )
    )
  }
  
  func setupButtonsView(model: TokenDetailsModel) {
    let mapper = IconButtonModelMapper()
    let buttons = model.buttons.map { buttonModel in
      return TokenDetailsHeaderButtonsView.Model.Button(
        configuration: mapper.mapButton(model: buttonModel.iconButton),
        isEnabled: buttonModel.isEnable,
        action: { [weak self] in
          switch buttonModel.iconButton {
          case .send(let token):
            self?.didTapSend?(token)
          case .receive(let token):
            self?.didTapReceive?(token)
          case .buySell:
            self?.didTapBuyOrSell?()
          case .swap(let token):
            self?.didTapSwap?(token)
          default:
            break
          }
        }
      )
    }
    let model = TokenDetailsHeaderButtonsView.Model(buttons: buttons)
    didUpdateButtonsView?(model)
  }
  
  func setupInformationView(model: TokenDetailsModel) {
    let badge: TKListItemIconView.Configuration.Badge? = {
      switch model.network {
      case .none:
        return nil
      case .ton:
        return TKListItemIconView.Configuration.Badge(
          configuration: TKListItemBadgeView.Configuration(
            item: .image(.image(.App.Currency.Vector.ton)),
            size: .large,
            backgroundColor: .Background.page
          ),
          position: .bottomRight
        )
      case .trc20:
        return TKListItemIconView.Configuration.Badge(
          configuration: TKListItemBadgeView.Configuration(
            item: .image(.image(.App.Currency.Vector.trc20)),
            size: .large,
            backgroundColor: .Background.page
          ),
          position: .bottomRight
        )
      }
    }()
    
    let imageConfiguration = TKListItemIconView.Configuration(
      content: .image(
        TKImageView.Model(
          image: model.image,
          tintColor: .clear,
          size: .size(CGSize(width: 64, height: 64)),
          corners: .circle
        )
      ),
      alignment: .center,
      size: CGSize(width: 64, height: 64),
      badge: badge
    )
    
    didUpdateInformationView?(
      TokenDetailsInformationView.Model(
        imageConfiguration: imageConfiguration,
        tokenAmount: model.tokenAmount,
        convertedAmount: model.convertedAmount
      )
    )
  }
  
  func setupBanners(model: TokenDetailsModel) {
    didUpdateBannerItems?(model.bannerItems)
  }
  
  func setupChart() {
    guard let chartViewController = chartViewControllerProvider?() else { return }
    didUpdateChartViewController?(chartViewController)
  }
}
