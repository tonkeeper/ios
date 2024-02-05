import Foundation
import TKUIKit
import UIKit

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
  case importTestnet
  
  var title: String {
    switch self {
    case .createRegular:
      return "New Wallet"
    case .importRegular:
      return "Existing Wallet"
    case .importTestnet:
      return "Testnet Account"
    }
  }
  
  var subtitle: String {
    switch self {
    case .createRegular:
      return "Create new wallet"
    case .importRegular:
      return "Import wallet with a 24 secret recovery words"
    case .importTestnet:
      return "Import wallet with a 24 secret recovery words to Testnet"
    }
  }
  
  var icon: UIImage {
    switch self {
    case .createRegular:
      return .TKUIKit.Icons.Size28.plusCircle
    case .importRegular:
      return .TKUIKit.Icons.Size28.key
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
      title: "Add Wallet",
      bottomDescription: "Create a new wallet or add an existing one."
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
        selectionHandler: { [weak self] in
          self?.didSelectOption?(option)
        },
        cellContentModel: cellContentModel
      )
      return AddWalletOptionPickerSection.options(item: model)
    }
  }
}
