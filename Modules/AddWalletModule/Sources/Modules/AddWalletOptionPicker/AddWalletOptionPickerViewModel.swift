import Foundation
import TKUIKit
import UIKit

protocol AddWalletOptionPickerModuleOutput: AnyObject {
  var didSelectOption: ((AddWalletOption) -> Void)? { get set }
}

protocol AddWalletOptionPickerViewModel: AnyObject {
  var didUpdateModel: ((AddWalletModel) -> Void)? { get set }
  
  func viewDidLoad()
}

struct AddWalletModel {
  let titleDescriptionModel: TKTitleDescriptionView.Model
  let listSections: [TKCollectionSection]
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
  
  private let options: [AddWalletOption]
  
  init(options: [AddWalletOption]) {
    self.options = options
  }
}

private extension AddWalletOptionPickerViewModelImplementation {
  func createModel() -> AddWalletModel {
    return AddWalletModel(
      titleDescriptionModel: createTitleDescriptionModel(),
      listSections: createListSections()
    )
  }
  
  func createTitleDescriptionModel() -> TKTitleDescriptionView.Model {
    TKTitleDescriptionView.Model(
      title: "Add Wallet",
      bottomDescription: "Create a new wallet or add an existing one."
    )
  }
  
  func createListSections() -> [TKCollectionSection] {
    let sections = options.map { option in
      let listItemModel = TKListItemView.Model(
        iconModel: TKListItemIconView.Model(
          type: .image(
            model: TKListItemIconImageContentView.Model(
              image: option.icon,
              tintColor: .Accent.blue,
              backgroundColor: .clear
            )
          ),
          alignment: .center),
        textContentModel: TKListItemTextContentView.Model(
          textWithTagModel: TKTextWithTagView.Model(title: option.title),
          attributedSubtitle: nil,
          description: option.subtitle)
      )
      let cell = TKCollectionItemIdentifier(
        identifier: option.rawValue,
        isSelectable: false,
        isReorderable: false,
        accessoryViewType: .disclosureIndicator,
        model: listItemModel,
        tapClosure: { [weak self] in
          self?.didSelectOption?(option)
        }
      )
      
      return TKCollectionSection.list(items: [cell])
    }
    return sections
  }
}
