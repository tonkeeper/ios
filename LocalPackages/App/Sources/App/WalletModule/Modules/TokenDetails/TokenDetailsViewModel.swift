import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKCore

protocol TokenDetailsModuleOutput: AnyObject {
  var didTapSend: ((KeeperCore.Token) -> Void)? { get set }
  var didTapReceive: ((KeeperCore.Token) -> Void)? { get set }
  var didTapBuyOrSell: (() -> Void)? { get set }
}

protocol TokenDetailsViewModel: AnyObject {
  var didUpdateTitleView: ((TokenDetailsTitleView.Model) -> Void)? { get set }
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)? { get set }
  var didUpdateChartViewController: ((UIViewController) -> Void)? { get set }
  
  func viewDidLoad()
}

struct TokenDetailsModel {
  let tokenTitle: String
  let tokenSubtitle: String?
  let image: TokenImage
  let tokenAmount: String
  let convertedAmount: String?
  let buttons: [IconButton]
}

final class TokenDetailsViewModelImplementation: TokenDetailsViewModel, TokenDetailsModuleOutput {
  // MARK: - TokenDetailsModuleOutput
  
  var didTapSend: ((KeeperCore.Token) -> Void)?
  var didTapReceive: ((KeeperCore.Token) -> Void)?
  var didTapBuyOrSell: (() -> Void)?
  
  // MARK: - TokenDetailsViewModel
  
  var didUpdateTitleView: ((TokenDetailsTitleView.Model) -> Void)?
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)?
  var didUpdateChartViewController: ((UIViewController) -> Void)?
  
  func viewDidLoad() {
    setupObservations()
    setInitialState()
    setupChart()
  }
  
  // MARK: - State
  
  private let syncQueue = DispatchQueue(label: "TokenDetailsViewModelImplementationQueue")
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()

  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStoreV2
  private let configurator: TokenDetailsConfigurator
  private let chartViewControllerProvider: (() -> UIViewController?)?
  
  // MARK: - Init
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStoreV2,
       configurator: TokenDetailsConfigurator,
       chartViewControllerProvider: (() -> UIViewController?)?) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.configurator = configurator
    self.chartViewControllerProvider = chartViewControllerProvider
  }
}

private extension TokenDetailsViewModelImplementation {
  func setInitialState() {
    syncQueue.sync {
      guard let address = try? wallet.friendlyAddress else {
        return
      }
      let balance = balanceStore.getState()[address]?.balance
      let model = configurator.getTokenModel(balance: balance)
      DispatchQueue.main.async {
        self.didUpdateModel(model)
      }
    }
  }
  
  func setupObservations() {
    balanceStore.addObserver(
      self,
      notifyOnAdded: false) { observer, newState, oldState in
        observer.syncQueue.sync {
          guard let address = try? observer.wallet.friendlyAddress else {
            return
          }
          let balance = newState[address]?.balance
          let model = observer.configurator.getTokenModel(balance: balance)
          DispatchQueue.main.async {
            self.didUpdateModel(model)
          }
        }
      }
  }
  
  func didUpdateModel(_ model: TokenDetailsModel) {
    setupTitleView(model: model)
    setupInformationView(model: model)
    setupButtonsView(model: model)
  }
  
  func setupTitleView(model: TokenDetailsModel) {
    didUpdateTitleView?(
      TokenDetailsTitleView.Model(
        title: model.tokenTitle,
        warning: model.tokenSubtitle
      )
    )
  }
  
  func setupButtonsView(model: TokenDetailsModel) {
    let mapper = IconButtonModelMapper()
    let buttons = model.buttons.map { buttonModel in
      TokenDetailsHeaderButtonsView.Model.Button(
        configuration: mapper.mapButton(model: buttonModel),
        action: { [weak self] in
          switch buttonModel {
          case .send(let token):
            self?.didTapSend?(token)
          case .receive(let token):
            self?.didTapReceive?(token)
          case .buySell:
            self?.didTapBuyOrSell?()
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
    let image: TKUIListItemImageIconView.Configuration.Image
    switch model.image {
    case .ton:
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      image = .asyncImage(url, TKCore.ImageDownloadTask(
        closure: {
          [imageLoader] imageView,
          size,
          cornerRadius in
          return imageLoader.loadImage(url: url, imageView: imageView, size: size, cornerRadius: cornerRadius)
        }
      ))
    }
    
    didUpdateInformationView?(
      TokenDetailsInformationView.Model(
        imageConfiguration: TKUIListItemImageIconView.Configuration(
          image: image,
          tintColor: .clear,
          backgroundColor: .clear,
          size: CGSize(width: 64, height: 64),
          cornerRadius: 32,
          contentMode: .scaleAspectFit
        ),
        tokenAmount: model.tokenAmount,
        convertedAmount: model.convertedAmount
      )
    )
  }
  
  func setupChart() {
    guard let chartViewController = chartViewControllerProvider?() else { return }
    didUpdateChartViewController?(chartViewController)
  }
}
