import Foundation
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore
import TonSwift
import BigInt

public protocol ChooseWalletToAddModuleOutput: AnyObject {
  var didSelectWallets: (([ActiveWalletModel]) -> Void)? { get set }
}

protocol ChooseWalletToAddViewModel: AnyObject {
  var didUpdateHeaderViewModel: ((TKTitleDescriptionView.Model) -> Void)? { get set }
  var didUpdateOptionsSections: (([ChooseWalletToAddSection]) -> Void)? { get set }
  var didUpdateModel: ((ChooseWalletToAddView.Model) -> Void)? { get set }
  
  var selectedItems: Set<ChooseWalletToAddItem> { get }
  
  func viewDidLoad()
  func didSelect(item: ChooseWalletToAddItem)
  func didDeselect(item: ChooseWalletToAddItem)
}

struct ChooseWalletToAddConfiguration {
  let showRevision: Bool
  let selectLastRevision: Bool
  
  init(showRevision: Bool, selectLastRevision: Bool) {
    self.showRevision = showRevision
    self.selectLastRevision = selectLastRevision
  }
}

final class ChooseWalletToAddViewModelImplementation: ChooseWalletToAddViewModel, ChooseWalletToAddModuleOutput {
  // MARK: - ChooseWalletToAddModuleOutput
  
  var didSelectWallets: (([ActiveWalletModel]) -> Void)?
  
  // MARK: - ChooseWalletToAddViewModel
  
  var didUpdateHeaderViewModel: ((TKTitleDescriptionView.Model) -> Void)?
  var didUpdateOptionsSections: (([ChooseWalletToAddSection]) -> Void)?
  var didUpdateModel: ((ChooseWalletToAddView.Model) -> Void)?
  
  var selectedItems = Set<ChooseWalletToAddItem>()

  func viewDidLoad() {
    didUpdateHeaderViewModel?(createHeaderViewModel())
    didUpdateOptionsSections?([createSection()])
    didUpdateModel?(createModel())
  }
  
  func didSelect(item: ChooseWalletToAddItem) {
    selectedItems.insert(item)
    didUpdateModel?(createModel())
  }
  
  func didDeselect(item: ChooseWalletToAddItem) {
    selectedItems.remove(item)
    didUpdateModel?(createModel())
  }
  
  private let activeWalletModels: [ActiveWalletModel]
  private let amountFormatter: AmountFormatter
  private let configuration: ChooseWalletToAddConfiguration
  
  init(activeWalletModels: [ActiveWalletModel],
       amountFormatter: AmountFormatter,
       configuration: ChooseWalletToAddConfiguration) {
    self.activeWalletModels = activeWalletModels
    self.amountFormatter = amountFormatter
    self.configuration = configuration
  }
  
  private func createHeaderViewModel() -> TKTitleDescriptionView.Model {
    TKTitleDescriptionView.Model(
      title: TKLocales.ChooseWallets.title,
      bottomDescription: TKLocales.ChooseWallets.description
    )
  }
  
  func createModel() -> ChooseWalletToAddView.Model {
      ChooseWalletToAddView.Model(
        continueButtonModel: TKUIActionButton.Model(title: TKLocales.Actions.continueAction),
        continueButtonAction: { [weak self] in
          guard let self = self else { return }
          let dictionary = activeWalletModels.reduce(into: [:]) { partialResult, model in
            partialResult[model.id] = model
          }
          let models = selectedItems
            .compactMap { dictionary[$0.identifier] }
            .sorted { lhs, rhs in lhs.revision > rhs.revision }
          self.didSelectWallets?(models)
        },
        isContinueButtonEnabled: !selectedItems.isEmpty
      )
    }
  
  private func createSection() -> ChooseWalletToAddSection {
    let items = activeWalletModels
      .sorted{ lhs, rhs in lhs.revision > rhs.revision }
      .map { createItem(walletModel: $0) }
    return ChooseWalletToAddSection(items: items)
  }
  
  private func createItem(walletModel: ActiveWalletModel) -> ChooseWalletToAddItem {
    let tonAmount = amountFormatter.formatAmount(
      BigUInt(
        integerLiteral: UInt64(walletModel.balance.tonBalance.amount)
      ),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      currency: .TON
    )
    
    let title = walletModel.address.toShortString(bounceable: false)
    var subtitle = !configuration.showRevision ? tonAmount : "\(walletModel.revision.rawValue) · \(tonAmount)"
    if !walletModel.balance.jettonsBalance.isEmpty || !walletModel.nfts.isEmpty {
      subtitle.append(", " + TKLocales.ChooseWallets.tokens)
    }
    if (walletModel.isAdded) {
      subtitle.append(" · " + TKLocales.ChooseWallets.alreadyAdded)
    }
    
    let isEnable = !walletModel.isAdded
    let isSelected: Bool = {
      guard isEnable else { return false }
      return !walletModel.balance.isEmpty || (walletModel.revision == .currentVersion && configuration.selectLastRevision)
    }()
    
    let cellConfiguration = TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [TKListItemTextView.Configuration(
            text: subtitle,
            color: .Text.secondary,
            textStyle: .body2
          )]
        )
      )
    )
    
    let item = ChooseWalletToAddItem(
      identifier: walletModel.address.toRaw(),
      isSelectionEnable: isEnable,
      cellConfiguration: cellConfiguration
    )
    
    if isSelected {
      selectedItems.insert(item)
    }
    
    return item
  }
}
