import Foundation
import TKUIKit
import UIKit
import TKLocalize

protocol AddWalletOptionPickerModuleOutput: AnyObject {
  var didSelectOption: ((AddWalletOption) -> Void)? { get set }
}

protocol AddWalletOptionPickerViewModel: AnyObject {
  var didUpdateModel: ((AddWalletModel) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectOption(in section: AddWalletOptionPickerSection)
}

struct AddWalletModel {
  let titleDescriptionModel: TKTitleDescriptionView.Model
  let optionSections: [AddWalletOptionPickerSection]
}

enum AddWalletOption: String {
  case createRegular
  case importRegular
  case importWatchOnly
  case importTestnet
  
  var title: String {
    switch self {
    case .createRegular:
      return TKLocales.AddWallet.Items.NewWallet.title
    case .importRegular:
      return TKLocales.AddWallet.Items.ExistingWallet.title
    case .importWatchOnly:
      return TKLocales.AddWallet.Items.WatchOnly.title
    case .importTestnet:
      return TKLocales.AddWallet.Items.Testnet.title
    }
  }
  
  var subtitle: String {
    switch self {
    case .createRegular:
      return TKLocales.AddWallet.Items.NewWallet.subtitle
    case .importRegular:
      return TKLocales.AddWallet.Items.ExistingWallet.subtitle
    case .importWatchOnly:
      return TKLocales.AddWallet.Items.WatchOnly.subtitle
    case .importTestnet:
      return TKLocales.AddWallet.Items.Testnet.subtitle
    }
  }
  
  var icon: UIImage {
    switch self {
    case .createRegular:
      return .TKUIKit.Icons.Size28.plusCircle
    case .importRegular:
      return .TKUIKit.Icons.Size28.key
    case .importWatchOnly:
      return .TKUIKit.Icons.Size28.magnifyingGlass
    case .importTestnet:
      return .TKUIKit.Icons.Size28.testnet
    }
  }
}

final class AddWalletOptionPickerViewModelImplementation: AddWalletOptionPickerViewModel, AddWalletOptionPickerModuleOutput {
  
  // MARK: - AddWalletOptionPickerModuleOutput
  
  var didSelectOption: ((AddWalletOption) -> Void)?
  
  // MARK: - AddWalletOptionPickerViewModel
  
  var didUpdateModel: ((AddWalletModel) -> Void)?
  
  func viewDidLoad() {
    didUpdateModel?(createModel())
  }
  
  func didSelectOption(in section: AddWalletOptionPickerSection) {
    switch section {
    case .options(let item):
      item.selectionHandler?()
    }
  }
  
  private let options: [AddWalletOption]
  
  init(options: [AddWalletOption]) {
    self.options = options
  }
}

private extension AddWalletOptionPickerViewModelImplementation {
  func createModel() -> AddWalletModel {
    let sections = createOptionItemSections()
    
    return AddWalletModel(
      titleDescriptionModel: createTitleDescriptionModel(),
      optionSections: sections
    )
  }
  
  func createTitleDescriptionModel() -> TKTitleDescriptionView.Model {
    TKTitleDescriptionView.Model(
      title: TKLocales.AddWallet.title,
      bottomDescription: TKLocales.AddWallet.description
    )
  }
  
  func createOptionItemSections() -> [AddWalletOptionPickerSection] {
    return options.map { option in
      
      let cellContentModel = AddWalletOptionPickerCellContentView.Model(
        iconModel: .init(image: .image(option.icon), tintColor: .Accent.blue, backgroundColor: .clear, size: CGSize(width: 28, height: 28)),
        title: option.title,
        description: option.subtitle
      )
      
      let model = AddWalletOptionPickerCell.Model(
        identifier: option.rawValue,
        accessoryType: .disclosureIndicator,
        selectionHandler: { [weak self] in
          self?.didSelectOption?(option)
        },
        cellContentModel: cellContentModel
      )
      return AddWalletOptionPickerSection.options(item: model)
    }
  }
}
