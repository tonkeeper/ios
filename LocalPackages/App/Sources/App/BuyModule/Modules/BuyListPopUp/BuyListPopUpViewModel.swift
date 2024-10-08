import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BuyListPopUpModuleOutput: AnyObject {
  var didTapOpen: ((BuySellItem) -> Void)? { get set }
}

protocol BuyListPopUpViewModel: AnyObject {
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  var headerImageView: ((HistoryEventDetailsNFTHeaderImageView.Model) -> UIView)? { get set }
  var descriptionView: ((TKDetailsDescriptionView.Model) -> UIView)? { get set }
  var doNotShowView: ((TKDetailsTickView.Model) -> UIView)? { get set }
  
  func viewDidLoad()
}

final class BuyListPopUpViewModelImplementation: BuyListPopUpViewModel, BuyListPopUpModuleOutput {
  
  // MARK: - BuyListPopUpModuleOutput
  
  var didTapOpen: ((BuySellItem) -> Void)?
  
  // MARK: - BuyListPopUpViewModel
  
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
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
    
    var isDoNotShowMarked = false
    
    let imageItem = TKPopUp.Component.ImageComponent(
      image: TKImageView.Model(image: .urlImage(buySellItem.fiatItem.iconURL),
                               size: .size(CGSize(width: 64, height: 64)),
                               corners: .cornerRadius(cornerRadius: 12),
                               padding: .zero),
      bottomSpace: 20
    )
    
    let titleCaption = TKPopUp.Component.TitleCaption(
      title: buySellItem.fiatItem.title,
      caption: buySellItem.fiatItem.description,
      bottomSpace: 16
    )
    
    let descriptionButtons: [TKDetailsDescriptionView.Model.Button] = buySellItem.fiatItem.infoButtons.map { infoButton in
      TKDetailsDescriptionView.Model.Button(text: infoButton.title, closure: { [weak self] in
        guard let url = URL(string: infoButton.url) else { return }
        self?.urlOpener.open(url: url)
      })
    }
    let description: TKPopUp.Item = {
      TKPopUp.Component.GroupComponent(
        padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
        items: [
          TKPopUp.Component.DetailsDescription(
            model: TKDetailsDescriptionView.Model(
              title: .externalWarningText,
              buttons: descriptionButtons
            ))
        ],
        bottomSpace: 16
      )
    }()
    
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    buttonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString("\(TKLocales.Actions.open) \(buySellItem.fiatItem.title)")
    )
    buttonConfiguration.action = { [weak self] in
      guard let self else { return }
      appSettings.setIsBuySellItemMarkedDoNotShowWarning(
        self.buySellItem.fiatItem.id, 
        doNotShow: isDoNotShowMarked
      )
      self.didTapOpen?(self.buySellItem)
    }
    
    let buttons = TKPopUp.Component.ButtonGroupComponent(buttons: [
      TKPopUp.Component.ButtonComponent(buttonConfiguration: buttonConfiguration)
    ], bottomSpace: 16)
    
    let doNotShowItem = TKPopUp.Component.TickItem(
      model: TKDetailsTickView.Model(
        text: TKLocales.Tick.doNotShowAgain,
        tick: TKDetailsTickView.Model.Tick(
          isSelected: isDoNotShowMarked,
          closure: {
            isDoNotShowMarked = $0
          }
        )
      ),
      bottomSpace: 16
    )
    
    let configuration = TKPopUp.Configuration(
      items: [
        imageItem,
        titleCaption,
        description,
        buttons,
        doNotShowItem
      ]
    )
    
    didUpdateConfiguration?(configuration)
  }
}

private extension String {
  static let checkmarkTitle = TKLocales.Tick.doNotShowAgain
  static let externalWarningText = TKLocales.BuyListPopup.youAreOpeningExternalApp
}
