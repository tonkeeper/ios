import UIKit
import TKUIKit
import TKCore
import KeeperCore

public struct CustomizeWalletModel {
  public let name: String
  public let colorIdentifier: String
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
        didSelectEmoji?(items.first(where: { $0.emoji.emoji == selectedEmoji })?.emoji ?? items[0].emoji)
        didUpdateModel?(createModel(emojiPickerItems: items))
        didSelectColor?(.Tint.color(with: selectedColorIdentifier))
      }
    }
  }
  
  func setWalletName(_ name: String) {
    let isNameValid = !name.isEmpty
    walletName = isNameValid ? name : .defaultWalletName
    didUpdateContinueButtonIsEnabled?(isNameValid)
    configurator.didEditName()
  }
  
  // MARK: - Data Source
  
  private var emojiDataSource = EmojisDataSource()
  
  // MARK: - State
  
  private lazy var walletName: String = wallet?.metaData.label ?? .defaultWalletName
  private lazy var selectedColorIdentifier: String = wallet?.metaData.colorIdentifier ?? .defaultColorIdentifier
  private lazy var selectedEmoji: String = wallet?.metaData.emoji ?? .defaultEmoji
  
  // MARK: - Dependencies
  
  private let wallet: Wallet?
  private let configurator: CustomizeWalletViewModelConfigurator
  
  init(wallet: Wallet? = nil,
       configurator: CustomizeWalletViewModelConfigurator) {
    self.wallet = wallet
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
    
    let continueButton: CustomizeWalletView.Model.ContinueButton?
    switch configurator.continueButtonMode {
    case .hidden:
      continueButton = nil
    case .visible(let title, let action):
      continueButton = CustomizeWalletView.Model.ContinueButton(
        model: TKUIActionButton.Model(title: title),
        action: action
      )
    }
    
    return CustomizeWalletView.Model(
      titleDescriptionModel: titleDescriptionModel,
      walletNameTextFieldPlaceholder: walletNameTextFieldPlaceholder,
      walletNameDefaultValue: walletName,
      colorPickerModel: colorPickerModel,
      emojiPicketModel: emojiPicketModel,
      continueButtonModel: continueButton
      )
  }
  
  func createColorPickerModel() -> WalletColorPickerView.Model {
    let items = (1...Int.colorsCount)
      .map {
        let identifier = "Color\($0)"
        let selectHandler: () -> Void = { [weak self] in
          self?.didSelectColor?(.Tint.color(with: identifier))
          self?.selectedColorIdentifier = identifier
          self?.configurator.didSelectColor()
        }
        return WalletColorPickerView.Model.ColorItem(
          identifier: identifier, 
          selectHandler: selectHandler
        )
      }
    
    return WalletColorPickerView.Model(
      items: items,
      initialSelectedIdentifier: selectedColorIdentifier
    )
  }
  
  func createEmojiPickerItems() async -> [WalletEmojiPickerView.Model.Item] {
    let emojis = await emojiDataSource.loadData()
    guard !emojis.isEmpty else { return [] }
    let items = emojis.map { emoji in
      WalletEmojiPickerView.Model.Item(
        emoji: emoji,
        selectHandler: { [weak self] in
          self?.selectedEmoji = emoji.emoji
          self?.didSelectEmoji?(emoji)
          self?.configurator.didSelectColor()
        }
      )
    }
    return items
  }
  
  func didFinishCustomization() {
    let model = CustomizeWalletModel(
      name: walletName,
      colorIdentifier: selectedColorIdentifier,
      emoji: selectedEmoji
    )
    didCustomizeWallet?(model)
  }
}

private extension Int {
  static let colorsCount = 26
}

private extension String {
  static let defaultWalletName = "Wallet"
  static let defaultColorIdentifier = "Color1"
  static let defaultEmoji = "😀"
}
