import Foundation
import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

protocol HistoryEventDetailsModuleOutput: AnyObject {
  
}

protocol HistoryEventDetailsViewModel: AnyObject {
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

final class HistoryEventDetailsViewModelImplementation: HistoryEventDetailsViewModel, HistoryEventDetailsModuleOutput {
  
  // MARK: - HistoryEventDetailsModuleOutput
  
  // MARK: - HistoryEventDetailsViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    configureDetails()
  }
  
  // MARK: - Dependencies
  
  private let historyEventDetailsController: HistoryEventDetailsController
  private let urlOpener: URLOpener
  
  // MARK: - Init
  
  init(historyEventDetailsController: HistoryEventDetailsController,
       urlOpener: URLOpener) {
    self.historyEventDetailsController = historyEventDetailsController
    self.urlOpener = urlOpener
  }
}

private extension HistoryEventDetailsViewModelImplementation {
  func configureDetails() {
    Task {
      let model = await self.historyEventDetailsController.model
      await MainActor.run {
        var headerItems = [TKModalCardViewController.Configuration.Item]()

        headerItems.append(contentsOf: composeHeaderImageItems(with: model))

        if let nftName = model.nftName {
          headerItems.append(
            .text(
              .init(
                text: nftName.withTextStyle(.h2, color: .Text.primary, alignment: .center, lineBreakMode: .byWordWrapping),
                numberOfLines: 1
              ),
              bottomSpacing: 0
            )
          )
          if let nftCollectionName = model.nftCollectionName {
            headerItems.append(
              .text(
                .init(text: nftCollectionName.withTextStyle(.body1, color: .Text.secondary, alignment: .center, lineBreakMode: .byWordWrapping), numberOfLines: 1),
                bottomSpacing: 0
              )
            )
          }
          headerItems.append(.customView(TKSpacingView(verticalSpacing: .constant(16)), bottomSpacing: 0))
        }
        
        if let aboveTitle = model.aboveTitle {
          headerItems.append(
            .text(.init(text: aboveTitle.withTextStyle(.h2, color: .Text.tertiary, alignment: .center, lineBreakMode: .byWordWrapping), numberOfLines: 1), bottomSpacing: 4)
          )
        }
        if let title = model.title {
          headerItems.append(.text(.init(text: title.withTextStyle(.h2, color: .Text.primary, alignment: .center, lineBreakMode: .byWordWrapping), numberOfLines: 1), bottomSpacing: 4))
        }
        if let fiatPrice = model.fiatPrice {
          headerItems.append(.text(.init(text: fiatPrice.withTextStyle(.body1, color: .Text.secondary, alignment: .center, lineBreakMode: .byWordWrapping), numberOfLines: 1), bottomSpacing: 4))
        }
        if let date = model.date {
          headerItems.append(.text(.init(text: date.withTextStyle(.body1, color: .Text.secondary, alignment: .center, lineBreakMode: .byWordWrapping), numberOfLines: 1), bottomSpacing: 0))
        }
        
        if let status = model.status {
          headerItems.append(.text(.init(text: status.withTextStyle(.body1, color: .Accent.orange, alignment: .center, lineBreakMode: .byWordWrapping), numberOfLines: 1), bottomSpacing: 0))
          headerItems.append(.customView(TKSpacingView(verticalSpacing: .constant(16)), bottomSpacing: 0))
        }
        
        let listItems = model.listItems.map {
          TKModalCardViewController.Configuration.ListItem.defaultItem(
            left: $0.title,
            rightTop: .value($0.topValue, numberOfLines: $0.topNumberOfLines, isFullString: $0.isTopValueFullString),
            rightBottom: .value($0.bottomValue, numberOfLines: 1, isFullString: false))
        }
        let list = TKModalCardViewController.Configuration.ContentItem.list(listItems)
        let buttonItem = TKModalCardViewController.Configuration.ContentItem.item(.customView(createOpenTransactionButtonContainerView(), bottomSpacing: 32))
        
        let configuration = TKModalCardViewController.Configuration(
          header: TKModalCardViewController.Configuration.Header(items: headerItems),
          content: TKModalCardViewController.Configuration.Content(items: [list, buttonItem]),
          actionBar: nil
        )
        didUpdateConfiguration?(configuration)
      }
    }
  }

  func composeHeaderImageItems(with model: HistoryEventDetailsController.Model) -> [TKModalCardViewController.Configuration.Item] {
    var headerItems = [TKModalCardViewController.Configuration.Item]()

    guard !model.isScam else {
      let view = HistoryEventDetailsScamView()
      let text = TKLocales.ActionTypes.spam.uppercased()
        .withTextStyle(.label2,
                       color: .Text.primary,
                       alignment: .center,
                       lineBreakMode: .byTruncatingTail)
      view.configure(model: HistoryEventDetailsScamView.Model(title: text))
      headerItems.append(.customView(view, bottomSpacing: 12))
      return headerItems
    }

    guard let headerImage = model.headerImage else {
      return []
    }

    switch headerImage {
    case .swap(let fromImage, let toImage):
      let view = HistoryEventDetailsSwapHeaderImageView()
      view.imageLoader = ImageLoader()
      view.configure(model: HistoryEventDetailsSwapHeaderImageView.Model(
        leftImage: .with(image: fromImage),
        rightImage: .with(image: toImage))
      )
      headerItems.append(TKModalCardViewController.Configuration.Item.customView(view, bottomSpacing: 20))
    case .image(let image):
      let view = HistoreEventDetailsTokenHeaderImageView()
      view.imageLoader = ImageLoader()
      view.configure(model: HistoreEventDetailsTokenHeaderImageView.Model(
        image: .with(image: image)
      ))
      headerItems.append(TKModalCardViewController.Configuration.Item.customView(view, bottomSpacing: 20))
    case .nft(let image):
      let view = HistoryEventDetailsNFTHeaderImageView()
      view.imageLoader = ImageLoader()
      view.configure(model: HistoryEventDetailsNFTHeaderImageView.Model(
        image: .with(image: .url(image)),
        size: CGSize(width: 96, height: 96)
      ))
      headerItems.append(TKModalCardViewController.Configuration.Item.customView(view, bottomSpacing: 20))
    }

    return headerItems
  }
}

private extension HistoryEventDetailsViewModelImplementation {
  func createOpenTransactionButtonContainerView() -> UIView {
    let buttonContainer = UIView()
    let button = HistoryEventOpenTransactionButton()

    buttonContainer.addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
      button.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
      button.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor)
    ])
    
    let model = HistoryEventOpenTransactionButton.Model(
      title: "\(TKLocales.EventDetails.transaction) ",
      transactionHash: historyEventDetailsController.transactionHash,
      image: .TKUIKit.Icons.Size16.globe
    )
    
    button.addAction(UIAction(handler: { [weak self] _ in
      guard let self = self else { return }
      self.urlOpener.open(url: self.historyEventDetailsController.transactionURL)
    }), for: .touchUpInside)
    
    button.configure(model: model)
    return buttonContainer
  }
}
