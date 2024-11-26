import UIKit
import TKUIKit
import TKCore
import TKLocalize
import KeeperCore

protocol SettingsPurchasesViewModel: AnyObject {
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  var didUpdateSnapshot: ((SettingsPurchasesViewController.Snapshot) -> Void)? { get set }
  var didOpenDetails: ((PurchasesManagementDetailsViewController.Configuration) -> Void)? { get set }
  var didHideDetails: (() -> Void)? { get set }
  var didCopyItem: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
  func getItemCellModel(identifier: String) -> SettingsPurchasesItemCell.Model?
  func sectionFooterModel(section: SettingsPurchasesViewController.Section) -> SettingsPurchasesSectionButtonView.Model?
  func didTapItem(identifier: String)
}

final class SettingsPurchasesViewModelImplementation: SettingsPurchasesViewModel {
  private struct ItemData {
    let title: String
    let subtitle: String
    let imageURL: URL?
  }
  
  private enum SectionState {
    case collapsed
    case expanded
  }
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateSnapshot: ((SettingsPurchasesViewController.Snapshot) -> Void)?
  var didOpenDetails: ((PurchasesManagementDetailsViewController.Configuration) -> Void)?
  var didHideDetails: (() -> Void)?
  var didCopyItem: ((String?) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: TKLocales.Collectibles.title))

    model.didUpdate = { [weak self] event in
      DispatchQueue.main.async {
        switch event {
        case .didUpdateItems(let state):
          self?.state = state
        case .didUpdateManagementState(let state):
          self?.state = state
        }
      }
    }
    let state = model.state
    self.state = state
  }
  
  func getItemCellModel(identifier: String) -> SettingsPurchasesItemCell.Model? {
    itemCellModels[identifier]
  }
  
  func sectionFooterModel(section: SettingsPurchasesViewController.Section) -> SettingsPurchasesSectionButtonView.Model? {
    footerModels[section]
  }
  
  func didTapItem(identifier: String) {
    itemCellModels[identifier]?.tapHandler?()
  }
  
  private var state: SettingsPurchasesModel.State? {
    didSet {
      guard let state else { return }
      didUpdateState(state)
    }
  }
  
  private var itemCellModels = [String: SettingsPurchasesItemCell.Model]()
  private var footerModels = [SettingsPurchasesViewController.Section: SettingsPurchasesSectionButtonView.Model]()
  private var sectionStates = [SettingsPurchasesViewController.Section: SectionState]()
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  private let model: SettingsPurchasesModel
  
  init(model: SettingsPurchasesModel) {
    self.model = model
  }
}

private extension SettingsPurchasesViewModelImplementation {
  func didUpdateState(_ state: SettingsPurchasesModel.State) {
    handleState(state)
  }
  
  func handleState(_ state: SettingsPurchasesModel.State) {
    var cellModels = [String: SettingsPurchasesItemCell.Model]()
    var footerModels = [SettingsPurchasesViewController.Section: SettingsPurchasesSectionButtonView.Model]()
   
    state.visible.forEach { visibleItem in
      let itemData = createItemData(item: visibleItem, collectionNfts: state.collectionNfts)
      let model = mapRegularItem(
        title: itemData.title,
        subtitle: itemData.subtitle,
        imageURL: itemData.imageURL,
        controlModel: SettingsPurchasesItemControl.Model(
          action: .minus,
          tapClosure: { [model] in
            model.hideItem(visibleItem)
          }
        ),
        tapHandler: {
          [weak self] in
          guard let self else { return }
          let configuration = createDetailsConfiguration(item: visibleItem, 
                                                         collectionNfts: state.collectionNfts,
                                                         itemState: .visible)
          didOpenDetails?(configuration)
        }
      )
      cellModels[visibleItem.id] = model
    }
    footerModels[.visible] = createFooterModelIfNeeded(items: state.visible, section: .visible)
    
    state.hidden.forEach { hiddenItem in
      let itemData = createItemData(item: hiddenItem, collectionNfts: state.collectionNfts)
      let model = mapRegularItem(
        title: itemData.title,
        subtitle: itemData.subtitle,
        imageURL: itemData.imageURL,
        controlModel: SettingsPurchasesItemControl.Model(
          action: .plus,
          tapClosure: { [model] in
            model.showItem(hiddenItem)
          }
        ),
        tapHandler: {
          [weak self] in
          guard let self else { return }
          let configuration = createDetailsConfiguration(item: hiddenItem,
                                                         collectionNfts: state.collectionNfts,
                                                         itemState: .hidden)
          didOpenDetails?(configuration)
        }
      )
      cellModels[hiddenItem.id] = model
    }
    footerModels[.hidden] = createFooterModelIfNeeded(items: state.hidden, section: .hidden)
    
    state.spam.forEach { visibleItem in
      let itemData = createItemData(item: visibleItem, collectionNfts: state.collectionNfts)
      let model = mapRegularItem(
        title: itemData.title,
        subtitle: itemData.subtitle,
        imageURL: itemData.imageURL,
        controlModel: nil,
        accessoryConfiguration: .chevron,
        tapHandler: {
          [weak self] in
          guard let self else { return }
          let configuration = createDetailsConfiguration(item: visibleItem,
                                                         collectionNfts: state.collectionNfts,
                                                         itemState: .spam)
          didOpenDetails?(configuration)
        }
      )
      cellModels[visibleItem.id] = model
    }
    footerModels[.spam] = createFooterModelIfNeeded(items: state.spam, section: .spam)
    
    let snapshot = createSnapshot(state)

    self.itemCellModels = cellModels
    self.footerModels = footerModels
    self.didUpdateSnapshot?(snapshot)
  }
  
  func createSnapshot(_ state: SettingsPurchasesModel.State) -> SettingsPurchasesViewController.Snapshot {
    var snapshot = SettingsPurchasesViewController.Snapshot()
    
    if !state.visible.isEmpty {
      snapshot.appendSections([.visible])
      snapshot.appendItems(
        createSnapshotItems(items: state.visible,
                            section: .visible),
        toSection: .visible)
    }
    
    if !state.hidden.isEmpty {
      snapshot.appendSections([.hidden])
      snapshot.appendItems(
        createSnapshotItems(items: state.hidden,
                            section: .hidden),
        toSection: .hidden)
    }
    
    if !state.spam.isEmpty {
      snapshot.appendSections([.spam])
      snapshot.appendItems(
        createSnapshotItems(items: state.spam,
                            section: .spam),
        toSection: .spam)
    }
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    return snapshot
  }
  
  func createSnapshotItems(items: [SettingsPurchasesModel.Item],
                           section: SettingsPurchasesViewController.Section) -> [String] {
    let items = items.count > 4
    ? sectionStates[section] == .expanded ? items : Array(items.prefix(4))
    : items
    return items.map {
      $0.id
    }
  }
  
  func createFooterModelIfNeeded(items: [SettingsPurchasesModel.Item],
                                 section: SettingsPurchasesViewController.Section) -> SettingsPurchasesSectionButtonView.Model? {
    guard items.count > 4 && sectionStates[section] != .expanded else {
      return nil
    }
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .small)
    buttonConfiguration.action = { [weak self] in
      self?.sectionStates[section] = .expanded
      self?.state = self?.model.state
    }
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.List.showAll))
    let model = SettingsPurchasesSectionButtonView.Model(buttonConfiguration: buttonConfiguration)
    return model
  }
  
  private enum ItemState {
    case visible
    case hidden
    case spam
  }
  
  private func createDetailsConfiguration(item: SettingsPurchasesModel.Item,
                                          collectionNfts:  [NFTCollection: [NFT]],
                                          itemState: ItemState) -> PurchasesManagementDetailsViewController.Configuration {
    let title: String
    let buttonTitle: String
    let listItems: [SettingsPurchasesDetailsListItemView.Model]
    
    switch item {
    case .single(let nft):
      title = TKLocales.Settings.Purchases.Details.Title.singleToken
      buttonTitle = {
        switch itemState {
        case .visible:
          TKLocales.Settings.Purchases.Details.Button.hideToken
        case .hidden:
          TKLocales.Settings.Purchases.Details.Button.showToken
        case .spam:
          if model.isMarkedAsSpam(item: item) {
            TKLocales.Settings.Purchases.Details.Button.notSpam
          } else {
            TKLocales.Settings.Purchases.Details.Button.showToken
          }
        }
      }()
      listItems = [
        SettingsPurchasesDetailsListItemView.Model(
          title: TKLocales.Settings.Purchases.Details.Items.tokenId,
          caption: nft.address.toShortString(bounceable: true),
          image: TKImageView.Model(
            image: .image(.TKUIKit.Icons.Size16.copy),
            tintColor: .Icon.secondary,
            size: .auto,
            corners: .none,
            padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 4)
          ),
          isHighlightable: true,
          copyValue: nft.address.toString(bounceable: true)
        )
      ]
    case .collection(let collection):
      title = TKLocales.Settings.Purchases.Details.Title.collection
      buttonTitle = {
        switch itemState {
        case .visible:
          TKLocales.Settings.Purchases.Details.Button.hideCollection
        case .hidden:
          TKLocales.Settings.Purchases.Details.Button.showCollection
        case .spam:
          if model.isMarkedAsSpam(item: item) {
            TKLocales.Settings.Purchases.Details.Button.notSpam
          } else {
            TKLocales.Settings.Purchases.Details.Button.showCollection
          }
        }
      }()
      listItems = [
        SettingsPurchasesDetailsListItemView.Model(
          title: TKLocales.Settings.Purchases.Details.Items.name,
          caption: collection.notEmptyName,
          image: TKImageView.Model(
            image: .urlImage(collectionNfts[collection]?.first?.preview.size500),
            size: .size(CGSize(width: 40, height: 40)),
            corners: .cornerRadius(cornerRadius: 8)
          ),
          isHighlightable: false,
          copyValue: nil
        ),
        SettingsPurchasesDetailsListItemView.Model(
          title: TKLocales.Settings.Purchases.Details.Items.collectionId,
          caption: collection.address.toShortString(bounceable: true),
          image: TKImageView.Model(
            image: .image(.TKUIKit.Icons.Size16.copy),
            tintColor: .Icon.secondary,
            size: .auto,
            corners: .none,
            padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 4)
          ),
          isHighlightable: true,
          copyValue: collection.address.toString(bounceable: true)
        )
      ]
    }
    
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    buttonConfiguration.content.title = .plainString(buttonTitle)
    buttonConfiguration.action = { [weak self] in
      switch itemState {
      case .visible:
        self?.model.hideItem(item)
      case .hidden, .spam:
        self?.model.showItem(item)
      }
      self?.didHideDetails?()
    }
    
    return PurchasesManagementDetailsViewController.Configuration(
      title: title,
      listConfiguration: TKListContainerView.Configuration(
        items: listItems,
        copyToastConfiguration: .copied
      ),
      buttonConfiguration: buttonConfiguration
    )
  }
  
  func mapRegularItem(title: String,
                      subtitle: String,
                      imageURL: URL?,
                      controlModel: SettingsPurchasesItemControl.Model?,
                      accessoryConfiguration: TKUIListItemAccessoryView.Configuration = .none,
                      tapHandler: (() -> Void)?) -> SettingsPurchasesItemCell.Model {
    
    let listModel = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: .asyncImage(
              imageURL,
              TKCore.ImageDownloadTask(
                closure: {
                  [imageLoader] imageView,
                  size,
                  cornerRadius in
                  return imageLoader.loadImage(
                    url: imageURL,
                    imageView: imageView,
                    size: size,
                    cornerRadius: cornerRadius
                  )
                }
              )
            ),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 8
          )
        ),
        alignment: .center
      ),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          tagViewModel: nil,
          subtitle: subtitle.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          description: nil
        ),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: accessoryConfiguration
    )
    
    return SettingsPurchasesItemCell.Model(
      controlModel: controlModel,
      listModel: listModel,
      tapHandler: tapHandler
    )
  }
  
  private func createItemData(item: SettingsPurchasesModel.Item, collectionNfts:  [NFTCollection: [NFT]]) -> ItemData {
    let title: String
    let subtitle: String
    let imageURL: URL?
    switch item {
    case .collection(let collection):
      title = collection.notEmptyName ?? TKLocales.Settings.Purchases.Token.unnamedCollection
      let nftsCount = collectionNfts[collection]?.count ?? 0
      subtitle = "\(nftsCount) \(TKLocales.Settings.Purchases.Token.tokenCount(count: nftsCount))"
      imageURL = collectionNfts[collection]?.first?.preview.size500
    case .single(let nft):
      title = nft.name ?? nft.address.toShortString(bounceable: true)
      subtitle = TKLocales.Settings.Purchases.Token.singleToken
      imageURL = nft.preview.size500
    }
    return ItemData(
      title: title,
      subtitle: subtitle,
      imageURL: imageURL
    )
  }
}
