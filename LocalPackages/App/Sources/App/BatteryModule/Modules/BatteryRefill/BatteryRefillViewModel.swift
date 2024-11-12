import UIKit
import TKUIKit
import TKCore
import KeeperCore
import TKLocalize

protocol BatteryRefillModuleOutput: AnyObject {
  var didTapSupportedTransactions: (() -> Void)? { get set }
  var didTapTransactionsSettings: (() -> Void)? { get set }
  var didTapRecharge: ((_ rechargeMethod: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> Void)? { get set }
  var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)? { get set }
  var didFinish: (() -> Void)? { get set }
}

protocol BatteryRefillModuleInput: AnyObject {
  
}

protocol BatteryRefillViewModel: AnyObject {
  var didUpdateSnapshot: ((BatteryRefill.Snapshot) -> Void)? { get set }
  var didUpdatePromocodeResolveState: ((BatteryPromocodeResolveState) -> Void)? { get set }
  var didUpdateHeaderView: ((BatteryRefillHeaderView.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func getInAppPurchaseCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
  func getListItemCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
  func getHeaderCellConfiguration() -> BatteryRefillHeaderView.Configuration?
  func getFooterCellConfiguration() -> BatteryRefillFooterView.Configuration?
  func purchaseItem(productIdentifier: String)
}

final class BatteryRefillViewModelImplementation: BatteryRefillViewModel, BatteryRefillModuleOutput, BatteryRefillModuleInput {
  
  // MARK: - BatteryRefillModuleOutput
  
  var didTapSupportedTransactions: (() -> Void)?
  var didTapTransactionsSettings: (() -> Void)?
  var didTapRecharge: ((_ rechargeMethod: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> Void)?
  var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)?
  var didFinish: (() -> Void)?
  
  // MARK: - BatteryRefillViewModel

  var didUpdateSnapshot: ((BatteryRefill.Snapshot) -> Void)?
  var didUpdatePromocodeResolveState: ((BatteryPromocodeResolveState) -> Void)?
  var didUpdateHeaderView: ((BatteryRefillHeaderView.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupPromocode()
    
    headerModel.didUpdateState = { [weak self] state in
      self?.headerState = state
      self?.updateHeader()
      self?.updateList()
    }
    headerState = headerModel.getState()
    
    iapItems = inAppPurchaseModel.items
    inAppPurchaseModel.loadProducts()
    inAppPurchaseModel.eventHandler = { [weak self] event in
      switch event {
      case .didUpdateItems(let items):
        self?.iapItems = items
        self?.updateList()
      case .didPerformTransaction:
        ToastPresenter.showToast(configuration: .defaultConfiguration(text: TKLocales.Battery.Refill.Toast.recharged))
      }
    }
    rechargeMethodsModelState = rechargeMethodsModel.state
    rechargeMethodsModel.stateHandler = { [weak self] state in
      self?.rechargeMethodsModelState = state
      self?.updateList()
    }
    rechargeMethodsModel.loadMethods()
    
    updateHeader()
    updateList()
  }
  
  func getInAppPurchaseCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
    purchasesCellConfigurations[identifier]
  }
  
  func getListItemCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
    listItemCellConfigurations[identifier]
  }
  
  func getHeaderCellConfiguration() -> BatteryRefillHeaderView.Configuration? {
    headerCellConfiguration
  }
  
  func getFooterCellConfiguration() -> BatteryRefillFooterView.Configuration? {
    footerCellConfiguration
  }
  
  func purchaseItem(productIdentifier: String) {
    inAppPurchaseModel.startProcessing(identifier: productIdentifier)
  }
  
  // MARK: - State
  
  
  private var headerState: BatteryRefillHeaderModel.State?
  private var iapItems = [BatteryIAPItem]()
  private var rechargeMethodsModelState: BatteryRefillRechargeMethodsModel.State = .loading
  private var promocode: String? {
    didSet {
      inAppPurchaseModel.promocode = promocode
    }
  }

  private var purchasesCellConfigurations = [String: TKListItemCell.Configuration]()
  private var listItemCellConfigurations = [String: TKListItemCell.Configuration]()
  private var headerCellConfiguration: BatteryRefillHeaderView.Configuration?
  private var footerCellConfiguration: BatteryRefillFooterView.Configuration?

  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let inAppPurchaseModel: BatteryRefillIAPModel
  private let rechargeMethodsModel: BatteryRefillRechargeMethodsModel
  private let headerModel: BatteryRefillHeaderModel
  private let tonProofTokenService: TonProofTokenService
  private let configuration: Configuration
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  private let promocodeOutput: BatteryPromocodeInputModuleOutput
  
  // MARK: - Init
  
  init(wallet: Wallet,
       inAppPurchaseModel: BatteryRefillIAPModel,
       rechargeMethodsModel: BatteryRefillRechargeMethodsModel,
       headerModel: BatteryRefillHeaderModel,
       tonProofTokenService: TonProofTokenService,
       configuration: Configuration,
       decimalAmountFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter,
       promocodeOutput: BatteryPromocodeInputModuleOutput) {
    self.wallet = wallet
    self.inAppPurchaseModel = inAppPurchaseModel
    self.rechargeMethodsModel = rechargeMethodsModel
    self.headerModel = headerModel
    self.tonProofTokenService = tonProofTokenService
    self.configuration = configuration
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountFormatter = amountFormatter
    self.promocodeOutput = promocodeOutput
  }
  
  private func updateList() {
    let snapshot = createSnapshot()
    didUpdateSnapshot?(snapshot)
  }
  
  private func updateHeader() {
    let batteryViewState: BatteryView.State
    let caption: String
    let informationButtonModel: TKPlainButton.Model?
    var tagConfiguration: TKTagView.Configuration?
    
    if headerState?.isBeta == true {
      tagConfiguration = .accentTag(text: "BETA", color: .Accent.orange)
    }
    
    switch headerState?.charge {
    case let .charged(chargesCount, batteryPercent):
      batteryViewState = .fill(batteryPercent)
      caption = "\(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: chargesCount))"
      informationButtonModel = nil
    case .notCharged:
      batteryViewState = .emptyTinted
      caption = TKLocales.Battery.Refill.emptyCaption
      informationButtonModel = TKPlainButton.Model(title: TKLocales.Battery.Refill.supportedTransactions.withTextStyle(.body2, color: .Accent.blue, alignment: .center, lineBreakMode: .byWordWrapping),
                                                   icon: nil,
                                                   action: { [weak self] in
        self?.didTapSupportedTransactions?()
      })
    case .none:
      return
    }
    
    let configuration = BatteryRefillHeaderView.Configuration(
      batteryViewState: batteryViewState,
      tagConfiguration: tagConfiguration,
      title: TKLocales.Battery.Refill.title,
      caption: caption,
      informationButtonModel: informationButtonModel
    )
    
    didUpdateHeaderView?(configuration)
  }
  
  private func createSnapshot() -> BatteryRefill.Snapshot {
    var snapshot = BatteryRefill.Snapshot()

    createHeaderSections(snapshot: &snapshot)
    createPromoSnapshotSection(snapshot: &snapshot)
    createInAppPurchasesSnapshotSection(snapshot: &snapshot)
    createRechargeMethodsSnapshotSection(snapshot: &snapshot)
    createHistorySnapshotSection(snapshot: &snapshot)
    createFooterSection(snapshot: &snapshot)
    
    return snapshot
  }
  
  private func createHeaderSections(snapshot: inout BatteryRefill.Snapshot) {
    snapshot.appendSections([.header])
    snapshot.appendItems([.header], toSection: .header)
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems([.header])
    } else {
      snapshot.reloadItems([.header])
    }
  
    
    switch headerState?.charge {
    case .charged:
      listItemCellConfigurations[.settingsCellIdentifier] = createSettingsCellConfiguration()
      
      snapshot.appendSections([.settings])
      snapshot.appendItems([.listItem(BatteryRefill.ListItem(
        identifier: .settingsCellIdentifier,
        onSelection: { [weak self] in
          self?.didTapTransactionsSettings?()
        })
      )], toSection: .settings)
      
    case .notCharged, .none:
      return
    }
  }
  
  private func createPromoSnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    snapshot.appendSections([.promocode])
    snapshot.appendItems([.promocode], toSection: .promocode)
  }
  
  private func createInAppPurchasesSnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    var purchasesCellConfigurations = [String: TKListItemCell.Configuration]()
    var snapshotItems = [BatteryRefill.SnapshotItem]()
    for item in iapItems {
      snapshotItems.append(createInAppPurchaseSnapshotItem(item: item))
      purchasesCellConfigurations[item.pack.productIdentifier] = createInAppPurchaseCellConfiguration(item: item)
    }
    
    snapshot.appendSections([.inAppPurchases])
    snapshot.appendItems(snapshotItems, toSection: .inAppPurchases)
    self.purchasesCellConfigurations = purchasesCellConfigurations
  }

  private func createRechargeMethodsSnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    var cellConfigurations = [String: TKListItemCell.Configuration]()
    var snapshotItems = [BatteryRefill.SnapshotItem]()
    switch rechargeMethodsModelState {
    case .loading:
      break
    case .idle(let items):
      for item in items {
        snapshotItems.append(createRechargeMethodSnapshotItem(item: item))
        cellConfigurations[item.identifier] = createRechargeMethodCellConfiguration(item: item)
      }
    }

    snapshot.appendSections([.rechargeMethods])
    snapshot.appendItems(snapshotItems, toSection: .rechargeMethods)
    self.listItemCellConfigurations.merge(cellConfigurations, uniquingKeysWith: { $1 })
  }
  
  private func createHistorySnapshotSection(snapshot: inout BatteryRefill.Snapshot) {
    snapshot.appendSections([.history])
    snapshot.appendItems([.listItem(BatteryRefill.ListItem(
      identifier: .historyCellIdentifier,
      onSelection: { [weak self] in
        guard let url = self?.createRefundURL() else {
          return
        }
        self?.didOpenRefundURL?(url, TKLocales.Battery.Refill.ChargesHistory.title)
      }))], toSection: .history)
    listItemCellConfigurations[.historyCellIdentifier] = createHistoryCellConfiguration()
  }
  
  private func createFooterSection(snapshot: inout BatteryRefill.Snapshot) {
    snapshot.appendSections([.footer])
    snapshot.appendItems([.footer], toSection: .footer)

    footerCellConfiguration = BatteryRefillFooterView.Configuration(
      description: TKLocales.Battery.Refill.Footer.description,
      restoreButtonTitle: TKLocales.Battery.Refill.Footer.restorePurchase,
      restoreButtonAction: { [weak self] in
        self?.inAppPurchaseModel.restorePurchases()
      }
    )
  }
  
  private func createInAppPurchaseSnapshotItem(item: BatteryIAPItem) -> BatteryRefill.SnapshotItem {
    let buttonTitle: String
    switch item.state {
    case .amount(let amount):
      let value = decimalAmountFormatter.format(
        amount: amount.price,
        maximumFractionDigits: 2,
        currency: amount.currency)
      buttonTitle = value
    case .loading:
      buttonTitle = "Loading"
    }
    
    return .inAppPurchase(
      BatteryRefill.InAppPurchaseItem(
        identifier: item.pack.productIdentifier,
        batteryPercent: item.pack.batteryPercent,
        buttonTitle: buttonTitle,
        isEnable: item.isEnable
      )
    )
  }
  
  private func createRechargeMethodSnapshotItem(item: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> BatteryRefill.SnapshotItem {
    let listItem = BatteryRefill.ListItem(
      identifier: item.identifier,
      onSelection: { [weak self] in
        self?.didTapRecharge?(item)
      }
    )
    return .listItem(listItem)
  }
  
  private func createInAppPurchaseCellConfiguration(item: BatteryIAPItem) -> TKListItemCell.Configuration {
    let caption: String
    switch item.state {
    case .loading:
      caption = "Loading"
    case .amount(let amount):
      caption = "\(amount.charges) \(TKLocales.Battery.Refill.chargesCount(count: amount.charges))"
    }
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: item.pack.name),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
  }
  
  private func createRechargeMethodCellConfiguration(item: BatteryRefillRechargeMethodsModel.RechargeMethodItem) -> TKListItemCell.Configuration {
    let title: String
    let caption: String
    let iconViewConfiguration: TKListItemIconView.Configuration
    switch item {
    case .token(let token, let amount):
      title = "\(TKLocales.Battery.Refill.Crypto.recharge) \(token.symbol)"
      
      switch token {
      case .ton:
        iconViewConfiguration = .tonConfiguration()
      case .jetton(let jettonItem):
        iconViewConfiguration = .configuration(jettonInfo: jettonItem.jettonInfo)
      }
      
      caption = amountFormatter.formatAmount(
        amount,
        fractionDigits: token.fractionDigits,
        maximumFractionDigits: 2,
        symbol: token.symbol
      )
    case .gift:
      title = TKLocales.Battery.Refill.Gift.title
      caption = TKLocales.Battery.Refill.Gift.caption
      iconViewConfiguration = TKListItemIconView.Configuration(
        content: TKListItemIconView.Configuration.Content.image(TKImageView.Model(image: TKImage.image(.App.Battery.gift))),
        alignment: .center,
        cornerRadius: 12,
        backgroundColor: .clear,
        size: CGSize(width: 44, height: 44)
      )
    }
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: iconViewConfiguration,
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
  }
  
  private func createHistoryCellConfiguration() -> TKListItemCell.Configuration {
    let title = TKLocales.Battery.Refill.ChargesHistory.title
    let caption = TKLocales.Battery.Refill.ChargesHistory.caption
    let iconViewConfiguration = TKListItemIconView.Configuration(
      content: TKListItemIconView.Configuration.Content.image(TKImageView.Model(image: TKImage.image(.App.Battery.history))),
      alignment: .center,
      cornerRadius: 12,
      backgroundColor: .clear,
      size: CGSize(width: 44, height: 44)
    )
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: iconViewConfiguration,
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2)
          ]
        )
      )
    )
  }
  
  private func createSettingsCellConfiguration() -> TKListItemCell.Configuration {
    let title = TKLocales.Battery.Refill.Settings.title
    let caption = "\(TKLocales.Battery.Refill.Settings.caption) \(TKLocales.Battery.Refill.Settings.Caption.Items.swaps), \(TKLocales.Battery.Refill.Settings.Caption.Items.tokenTransfers) and \(TKLocales.Battery.Refill.Settings.Caption.Items.nftTransfers)"
   
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [
            TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2, numberOfLines: 0)
          ]
        )
      )
    )
  }
  
  private func createRefundURL() -> URL? {
    guard let tonProof = try? tonProofTokenService.getWalletToken(wallet),
          let batteryRefundEndpoint = configuration.batteryRefundEndpoint(isTestnet: wallet.isTestnet) else {
      return nil
    }
    
    var components = URLComponents(url: batteryRefundEndpoint, resolvingAgainstBaseURL: true)
    components?.queryItems = [
      URLQueryItem(name: "token", value: tonProof),
      URLQueryItem(name: "testnet", value: String(wallet.isTestnet)),
    ]
    return components?.url
  }
  
  private func setupPromocode() {
    promocodeOutput.didUpdateResolvingState = { [weak self] state in
      switch state {
      case .failed, .none, .resolving:
        self?.promocode = nil
      case .success(let promocode):
        self?.promocode = promocode
      }
    }
  }
}

private extension String {
  static let historyCellIdentifier = "history_item"
  static let settingsCellIdentifier = "settings_item"
}
