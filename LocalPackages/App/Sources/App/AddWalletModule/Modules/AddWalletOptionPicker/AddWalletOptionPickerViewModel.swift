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
  case signer
  case ledger
  
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
    case .signer:
      return TKLocales.AddWallet.Items.PairSigner.title
    case .ledger:
      return TKLocales.AddWallet.Items.PairLedger.title
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
    case .signer:
      return TKLocales.AddWallet.Items.PairSigner.subtitle
    case .ledger:
      return TKLocales.AddWallet.Items.PairLedger.subtitle
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
    case .signer:
      return .TKUIKit.Icons.Size28.signer
    case .ledger:
      return .TKUIKit.Icons.Size28.ledger
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
      item.selectionClosure?()
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
      let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
        title: option.title.withTextStyle(
          .label1,
          color: .Text.primary,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        ),
        tagViewModel: nil,
        subtitle: nil,
        description: option.subtitle.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
      )
      
      let contentConfiguration = TKUIListItemContentView.Configuration(
        leftItemConfiguration: leftItemConfiguration,
        rightItemConfiguration: nil
      )
      
      let listItemConfiguration = TKUIListItemView.Configuration(
        iconConfiguration: TKUIListItemIconView.Configuration(
          iconConfiguration: .image(
            TKUIListItemImageIconView.Configuration(
              image: .image(option.icon),
              tintColor: .Accent.blue,
              backgroundColor: .clear,
              size: CGSize(width: 28, height: 28),
              cornerRadius: .zero
            )
          ),
          alignment: .center
        ),
        contentConfiguration: contentConfiguration,
        accessoryConfiguration: .image(
          .init(
            image: .TKUIKit.Icons.Size16.chevronRight,
            tintColor: .Text.tertiary,
            padding: .zero
          )
        )
      )
      
      let item = TKUIListItemCell.Configuration(
        id: option.rawValue,
        listItemConfiguration: listItemConfiguration,
        isHighlightable: true,
        selectionClosure: { [weak self] in
          self?.didSelectOption?(option)
        }
      )
      
      return AddWalletOptionPickerSection.options(item: item)
    }
  }
}
