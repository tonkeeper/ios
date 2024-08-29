import UIKit
import TKUIKit
import KeeperCore

protocol NFTDetailsModuleOutput: AnyObject {
  var didClose: (() -> Void)? { get set }
}

protocol NFTDetailsViewModel: AnyObject {
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  var didUpdateInformationView: ((NFTDetailsInformationView.Model) -> Void)? { get set }
  var didUpdatePropertiesView: ((NFTDetailsPropertiesView.Model?) -> Void)? { get set }
  var didUpdateDetailsView: ((NFTDetailsDetailsView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapClose()
}

final class NFTDetailsViewModelImplementation: NFTDetailsViewModel, NFTDetailsModuleOutput {
  
  private var nft: NFT
  
  init(nft: NFT) {
    self.nft = nft
  }
  
  // MARK: - NFTDetailsModuleOutput
  
  var didClose: (() -> Void)?
  
  // MARK: - NFTDetailsViewModel
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateInformationView: ((NFTDetailsInformationView.Model) -> Void)?
  var didUpdatePropertiesView: ((NFTDetailsPropertiesView.Model?) -> Void)?
  var didUpdateDetailsView: ((NFTDetailsDetailsView.Model) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitleView?(createTitleViewModel())
    didUpdateInformationView?(createInformationViewModel())
    didUpdateDetailsView?(createDetailsViewModel())
    didUpdatePropertiesView?(createPropertiesViewModel())
  }
  
  func didTapClose() {
    didClose?()
  }
  
  // MARK: - Private
  
  private func createTitleViewModel() -> TKUINavigationBarTitleView.Model {
    let captionModel: TKPlainButton.Model? = {
      switch nft.trust {
      case .whitelist:
        nil
      case .blacklist, .none, .graylist, .unknown:
        TKPlainButton.Model(
          title: String.unverifiedNFT.withTextStyle(
            .body2,
            color: .Accent.orange,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
          ),
          icon: TKPlainButton.Model.Icon(
            image: .TKUIKit.Icons.Size12.informationCircle,
            tintColor: .Accent.orange,
            padding: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 0)
          ),
          action: {
            
          })
      }
    }()
    
    return TKUINavigationBarTitleView.Model(
      title: nft.notNilName,
      caption: captionModel
    )
  }
  
  private func createInformationViewModel() -> NFTDetailsInformationView.Model {
    let imageViewModel: TKImageView.Model = {
      TKImageView.Model(image: .urlImage(nft.preview.size1500), size: .none)
    }()

    let itemInformationViewModel: NFTDetailsItemInformationView.Model = {
      let collectionName = nft.collection?.notEmptyName ?? "Single NFT"
      return NFTDetailsItemInformationView.Model(
        name: nft.notNilName,
        collectionName: collectionName,
        isCollectionVerified: nft.trust == .whitelist,
        itemDescriptionModel: NFTDetailsMoreTextView.Model(
          text: nft.description,
          readMoreText: "More"
        )
      )
    }()
    
    let collectionInformationViewModel: NFTDetailsCollectionInformationView.Model? = {
      guard let collection = nft.collection else { return nil }
      return NFTDetailsCollectionInformationView.Model(
        title: .aboutCollection,
        collectionDescriptionModel: NFTDetailsMoreTextView.Model(
          text: collection.description,
          readMoreText: "More"
        )
      )
    }()
    
    return NFTDetailsInformationView.Model(
      imageViewModel: imageViewModel,
      itemInformationViewModel: itemInformationViewModel,
      collectionInformationViewModel: collectionInformationViewModel
    )
  }
  
  private func createDetailsViewModel() -> NFTDetailsDetailsView.Model {
    let headerViewModel = NFTDetailsSectionHeaderView.Model(
      title: "Details",
      buttonModel: TKPlainButton.Model(
        title: "View in explorer".withTextStyle(
          .label1,
          color: .Accent.blue,
          alignment: .left,
          lineBreakMode: .byTruncatingTail
        ),
        icon: nil,
        action: {
          
        }
      )
    )
  
    let listViewConfiguration = TKListContainerView.Configuration(
      items: [
        TKListContainerItemView.Model(
          title: "Owner",
          value: .value(
            TKListContainerItemDefaultValueView.Model(
              topValue: nft.owner?.address.toShortString(bounceable: false)
            )
          ),
          isHighlightable: true,
          copyValue: nft.owner?.address.toString(bounceable: false)
        ),
        TKListContainerItemView.Model(
          title: "Contract address",
          value: .value(
            TKListContainerItemDefaultValueView.Model(
              topValue: nft.address.toShortString(bounceable: true)
            )
          ),
          isHighlightable: true,
          copyValue: nft.address.toString(bounceable: true)
        )
      ]
    )
    
    return NFTDetailsDetailsView.Model(
      headerViewModel: headerViewModel,
      listViewConfiguration: listViewConfiguration
    )
  }
  
  private func createPropertiesViewModel() -> NFTDetailsPropertiesView.Model? {
    guard !nft.attributes.isEmpty else { return nil }
    
    let headerViewModel = NFTDetailsSectionHeaderView.Model(
      title: "Properties",
      buttonModel: nil
    )
    
    let propertyViewsModels = nft.attributes.map {
      NFTDetailsPropertyView.Model(
        title: $0.key,
        value: $0.value
      )
    }
    
    return NFTDetailsPropertiesView.Model(
      headerViewModel: headerViewModel,
      propertyViewsModels: propertyViewsModels
    )
  }
}

private extension String {
  static let unverifiedNFT = "Unverified NFT"
  static let aboutCollection = "About collection"
}
