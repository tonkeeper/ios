import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

public struct CustomizeWalletModel {
  public let name: String
  public let tintColor: WalletTintColor
  public let icon: WalletIcon
}

public protocol CustomizeWalletModuleOutput: AnyObject {
  var didCustomizeWallet: ((CustomizeWalletModel) -> Void)? { get set }
}

protocol CustomizeWalletViewModel: AnyObject {
  var didUpdateModel: ((CustomizeWalletView.Model) -> Void)? { get set }
  var didSelectEmoji: ((EmojisDataSource.Emoji) -> Void)? { get set }
  var didSelectWalletIcon: ((WalletColorIconBadgeView.Model) -> Void)? { get set }
  var didSelectColor: ((UIColor) -> Void)? { get set }
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func setWalletName(_ name: String)
  func setIcon(_ walletIcon: WalletIcon)
}

final class CustomizeWalletViewModelImplementation: CustomizeWalletViewModel, CustomizeWalletModuleOutput {
  
  // MARK: - CustomizeWalletModuleOutput
  
  var didCustomizeWallet: ((CustomizeWalletModel) -> Void)?
  
  // MARK: - CustomizeWalletViewModel
  
  var didUpdateModel: ((CustomizeWalletView.Model) -> Void)?
  var didSelectEmoji: ((EmojisDataSource.Emoji) -> Void)?
  var didSelectWalletIcon: ((WalletColorIconBadgeView.Model) -> Void)?
  var didSelectColor: ((UIColor) -> Void)?
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel(items: []))
    didUpdateContinueButtonIsEnabled?(true)
    Task {
      let items = await createIconPickerItems()
      guard !items.isEmpty else { return }
      await MainActor.run {
        didSelectWalletIcon?((items.first(where: { $0 == self.icon }) ?? items[0]).colorIconBadgeViewModel)
        didUpdateModel?(createModel(items: items))
        didSelectColor?(self.tintColor.uiColor)
      }
    }
  }
  
  func setWalletName(_ name: String) {
    let isNameValid = !name.isEmpty
    self.name = isNameValid ? name : .defaultWalletName
    didUpdateContinueButtonIsEnabled?(isNameValid)
    configurator.didEditName()
  }
  
  func setIcon(_ walletIcon: WalletIcon) {
    self.icon = walletIcon
    self.didSelectWalletIcon?(walletIcon.colorIconBadgeViewModel)
    self.configurator.didSelectColor()
  }
  
  // MARK: - Data Source
  
  private var emojiDataSource = EmojisDataSource()

  // MARK: - Dependencies
  
  private var name: String
  private var tintColor: WalletTintColor
  private var icon: WalletIcon
  private let configurator: CustomizeWalletViewModelConfigurator
  
  init(name: String? = nil,
       tintColor: WalletTintColor? = nil,
       icon: WalletIcon? = nil,
       configurator: CustomizeWalletViewModelConfigurator) {
    self.name = name ?? .defaultWalletName
    self.tintColor = tintColor ?? .defaultColor
    self.icon = icon ?? .default
    self.configurator = configurator
    
    configurator.didCustomizeWallet = { [weak self] in
      self?.didFinishCustomization()
    }
  }
}

private extension CustomizeWalletViewModelImplementation {
  func createModel(items: [WalletIcon]) -> CustomizeWalletView.Model {
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: TKLocales.CustomizeWallet.title,
      bottomDescription: TKLocales.CustomizeWallet.description
    )
    
    let walletNameTextFieldPlaceholder = TKLocales.CustomizeWallet.inputPlaceholder

    let colorPickerModel = createColorPickerModel()
    let iconPickerModel = WalletIconPickerView.Model(items: items)
    
    var continueButtonConfiguration: TKButton.Configuration?
    switch configurator.continueButtonMode {
    case .hidden:
      continueButtonConfiguration = nil
    case .visible(let title, let action):
      continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
        category: .primary,
        size: .large
      )
      continueButtonConfiguration?.content.title = .plainString(title)
      continueButtonConfiguration?.action = action
    }
  
    return CustomizeWalletView.Model(
      titleDescriptionModel: titleDescriptionModel,
      continueButtonConfiguration: continueButtonConfiguration,
      walletNameTextFieldPlaceholder: walletNameTextFieldPlaceholder,
      walletNameDefaultValue: name,
      colorPickerModel: colorPickerModel,
      iconPickerModel: iconPickerModel
    )
  }
  
  func createColorPickerModel() -> WalletColorPickerView.Model {
    var colorItems = [WalletColorPickerView.Model.ColorItem]()
    var initialSelectedIndex: Int?
    for (index, color) in WalletTintColor.allCases.enumerated() {
      let colorItem = WalletColorPickerView.Model.ColorItem(
        color: color.uiColor) { [weak self] in
          self?.didSelectColor?(color.uiColor)
          self?.tintColor = color
          self?.configurator.didSelectColor()
        }
      colorItems.append(colorItem)
      if tintColor == color {
        initialSelectedIndex = index
      }
    }
    return WalletColorPickerView.Model(
      items: colorItems,
      intitialSelectedIndex: initialSelectedIndex
    )
  }
  
  func createIconPickerItems() async -> [WalletIcon] {
    let emojis = await emojiDataSource.loadData()
    let images = WalletIcon.Image.allCases

    let imageItems = images.map { image in
      WalletIcon.icon(image)
    }
    let emojiItems = emojis.map { emoji in
      WalletIcon.emoji(emoji.emoji)
    }
    return imageItems + emojiItems
  }
  
  func didFinishCustomization() {
    let model = CustomizeWalletModel(
      name: name,
      tintColor: tintColor,
      icon: icon
    )
    didCustomizeWallet?(model)
  }
}

private extension WalletIcon {
  var colorIconBadgeViewModel: WalletColorIconBadgeView.Model {
    switch self {
    case .emoji(let string):
      return .emoji(string)
    case .icon(let image):
      return .image(image.image)
    }
  }
}

private extension Int {
  static let colorsCount = 26
}

private extension WalletIcon {
  static var `default`: WalletIcon {
    .icon(.wallet)
  }
}

private extension String {
  static let defaultWalletName = TKLocales.CustomizeWallet.defaultWalletName
}
