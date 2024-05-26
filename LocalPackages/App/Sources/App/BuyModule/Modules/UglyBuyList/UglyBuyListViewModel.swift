import UIKit
import TKUIKit
import TKCore
import KeeperCore

protocol UglyBuyListModuleOutput: AnyObject {
  var didSelectURL: ((URL) -> Void)? { get set }
}

protocol UglyBuyListViewModel: AnyObject {
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<UglyBuyListSection, AnyHashable>) -> Void)? { get set }
  
  func viewDidLoad()
}

final class UglyBuyListViewModelImplementation: UglyBuyListViewModel, UglyBuyListModuleOutput {
  
  // MARK: - UglyBuyListModuleOutput
  
  var didSelectURL: ((URL) -> Void)?
  var didSelectItem: ((BuySellItemModel) -> Void)?
  
  // MARK: - UglyBuyListViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<UglyBuyListSection, AnyHashable>) -> Void)?
  
  func viewDidLoad() {
    Task {
      buyListController.didUpdateMethods = { [weak self] methods in
        self?.didUpdateMethods(methods)
      }
      await buyListController.start()
    }
  }
  
  // MARK: - State
  
  private var snapshot = NSDiffableDataSourceSnapshot<UglyBuyListSection, AnyHashable>()
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let buyListController: BuyListController
  private let appSettings: AppSettings

  init(buyListController: BuyListController,
       appSettings: AppSettings) {
    self.buyListController = buyListController
    self.appSettings = appSettings
  }
}

private extension UglyBuyListViewModelImplementation {
  
  func didUpdateMethods(_ methods: [[BuySellItemModel]]) {
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
  
  func mapBuySellItem(_ item: BuySellItemModel) -> TKUIListItemCell.Configuration {
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
      .uglyTitle,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let description = item.actionURL?.host?.withTextStyle(
      .uglyLink,
      color: .Accent.blue,
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
          image: .TKUIKit.Icons.Size28.linkOutline,
          tintColor: .Accent.blue,
          padding: .zero
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: item.id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: { [weak self] in
        guard let self,
              let url = item.actionURL else { return }
        
        self.didSelectURL?(url)
      }
    )
  }
}

private extension TKTextStyle {
  static var uglyTitle: TKTextStyle {
    TKTextStyle(
      font: .systemFont(
        ofSize: 16,
        weight: .medium
      ),
      lineHeight: 24
    )
  }
  static var uglyLink: TKTextStyle {
    TKTextStyle(
      font: .systemFont(ofSize: 14, weight: .regular),
      lineHeight: 20,
      underline: true
    )
  }
}
