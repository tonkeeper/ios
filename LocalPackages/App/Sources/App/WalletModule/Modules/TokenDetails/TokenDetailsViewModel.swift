import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKCore

protocol TokenDetailsModuleOutput: AnyObject {
  
}

protocol TokenDetailsViewModel: AnyObject {
  var didUpdateTitleView: ((TokenDetailsTitleView.Model) -> Void)? { get set }
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
  var didUpdateChartViewController: ((UIViewController) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TokenDetailsViewModelImplementation: TokenDetailsViewModel, TokenDetailsModuleOutput {
  
  // MARK: - TokenDetailsModuleOutput
  
  
  // MARK: - TokenDetailsViewModel
  
  var didUpdateTitleView: ((TokenDetailsTitleView.Model) -> Void)?
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
  var didUpdateChartViewController: ((UIViewController) -> Void)?
  
  func viewDidLoad() {
    tokenDetailsController.reloadTokenModel()
    setupChart()
  }
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()

  // MARK: - Dependencies
  
  private let tokenDetailsController: TokenDetailsController
  private let chartViewControllerProvider: (() -> UIViewController?)?
  
  // MARK: - Init
  
  init(tokenDetailsController: TokenDetailsController,
       chartViewControllerProvider: (() -> UIViewController?)?) {
    self.tokenDetailsController = tokenDetailsController
    self.chartViewControllerProvider = chartViewControllerProvider
    tokenDetailsController.didUpdateTokenModel = { [weak self] model in
      guard let self = self else { return }
      Task {
        await self.didUpdateTokenModel(model: model)
      }
    }
  }
}

private extension TokenDetailsViewModelImplementation {
  @MainActor
  func didUpdateTokenModel(model: TokenDetailsController.TokenModel) {
    setupTitleView(model: model)
    setupInformationView(model: model)
  }
  
  func setupTitleView(model: TokenDetailsController.TokenModel) {
    didUpdateTitleView?(
      TokenDetailsTitleView.Model(
        title: model.tokenTitle,
        warning: model.tokenSubtitle
      )
    )
  }
  
  func setupInformationView(model: TokenDetailsController.TokenModel) {
    let image: TokenDetailsInformationView.Model.Image
    switch model.image {
    case .ton:
      image = .image(.TKCore.Icons.Size44.tonLogo)
    case .url(let url):
      image = .asyncImage(
        TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(url: url, imageView: imageView, size: size, cornerRadius: cornerRadius)
          }
        )
      )
    }
    
    didUpdateInformationView?(
      TokenDetailsInformationView.Model(
        image: image,
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
