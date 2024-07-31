import UIKit
import TKUIKit
import KeeperCore
import TKCore

protocol BuyListPopUpModuleOutput: AnyObject {
  var didTapOpen: ((BuySellItem) -> Void)? { get set }
}

protocol BuyListPopUpViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  var headerImageView: ((HistoryEventDetailsNFTHeaderImageView.Model) -> UIView)? { get set }
  var descriptionView: ((TKDetailsDescriptionView.Model) -> UIView)? { get set }
  var doNotShowView: ((TKDetailsTickView.Model) -> UIView)? { get set }
  
  func viewDidLoad()
}

final class BuyListPopUpViewModelImplementation: BuyListPopUpViewModel, BuyListPopUpModuleOutput {
  
  // MARK: - BuyListPopUpModuleOutput
  
  var didTapOpen: ((BuySellItem) -> Void)?
  
  // MARK: - BuyListPopUpViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  var headerImageView: ((HistoryEventDetailsNFTHeaderImageView.Model) -> UIView)?
  var descriptionView: ((TKDetailsDescriptionView.Model) -> UIView)?
  var doNotShowView: ((TKDetailsTickView.Model) -> UIView)?
  
  func viewDidLoad() {
    configure()
  }
  
  // MARK: - State
  
  private var doNotShowAgain = false
  
  // MARK: - Dependencies
  
  private let buySellItem: BuySellItem
  private let appSettings: AppSettings
  private let urlOpener: URLOpener
  
  // MARK: - Init
  
  init(buySellItem: BuySellItem,
       appSettings: AppSettings,
       urlOpener: URLOpener) {
    self.buySellItem = buySellItem
    self.appSettings = appSettings
    self.urlOpener = urlOpener
  }
}

private extension BuyListPopUpViewModelImplementation {
  func configure() {
    
    var headerItems = [TKModalCardViewController.Configuration.Item]()
    
    if let headerImageView = headerImageView?(
      HistoryEventDetailsNFTHeaderImageView.Model(
        image: .url(buySellItem.fiatItem.iconURL),
        size: CGSize(
          width: 64,
          height: 64
        )
      )
    ) {
      headerItems.append(.customView(headerImageView, bottomSpacing: 20))
    }
    
    headerItems.append(contentsOf: [
      .text(.init(text: buySellItem.fiatItem.title.withTextStyle(
        .h2,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      ), numberOfLines: 1), bottomSpacing: 4),
      .text(.init(text: buySellItem.fiatItem.description?.withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      ), numberOfLines: 0), bottomSpacing: 0)
    ])
    
    let header = TKModalCardViewController.Configuration.Header(items: headerItems)
    
    var contentItems = [TKModalCardViewController.Configuration.ContentItem]()
    
    let descriptionButtons: [TKDetailsDescriptionView.Model.Button] = buySellItem.fiatItem.infoButtons.map { infoButton in
      TKDetailsDescriptionView.Model.Button(text: infoButton.title, closure: { [weak self] in
        guard let url = URL(string: infoButton.url) else { return }
        self?.urlOpener.open(url: url)
      })
    }
    if let descriptionView = descriptionView?(
      TKDetailsDescriptionView.Model(
        title: .externalWarningText,
        buttons: descriptionButtons
      )) {
      contentItems.append(.item(.customView(descriptionView, bottomSpacing: 32)))
    }
    
    contentItems.append(
      .item(
        .button(
          TKModalCardViewController.Configuration.Button(
            title: "Open \(buySellItem.fiatItem.title)",
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: { [weak self] _, _ in
              guard let self else { return }
              self.appSettings.setIsBuySellItemMarkedDoNotShowWarning(
                self.buySellItem.fiatItem.id,
                doNotShow: self.doNotShowAgain
              )
              self.didTapOpen?(self.buySellItem)
            }
          ),
          bottomSpacing: 16
        )
      )
    )
    
    if let doNotShowView = doNotShowView?(
      TKDetailsTickView.Model(
        text: .checkmarkTitle,
        tick: TKDetailsTickView.Model.Tick(
          isSelected: false,
          closure: { [weak self] in
            self?.doNotShowAgain = $0
          }
        )
      )
    ) {
      contentItems.append(.item(.customView(doNotShowView, bottomSpacing: 4)))
    }
    
    let configuration = TKModalCardViewController.Configuration(
      header: header,
      content: TKModalCardViewController.Configuration.Content(items: contentItems),
      actionBar: nil
    )
    didUpdateConfiguration?(configuration)
  }
}

private extension String {
  static let checkmarkTitle = "Do not show again"
  static let externalWarningText = "You are opening an external app not operated by Tonkeeper."
}
