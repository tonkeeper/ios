import Foundation
import TKUIKit
import UIKit
import TKLocalize

protocol AddWalletOptionPickerModuleOutput: AnyObject {
  var didSelectOption: ((AddWalletOption) -> Void)? { get set }
}

protocol AddWalletOptionPickerViewModel: AnyObject {
  var didUpdateHeaderViewModel: ((TKTitleDescriptionView.Model) -> Void)? { get set }
  var didUpdateOptionsSections: (([AddWalletOptionPickerSection]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectItem(_ item: AddWalletOptionPickerItem)
}

final class AddWalletOptionPickerViewModelImplementation: AddWalletOptionPickerViewModel, AddWalletOptionPickerModuleOutput {
  
  // MARK: - AddWalletOptionPickerModuleOutput
  
  var didSelectOption: ((AddWalletOption) -> Void)?
  
  // MARK: - AddWalletOptionPickerViewModel
  
  var didUpdateHeaderViewModel: ((TKTitleDescriptionView.Model) -> Void)?
  var didUpdateOptionsSections: (([AddWalletOptionPickerSection]) -> Void)?
  
  func viewDidLoad() {
    didUpdateHeaderViewModel?(createHeaderViewModel())
    didUpdateOptionsSections?(createOptionsSections())
  }
  
  func didSelectItem(_ item: AddWalletOptionPickerItem) {
    didSelectOption?(item.option)
  }

  private let options: [AddWalletOption]
  
  init(options: [AddWalletOption]) {
    self.options = options
  }
  
  private func createHeaderViewModel() -> TKTitleDescriptionView.Model {
    TKTitleDescriptionView.Model(
      title: TKLocales.AddWallet.title,
      bottomDescription: TKLocales.AddWallet.description
    )
  }
  
  private func createOptionsSections() -> [AddWalletOptionPickerSection] {
    return options.map { option in
      
      let cellConfiguration = TKListItemCell.Configuration(
        listItemContentViewConfiguration: TKListItemContentViewV2.Configuration(
          iconViewConfiguration: TKListItemIconViewV2.Configuration(
            content: .image(
              TKImageView.Model(
                image: .image(option.icon),
                tintColor: .Accent.blue
              )
            ),
            alignment: .center,
            size: CGSize(width: 28, height: 28)
          ),
          textContentViewConfiguration: TKListItemTextContentViewV2.Configuration(
            titleViewConfiguration: TKListItemTitleView.Configuration(
              title: option.title
            ),
            captionViewsConfigurations: [TKListItemTextView.Configuration(
              text: option.subtitle,
              color: .Text.secondary,
              textStyle: .body2,
              numberOfLines: 0
            )]
          )
        )
      )
      
      let item = AddWalletOptionPickerItem(
        option: option,
        cellConfiguration: cellConfiguration
      )
      
      return AddWalletOptionPickerSection(item: item)
    }
  }
}
