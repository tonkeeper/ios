import UIKit
import TKUIKit
import TKCore
import KeeperCore

protocol BuyListModuleOutput: AnyObject {
  var didSelectItem: ((URL) -> Void)? { get set }
}

protocol BuyListViewModel: AnyObject {
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BuyListSection, AnyHashable>) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BuyListViewModelImplementation: BuyListViewModel, BuyListModuleOutput {
  
  // MARK: - BuyListModuleOutput
  
  var didSelectItem: ((URL) -> Void)?
  
  // MARK: - BuyListViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BuyListSection, AnyHashable>) -> Void)?
  
  func viewDidLoad() {
    Task {
      buyListController.didUpdateMethods = { [weak self] methods in
        self?.didUpdateMethods(methods)
      }
      await buyListController.start()
    }
  }
  
  // MARK: - State
  
  private var snapshot = NSDiffableDataSourceSnapshot<BuyListSection, AnyHashable>()
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let buyListController: BuyListController
  
//  private let fiatMethodsController: FiatMethodsController
//  private let buyListServiceBuilder: BuyListServiceBuilder
//  private let appSettings = AppSettings()
  
  init(buyListController: BuyListController) {
    self.buyListController = buyListController
  }
}

private extension BuyListViewModelImplementation {
  
  func didUpdateMethods(_ methods: [[BuyListController.BuySellItem]]) {
    Task { @MainActor in
      let sections = methods.map { section in
        section.map { mapBuySellItem($0) }
      }
      snapshot.deleteAllItems()
      sections.forEach {
        snapshot.appendSections([.items($0)])
        snapshot.appendItems($0)
      }
      didUpdateSnapshot?(snapshot)
    }
  }
  
  func mapBuySellItem(_ item: BuyListController.BuySellItem) -> TKUIListItemCell.Configuration {
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image = .asyncImage(item.iconURL, TKCore.ImageDownloadTask(
      closure: {
        [imageLoader] imageView,
        size,
        cornerRadius in
        return imageLoader.loadImage(
          url: item.iconURL,
          imageView: imageView,
          size: size,
          cornerRadius: cornerRadius
        )
      }
    ))
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        .init(
          image: iconConfigurationImage,
          tintColor: .clear,
          backgroundColor: .clear,
          size: CGSize(width: 44, height: 44),
          cornerRadius: 12
        )
      ),
      alignment: .center
    )
    
    let title = item.title.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    let description = item.description?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: nil,
      description: description,
      descriptionNumberOfLines: 0
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: leftItemConfiguration,
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .image(
        .init(
          image: .TKUIKit.Icons.Size16.chevronRight,
          tintColor: .Text.tertiary,
          padding: .zero
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: item.id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: { [weak self] in
        guard let url = item.actionURL else { return }
        self?.didSelectItem?(url)
      }
    )
  }
}
