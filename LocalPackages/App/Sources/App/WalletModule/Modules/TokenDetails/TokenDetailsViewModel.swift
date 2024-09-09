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
  private let balanceStore: ConvertedBalanceStore
  private let configurator: TokenDetailsConfigurator
  private let chartViewControllerProvider: (() -> UIViewController?)?
  
  // MARK: - Init
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStore,
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
      let balance = balanceStore.getState()[wallet]?.balance
      let model = configurator.getTokenModel(balance: balance)
      DispatchQueue.main.async {
        self.didUpdateModel(model)
      }
    }
  }
  
  func setupObservations() {
    balanceStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateConvertedBalance(_, let wallet):
        guard wallet == observer.wallet else { return }
        observer.syncQueue.async {
          let balance = observer.balanceStore.getState()[wallet]?.balance
          let model = observer.configurator.getTokenModel(balance: balance)
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
      let isEnabled: Bool
      switch buttonModel {
      case .send(_, let enabled):
        isEnabled = enabled
      default:
        isEnabled = true
      }
      
      return TokenDetailsHeaderButtonsView.Model.Button(
        configuration: mapper.mapButton(model: buttonModel),
        isEnabled: isEnabled,
        action: { [weak self] in
          switch buttonModel {
          case .send(let token, _):
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
        imageConfiguration: TKUIListItemIconView.Configuration(
          iconConfiguration: .image(TKUIListItemImageIconView.Configuration(
            image: image,
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 64, height: 64),
            cornerRadius: 32,
            contentMode: .scaleAspectFit
          )),
          alignment: .center
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
