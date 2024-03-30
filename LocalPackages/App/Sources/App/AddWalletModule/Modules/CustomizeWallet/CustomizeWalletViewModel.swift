import UIKit
import TKUIKit
import TKCore
import KeeperCore

public struct CustomizeWalletModel {
  public let name: String
  public let tintColor: WalletTintColor
  public let emoji: String
}

public protocol CustomizeWalletModuleOutput: AnyObject {
  var didCustomizeWallet: ((CustomizeWalletModel) -> Void)? { get set }
}

protocol CustomizeWalletViewModel: AnyObject {
  var didUpdateModel: ((CustomizeWalletView.Model) -> Void)? { get set }
  var didSelectEmoji: ((EmojisDataSource.Emoji) -> Void)? { get set }
  var didSelectColor: ((UIColor) -> Void)? { get set }
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func setWalletName(_ name: String)
}

final class CustomizeWalletViewModelImplementation: CustomizeWalletViewModel, CustomizeWalletModuleOutput {
  
  // MARK: - CustomizeWalletModuleOutput
  
  var didCustomizeWallet: ((CustomizeWalletModel) -> Void)?
  
  // MARK: - CustomizeWalletViewModel
  
  var didUpdateModel: ((CustomizeWalletView.Model) -> Void)?
  var didSelectEmoji: ((EmojisDataSource.Emoji) -> Void)?
  var didSelectColor: ((UIColor) -> Void)?
  var didUpdateContinueButtonIsEnabled: ((Bool) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel(emojiPickerItems: []))
    didUpdateContinueButtonIsEnabled?(true)
    Task {
      let items = await createEmojiPickerItems()
      guard !items.isEmpty else { return }
      await MainActor.run {
        didSelectEmoji?(items.first(where: { $0.emoji.emoji == self.emoji })?.emoji ?? items[0].emoji)
        didUpdateModel?(createModel(emojiPickerItems: items))
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
  
  // MARK: - Data Source
  
  private var emojiDataSource = EmojisDataSource()
  
  // MARK: - State
  
//  private lazy var walletName: String = wallet?.metaData.label ?? .defaultWalletName
//  private lazy var selectedTintColor: WalletTintColor = wallet?.metaData.tintColor ?? .defaultColor
//  private lazy var selectedEmoji: String = wallet?.metaData.emoji ?? .defaultEmoji
  
  
  // MARK: - Dependencies
  
//  private let wallet: Wallet?
  private var name: String
  private var tintColor: WalletTintColor
  private var emoji: String
  private let configurator: CustomizeWalletViewModelConfigurator
  
  
  init(name: String? = nil,
       tintColor: WalletTintColor? = nil,
       emoji: String? = nil,
       configurator: CustomizeWalletViewModelConfigurator) {
    self.name = name ?? .defaultWalletName
    self.tintColor = tintColor ?? .defaultColor
    self.emoji = emoji ?? .defaultEmoji
    self.configurator = configurator
    
    configurator.didCustomizeWallet = { [weak self] in
      self?.didFinishCustomization()
    }
  }
}

private extension CustomizeWalletViewModelImplementation {
  func createModel(emojiPickerItems: [WalletEmojiPickerView.Model.Item]) -> CustomizeWalletView.Model {
    let titleDescriptionModel = TKTitleDescriptionView.Model(
      title: "Customize your Wallet",
      bottomDescription: "Wallet name and icon are stored locally on your device."
    )
    
    let walletNameTextFieldPlaceholder = "Wallet Name"
    
    let colorPickerModel = createColorPickerModel()
    let emojiPicketModel = WalletEmojiPickerView.Model(items: emojiPickerItems)
    
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
      emojiPicketModel: emojiPicketModel
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
  
  func createEmojiPickerItems() async -> [WalletEmojiPickerView.Model.Item] {
    let emojis = await emojiDataSource.loadData()
    guard !emojis.isEmpty else { return [] }
    let items = emojis.map { emoji in
      WalletEmojiPickerView.Model.Item(
        emoji: emoji,
        selectHandler: { [weak self] in
          self?.emoji = emoji.emoji
          self?.didSelectEmoji?(emoji)
          self?.configurator.didSelectColor()
        }
      )
    }
    return items
  }
  
  func didFinishCustomization() {
    let model = CustomizeWalletModel(
      name: name,
      tintColor: tintColor,
      emoji: emoji
    )
    didCustomizeWallet?(model)
  }
}

private extension Int {
  static let colorsCount = 26
}

private extension String {
  static let defaultWalletName = "Wallet"
  static let defaultEmoji = "😀"
}
