import UIKit
import TKUIKit
import KeeperCore
import TonSwift
import TKLocalize

protocol NFTDetailsModuleOutput: AnyObject {
  var didClose: (() -> Void)? { get set }
  var didTapTransfer: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
  var didTapLinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
  var didTapUnlinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
  var didTapRenewDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)? { get set }
  var didTapProgrammaticButton: ((_ url: URL) -> Void)? { get set }
}

protocol NFTDetailsViewModel: AnyObject {
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  var didUpdateInformationView: ((NFTDetailsInformationView.Model) -> Void)? { get set }
  var didUpdateButtonsView: ((NFTDetailsButtonsView.Model?) -> Void)? { get set }
  var didUpdatePropertiesView: ((NFTDetailsPropertiesView.Model?) -> Void)? { get set }
  var didUpdateDetailsView: ((NFTDetailsDetailsView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func didTapClose()
}

final class NFTDetailsViewModelImplementation: NFTDetailsViewModel, NFTDetailsModuleOutput {

  private struct DNSResolveData {
    let linkedAddressResult: Result<FriendlyAddress, Swift.Error>
    let expirationDateResult: Result<Date?, Swift.Error>
  }
  
  private enum DNSResolveState {
    case idle
    case loading
    case resolved(DNSResolveData)
  }
  
  private var dnsResolveState: DNSResolveState = .idle {
    didSet {
      update()
    }
  }
  
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM yyyy"
    return formatter
  }()
  
  private var nft: NFT
  private let wallet: Wallet
  private let dnsService: DNSService
  private let appSetttingsStore: AppSettingsV3Store
  
  private let mnemonicRepository: MnemonicsRepository

  init(nft: NFT,
       wallet: Wallet,
       dnsService: DNSService,
       appSetttingsStore: AppSettingsV3Store,
       mnemonicRepository: MnemonicsRepository) {
    self.nft = nft
    self.wallet = wallet
    self.dnsService = dnsService
    self.appSetttingsStore = appSetttingsStore
    self.mnemonicRepository = mnemonicRepository
  }
  
  // MARK: - NFTDetailsModuleOutput
  
  var didClose: (() -> Void)?
  var didTapTransfer: ((Wallet, NFT) -> Void)?
  var didTapLinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
  var didTapUnlinkDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
  var didTapRenewDomain: ((_ wallet: Wallet, _ nft: NFT) -> Void)?
  var didTapProgrammaticButton: ((_ url: URL) -> Void)?
  var didComposeProgrammaticButtonLink: ((_ url: URL) -> Void)?

  // MARK: - NFTDetailsViewModel
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateInformationView: ((NFTDetailsInformationView.Model) -> Void)?
  var didUpdateButtonsView: ((NFTDetailsButtonsView.Model?) -> Void)?
  var didUpdatePropertiesView: ((NFTDetailsPropertiesView.Model?) -> Void)?
  var didUpdateDetailsView: ((NFTDetailsDetailsView.Model) -> Void)?
  
  func viewDidLoad() {
    resolveDNS()
    update()
  }
  
  func didTapClose() {
    didClose?()
  }

  // MARK: - Private
  
  private func update() {
    let isSecureMode = appSetttingsStore.getState().isSecureMode
    didUpdateTitleView?(createTitleViewModel(isSecureMode: isSecureMode))
    didUpdateInformationView?(createInformationViewModel(isSecureMode: isSecureMode))
    didUpdateButtonsView?(createButtonsViewModel())
    didUpdateDetailsView?(createDetailsViewModel())
    didUpdatePropertiesView?(createPropertiesViewModel(isSecureMode: isSecureMode))
  }
  
  private func createTitleViewModel(isSecureMode: Bool) -> TKUINavigationBarTitleView.Model {
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
      title: isSecureMode ? .secureModeValueShort : nft.notNilName,
      caption: captionModel
    )
  }
  
  private func createInformationViewModel(isSecureMode: Bool) -> NFTDetailsInformationView.Model {
    let imageViewModel: TKImageView.Model = {
      TKImageView.Model(image: .urlImage(nft.preview.size500), size: .none)
    }()
    
    let image = NFTDetailsInformationView.Model.Image(
      imageViewModel: imageViewModel,
      isBlurVisible: isSecureMode
    )

    let itemInformationViewModel: NFTDetailsItemInformationView.Model = {
      let name: String = isSecureMode ? .secureModeValueLong : nft.notNilName
      let collectionName: String = isSecureMode ? .secureModeValueShort : nft.collection?.notEmptyName ?? TKLocales.NftDetails.singleNft
      let nftDescription: String? = isSecureMode ? .secureModeValueShort : nft.description
      return NFTDetailsItemInformationView.Model(
        name: name,
        collectionName: collectionName,
        isCollectionVerified: nft.trust == .whitelist,
        itemDescriptionModel: NFTDetailsMoreTextView.Model(
          text: nftDescription,
          readMoreText: TKLocales.Actions.more
        )
      )
    }()

    let collectionInformationViewModel: NFTDetailsCollectionInformationView.Model? = {
      guard let collection = nft.collection else { return nil }
      return NFTDetailsCollectionInformationView.Model(
        title: .aboutCollection,
        collectionDescriptionModel: NFTDetailsMoreTextView.Model(
          text: isSecureMode ? .secureModeValueShort : collection.description,
          readMoreText: TKLocales.Actions.more
        )
      )
    }()
    
    return NFTDetailsInformationView.Model(
      image: image,
      itemInformationViewModel: itemInformationViewModel,
      collectionInformationViewModel: collectionInformationViewModel
    )
  }
  
  private func createDetailsViewModel() -> NFTDetailsDetailsView.Model {
    let headerViewModel = NFTDetailsSectionHeaderView.Model(
        title: TKLocales.NftDetails.details,
      buttonModel: TKPlainButton.Model(
        title: TKLocales.NftDetails.viewInExplorer.withTextStyle(
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
    
    var items = [TKListContainerItemView.Model]()
    items.append(TKListContainerItemView.Model(
      title: TKLocales.NftDetails.owner,
      value: .value(
        TKListContainerItemDefaultValueView.Model(
          topValue: nft.owner?.address.toShortString(bounceable: false)
        )
      ),
      isHighlightable: true,
      copyValue: nft.owner?.address.toString(bounceable: false)
    ))
    
    switch dnsResolveState {
    case .resolved(let data):
      guard let date = try? data.expirationDateResult.get() else { break }
      let dateFormatted = dateFormatter.string(from: date)
      items.append(TKListContainerItemView.Model(
        title: TKLocales.NftDetails.expirationDate,
        value: .value(
          TKListContainerItemDefaultValueView.Model(
            topValue: dateFormatted
          )
        ),
        isHighlightable: false,
        copyValue: nil
      ))
    default:
      break
    }
    
    items.append(TKListContainerItemView.Model(
      title: TKLocales.NftDetails.contractAddress,
      value: .value(
        TKListContainerItemDefaultValueView.Model(
          topValue: nft.address.toShortString(bounceable: true)
        )
      ),
      isHighlightable: true,
      copyValue: nft.address.toString(bounceable: true)
    ))
  
    let listViewConfiguration = TKListContainerView.Configuration(
      items: items
    )
    
    return NFTDetailsDetailsView.Model(
      headerViewModel: headerViewModel,
      listViewConfiguration: listViewConfiguration
    )
  }
  
  private func createPropertiesViewModel(isSecureMode: Bool) -> NFTDetailsPropertiesView.Model? {
    guard !nft.attributes.isEmpty, !isSecureMode else { return nil }
    
    let headerViewModel = NFTDetailsSectionHeaderView.Model(
      title: TKLocales.NftDetails.properties,
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
  
  private func createButtonsViewModel() -> NFTDetailsButtonsView.Model? {
    guard wallet.kind != .watchonly else { return nil }
    var buttonsConfigurations = [NFTDetailsButtonView.Model]()
    if let transferButtonConfiguration = createTransferButtonConfiguration() {
      buttonsConfigurations.append(transferButtonConfiguration)
    }
    
    buttonsConfigurations.append(contentsOf: createLinkButtons())

    buttonsConfigurations.append(contentsOf: composeProgrammaticButtons())

    guard !buttonsConfigurations.isEmpty else {
      return nil
    }
    
    return NFTDetailsButtonsView.Model(buttonViewModels: buttonsConfigurations)
  }
  
  private func createTransferButtonConfiguration() -> NFTDetailsButtonView.Model? {
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    buttonConfiguration.isEnabled = nft.sale == nil && isNFTOwner
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.NftDetails.transfer))
    buttonConfiguration.action = { [weak self, nft, wallet] in
      self?.didTapTransfer?(wallet, nft)
    }
    
    var description: NSAttributedString?
    if nft.sale != nil {
      let value: String = nft.dns == nil ? .nftOnSaleDescription : .domainOnSaleDescription
      description = value.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    }
    
    return NFTDetailsButtonView.Model(buttonConfiguration: buttonConfiguration,
                                      description: description)
  }

  private func composeProgrammaticButtons() -> [NFTDetailsButtonView.Model] {
    guard let buttons = nft.programmaticButtons, nft.trust == .whitelist else {
      return []
    }

    return buttons.enumerated().compactMap { button -> NFTDetailsButtonView.Model? in
      guard let label = button.element.label else {
        return nil
      }

      let content = TKButton.Configuration.Content(title: .plainString(label), icon: .TKUIKit.Icons.Size28.linkOutline)
      let category = TKActionButtonCategory.secondary
      var configuration: TKButton.Configuration
      if button.offset == 0 {
        let size = TKActionButtonSize.large
        configuration = TKButton.Configuration(
          content: content,
          contentPadding: size.padding,
          textStyle: TKActionButtonSize.large.textStyle,
          textColor: category.titleColor,
          iconTintColor: category.titleColor,
          backgroundColors: [
            .normal: UIColor.Button.primaryBackgroundGreen,
            .highlighted: UIColor.Button.primaryBackgroundGreenHighlighted,
            .disabled: UIColor.Button.primaryBackgroundGreenDisabled
          ],
          cornerRadius: size.cornerRadius,
          loaderSize: size.loaderViewSize
        )
      } else {
        configuration = TKButton.Configuration.actionButtonConfiguration(
          category: .secondary,
          size: .large
        )
      }

      configuration.content = content
      configuration.iconPosition = .right
      configuration.action = { [weak self] in
        guard let url = button.element.url else {
          return
        }

        self?.didTapProgrammaticButton?(url)
      }
      return .init(buttonConfiguration: configuration, description: nil)
    }
  }

  private func createLinkButtons() -> [NFTDetailsButtonView.Model] {
    switch dnsResolveState {
    case .idle:
      return []
    case .loading:
      return [createLinkResolvingButton()]
    case .resolved(let data):
      var buttons = [createLinkedButton(result: data.linkedAddressResult)]
      switch data.linkedAddressResult {
      case .success:
        buttons.append(createRenewButton(result: data.expirationDateResult))
      case .failure:
        break
      }
      return buttons
    }
  }
  
  private func createLinkResolvingButton() -> NFTDetailsButtonView.Model {
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    buttonConfiguration.isEnabled = false
    buttonConfiguration.showsLoader = true
    buttonConfiguration.loaderSize = .medium
    buttonConfiguration.loaderStyle = .primary
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(" "))
    
    return NFTDetailsButtonView.Model(buttonConfiguration: buttonConfiguration, description: nil)
  }
  
  private func createLinkedButton(result: Result<FriendlyAddress, Swift.Error>) -> NFTDetailsButtonView.Model {
    let title: String
    let action: () -> Void
    switch result {
    case .success(let success):
      title = TKLocales.NftDetails.linkedWith(success.toShort())
      action = { [weak self, wallet, nft] in
        self?.didTapUnlinkDomain?(wallet, nft)
      }
    case .failure(let failure):
      title = TKLocales.NftDetails.linkedDomain
      action = { [weak self, wallet, nft] in
        self?.didTapLinkDomain?(wallet, nft)
      }
    }
    
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    buttonConfiguration.isEnabled = nft.sale == nil && isNFTOwner
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(title))
    buttonConfiguration.action = action
    
    return NFTDetailsButtonView.Model(buttonConfiguration: buttonConfiguration, description: nil)
  }
  
  private func createRenewButton(result: Result<Date?, Swift.Error>) -> NFTDetailsButtonView.Model {
    let dateFormatted: String = {
      if let date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) {
        return dateFormatter.string(from: date)
      } else {
        return " "
      }
    }()
    let title = TKLocales.NftDetails.renewUntil(dateFormatted)

    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
    buttonConfiguration.isEnabled = nft.sale == nil && isNFTOwner
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(title))
    buttonConfiguration.action = { [weak self, wallet, nft] in
      self?.didTapRenewDomain?(wallet, nft)
    }
    
    var description: NSAttributedString?
    if let expiresData = try? result.get() {
      let numberOfDays = Calendar.current.dateComponents([.day], from: Date(), to: expiresData).day ?? 0
      let value = TKLocales.NftDetails.expiresInDays(numberOfDays)

      description = value.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .center,
        lineBreakMode: .byWordWrapping
      )
    }
    
    return NFTDetailsButtonView.Model(buttonConfiguration: buttonConfiguration, description: description)
  }
  
  
  private var isNFTOwner: Bool {
    do {
      return try nft.owner?.address == wallet.address
    } catch {
      return false
    }
  }
  
  private func resolveDNS() {
    guard let dns = nft.dns else { return }
    dnsResolveState = .loading
    Task {
      async let linkedAddressTask = loadDNSLinkedAddress(dns: dns)
      async let expirationDateTask = getDNSExpirationDate(dns: dns)
      
      let linkedAddressResult = await linkedAddressTask
      let expirationDateResult = await expirationDateTask
      await MainActor.run {
        dnsResolveState = .resolved(
          DNSResolveData(
            linkedAddressResult: linkedAddressResult,
            expirationDateResult: expirationDateResult
          )
        )
      }
    }
  }
  
  private func loadDNSLinkedAddress(dns: String) async -> Result<FriendlyAddress, Swift.Error> {
    do {
      let linkedAddress = try await dnsService.resolveDomainName(
        dns,
        isTestnet: wallet.isTestnet
      )
      return .success(linkedAddress.friendlyAddress)
    } catch {
      return .failure(error)
    }
  }
  
  private func getDNSExpirationDate(dns: String) async -> Result<Date?, Swift.Error> {
    do {
      let date = try await dnsService.loadDomainExpirationDate(
        dns,
        isTestnet: wallet.isTestnet
      )
      return .success(date)
    } catch {
      return .failure(error)
    }
  }
}

private extension String {
  static let unverifiedNFT = TKLocales.NftDetails.unverifiedNft
  static let aboutCollection = TKLocales.NftDetails.aboutCollection
  static let domainOnSaleDescription = TKLocales.NftDetails.domainOnSaleDescription
  static let nftOnSaleDescription = TKLocales.NftDetails.nftOnSaleDescription
  static let expirationDateTitle = TKLocales.NftDetails.expirationDate
}
