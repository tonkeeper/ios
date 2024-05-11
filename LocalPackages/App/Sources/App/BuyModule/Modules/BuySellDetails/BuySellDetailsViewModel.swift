import UIKit
import TKUIKit
import KeeperCore
import TKCore

struct BuySellDetailsItem {
  struct CurrencyDirection {
    var from: Currency
    var to: Currency
  }
  
  struct ServiceInfo {
    struct InfoButton {
      var title: String
      var url: URL?
    }
    
    var provider: String
    var leftButton: InfoButton?
    var rightButton: InfoButton?
  }
  
  var iconUrl: URL?
  var serviceTitle: String
  var serviceSubtitle: String
  var serviceInfo: ServiceInfo
  var amountPay: String
  var currencyDirection: CurrencyDirection
}

struct BuySellDetailsModel {
  enum Icon {
    case image(UIImage?)
    case asyncImage(TKCore.ImageDownloadTask)
  }
  
  struct TextField {
    let placeholder: String
    let inputText: String
    let currencyCode: String
  }
  
  struct Button {
    let title: String
    let isEnabled: Bool
    let isActivity: Bool
    let action: (() -> Void)
  }
  
  struct InfoContainer {
    struct InfoButton {
      let title: String
      let action: (() -> Void)
    }
    
    let description: String
    let leftButton: InfoButton?
    let rightButton: InfoButton?
  }
  
  let icon: Icon
  let title: String
  let subtitle: String
  let textFieldPay: TextField
  let textFieldGet: TextField
  let convertedRate: String
  let infoContainer: InfoContainer
  let continueButton: Button
}

protocol BuySellDetailsModuleOutput: AnyObject {
  var didTapContinue: (() -> Void)? { get set }
  var didTapInfoButton: ((URL?) -> Void)? { get set }
}

protocol BuySellDetailsModuleInput: AnyObject {
  
}

protocol BuySellDetailsViewModel: AnyObject {
  var didUpdateModel: ((BuySellDetailsModel) -> Void)? { get set }
  
  func viewDidLoad()
  func didInputAmountPay(_ string: String)
  func didInputAmountGet(_ string: String)
}

final class BuySellDetailsViewModelImplementation: BuySellDetailsViewModel, BuySellDetailsModuleOutput, BuySellDetailsModuleInput {
  
  // MARK: - BuySellDetailsModelModuleOutput
  
  var didTapContinue: (() -> Void)?
  var didTapInfoButton: ((URL?) -> Void)?
  
  // MARK: - BuySellDetailsModelModuleInput
  
  // MARK: - BuySellDetailsModelViewModel
  
  var didUpdateModel: ((BuySellDetailsModel) -> Void)?
  
  func viewDidLoad() {
    update()
    
    Task {
      await buySellDetailsController.start()
    }
  }
  
  func didInputAmountPay(_ string: String) {
    
  }
  
  func didInputAmountGet(_ string: String) {
    
  }
  
  // MARK: - State
  
  private var amountPay = ""
  private var amountGet = ""
  private var convertedRate = ""
  
  private var isResolving = false {
    didSet {
      guard isResolving != oldValue else { return }
      update()
    }
  }
  
  private var isContinueEnable: Bool {
    true
  }
  
  // MARK: - Dependencies
  
  private let imageLoader = ImageLoader()
  
  private let buySellDetailsController: BuySellDetailsController
  private var buySellDetailsItem: BuySellDetailsItem
  
  // MARK: - Init
  
  init(buySellDetailsController: BuySellDetailsController, buySellDetailsItem: BuySellDetailsItem) {
    self.buySellDetailsController = buySellDetailsController
    self.buySellDetailsItem = buySellDetailsItem
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension BuySellDetailsViewModelImplementation {
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> BuySellDetailsModel {
    let iconUrl = buySellDetailsItem.iconUrl
    
    let iconImageDownloadTask = TKCore.ImageDownloadTask { [imageLoader] imageView, size, cornerRadius in
      return imageLoader.loadImage(
        url: iconUrl,
        imageView: imageView,
        size: size,
        cornerRadius: cornerRadius
      )
    }
    
    return BuySellDetailsModel(
      icon: .asyncImage(iconImageDownloadTask),
      title: buySellDetailsItem.serviceTitle,
      subtitle: buySellDetailsItem.serviceSubtitle,
      textFieldPay: .init(placeholder: "You Pay", inputText: "", currencyCode: buySellDetailsItem.currencyDirection.from.code),
      textFieldGet: .init(placeholder: "You Get", inputText: "", currencyCode: buySellDetailsItem.currencyDirection.to.code),
      convertedRate: "2,330.01 AMD for 1 TON", // TODO: Rate converter and formatter
      infoContainer: createInfoContainerModel(buySellDetailsItem.serviceInfo),
      continueButton: .init(
        title: "Continue",
        isEnabled: !isResolving && isContinueEnable,
        isActivity: isResolving,
        action: { [weak self] in
          self?.didTapContinue?()
        }
      )
    )
    
    func createInfoContainerModel(_ serviceInfo: BuySellDetailsItem.ServiceInfo) -> BuySellDetailsModel.InfoContainer {
      BuySellDetailsModel.InfoContainer(
        description: "Service provided by \(serviceInfo.provider)",
        leftButton: createInfoButtonModel(serviceInfo.leftButton),
        rightButton: createInfoButtonModel(serviceInfo.rightButton)
      )
    }
    
    func createInfoButtonModel(_ button: BuySellDetailsItem.ServiceInfo.InfoButton?) -> BuySellDetailsModel.InfoContainer.InfoButton? {
      guard let button else { return nil }
      return .init(title: button.title) { [weak self] in
        self?.didTapInfoButton?(button.url)
      }
    }
  }
}
