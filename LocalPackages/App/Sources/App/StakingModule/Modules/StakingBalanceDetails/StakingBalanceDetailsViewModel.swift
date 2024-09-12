import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt
import TKLocalize

protocol StakingBalanceDetailsModuleOutput: AnyObject {
  var didOpenURL: ((URL) -> Void)? { get set }
  var didOpenURLInApp: ((URL, String?) -> Void)? { get set }
  var openJettonDetails: ((_ wallet: Wallet, _ jettonItem: JettonItem) -> Void)? { get set }
  var didTapStake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
  var didTapUnstake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)? { get set }
  var didTapCollect: (( _ wallet: Wallet,
                        _ stakingPoolInfo: StackingPoolInfo,
                        _ accountStakingInfo: AccountStackingInfo) -> Void)? { get set }
}

protocol StakingBalanceDetailsModuleInput: AnyObject {
  
}

protocol StakingBalanceDetailsViewModel: AnyObject {
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
  var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)? { get set }
  var didUpdateDescription: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model) -> Void)? { get set }
  var didUpdateJettonItemView: ((TKListItemButton.Configuration?) -> Void)? { get set }
  var didUpdateJettonButtonDescription: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateStakeStateView: ((TKListItemButton.Configuration?) -> Void)? { get set }
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakingBalanceDetailsViewModelImplementation: StakingBalanceDetailsViewModel, StakingBalanceDetailsModuleOutput {
  
  // MARK: - StakingBalanceDetailsModuleOutput
  
  var didOpenURL: ((URL) -> Void)?
  var didOpenURLInApp: ((URL, String?) -> Void)?
  var openJettonDetails: ((Wallet, JettonItem) -> Void)?
  var didTapStake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?
  var didTapUnstake: ((_ wallet: Wallet, _ stakingPoolInfo: StackingPoolInfo) -> Void)?
  var didTapCollect: (( _ wallet: Wallet,
                        _ stakingPoolInfo: StackingPoolInfo,
                        _ accountStakingInfo: AccountStackingInfo) -> Void)?
  
  // MARK: - StakingViewModel
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
  var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)?
  var didUpdateDescription: ((NSAttributedString?) -> Void)?
  var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model) -> Void)?
  var didUpdateJettonItemView: ((TKListItemButton.Configuration?) -> Void)?
  var didUpdateJettonButtonDescription: ((NSAttributedString?) -> Void)?
  var didUpdateStakeStateView: ((TKListItemButton.Configuration?) -> Void)?
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)?
  
  // MARK: - State
  
  private let queue = DispatchQueue(label: "StakingBalanceDetailsViewModelImplementationQueue")
  private var balanceItem: ProcessedBalanceStakingItem?
  private var jettonBalanceItem: ProcessedBalanceJettonItem?
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let stakingPoolInfo: StackingPoolInfo
  private let listViewModelBuilder: StakingListViewModelBuilder
  private let linksViewModelBuilder: StakingLinksViewModelBuilder
  private let balanceItemMapper: BalanceItemMapper
  private let stakingPoolsStore: StakingPoolsStore
  private let balanceStore: ProcessedBalanceStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let decimalFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(wallet: Wallet,
       stakingPoolInfo: StackingPoolInfo,
       listViewModelBuilder: StakingListViewModelBuilder,
       linksViewModelBuilder: StakingLinksViewModelBuilder,
       balanceItemMapper: BalanceItemMapper,
       stakingPoolsStore: StakingPoolsStore,
       balanceStore: ProcessedBalanceStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       decimalFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.wallet = wallet
    self.stakingPoolInfo = stakingPoolInfo
    self.listViewModelBuilder = listViewModelBuilder
    self.linksViewModelBuilder = linksViewModelBuilder
    self.balanceItemMapper = balanceItemMapper
    self.stakingPoolsStore = stakingPoolsStore
    self.balanceStore = balanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.decimalFormatter = decimalFormatter
    self.amountFormatter = amountFormatter
  }
  
  
  func viewDidLoad() {
    didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: stakingPoolInfo.name))
    queue.sync {
      prepareInitialState()
      updateInformation()
      updateDescription()
      updateList()
      updateLinks()
      updateJettonItemView()
      updateStakeStateView()
      updateButtons()
    }
  }
}

private extension StakingBalanceDetailsViewModelImplementation {
  func updateList() {
    let profitablePool = stakingPoolsStore.getState()[wallet]?.profitablePool
    let model = self.listViewModelBuilder.build(stakingPoolInfo: stakingPoolInfo, isMaxAPY: profitablePool?.address == self.stakingPoolInfo.address)
    DispatchQueue.main.async {
      self.didUpdateListViewModel?(model)
    }
  }
  
  func updateLinks() {
    let model = linksViewModelBuilder.buildModel(
      poolInfo: stakingPoolInfo,
      openURL: { [weak self] url in
        self?.didOpenURL?(url)
      },
      openURLInApp: { [weak self] url in
        self?.didOpenURLInApp?(url, nil)
      })
    DispatchQueue.main.async {
      self.didUpdateLinksViewModel?(model)
    }
  }
  
  func updateDescription() {
    didUpdateDescription?(
      String.description.withTextStyle(
        .body3,
        color: .Text.tertiary,
        alignment: .left,
        lineBreakMode: .byWordWrapping
      )
    )
  }
  
  func prepareInitialState() {
    guard let balance = balanceStore.getState()[wallet]?.balance else {
      return
    }

    self.balanceItem = balance.stakingItems.first(where: { $0.poolInfo?.address == stakingPoolInfo.address })
    self.jettonBalanceItem = balanceItem?.jetton
  }
  
  func updateInformation() {
    guard let balanceItem else {
      return
    }
    
    let tokenAmount = amountFormatter.formatAmount(
      BigUInt(UInt64(balanceItem.info.amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      symbol: TonInfo.symbol
    )
    
    let convertedAmount = decimalFormatter.format(
      amount: balanceItem.amountConverted,
      maximumFractionDigits: 2,
      currency: balanceItem.currency
    )
    
    let badgeImage = TKUIListItemImageIconView.Configuration.Image.image(stakingPoolInfo.implementation.icon)
    let badgeIconConfiguration = TKUIListItemImageIconView.Configuration(
      image: badgeImage,
      tintColor: .Icon.primary,
      backgroundColor: .Background.contentTint,
      size: .badgeIconSize,
      cornerRadius: 13,
      borderWidth: 2,
      borderColor: .Background.page,
      contentMode: .scaleAspectFill
    )
    
    let model = TokenDetailsInformationView.Model(
      imageConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .imageWithBadge(TKUIListItemImageIconView.Configuration(
          image: .image(
            .TKCore.Icons.Size44.tonLogo
          ),
          tintColor: .clear,
          backgroundColor: .clear,
          size: CGSize(width: 64, height: 64),
          cornerRadius: 32,
          contentMode: .scaleAspectFit,
          imageSize: CGSize(width: 64, height: 64)
        ), badgeIconConfiguration),
        alignment: .center
      ),
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount
    )
    
    DispatchQueue.main.async {
      self.didUpdateInformationView?(model)
    }
  }
  
  func updateJettonItemView() {
    guard let jettonBalanceItem else {
      didUpdateJettonItemView?(nil)
      return
    }
    
    let configuration = balanceItemMapper.mapJettonItem(jettonBalanceItem)
    didUpdateJettonItemView?(
      TKListItemButton.Configuration(
        listItemConfiguration: configuration,
        tapClosure: { [weak self] in
          guard let self else { return }
          self.openJettonDetails?(self.wallet, jettonBalanceItem.jetton)
        })
      )
      
      didUpdateJettonButtonDescription?(
        String.jettonButtonDescription.withTextStyle(
          .body3,
          color: .Text.tertiary,
          alignment: .left,
          lineBreakMode: .byWordWrapping
        )
      )
  }
  
  func updateStakeStateView() {
    guard let balanceItem else {
      didUpdateStakeStateView?(nil)
      return
    }
    
    let currency = currencyStore.getState()
    
    func convert(amount: Int64) -> Decimal {
      let converter = RateConverter()
      
      if let rate = tonRatesStore.getState().first(where: { $0.currency == currency }) {
        return converter.convertToDecimal(
          amount: BigUInt(UInt64(amount)),
          amountFractionLength: TonInfo.fractionDigits,
          rate: rate
        )
      }
      return 0
    }
    
    let title: String
    let subtitle: String
    let amount: Int64
    let converted: Decimal
    let tapClosure: (() -> Void)?
    
    if balanceItem.info.pendingDeposit > 0 {
      amount = balanceItem.info.pendingDeposit
      converted = convert(amount: balanceItem.info.pendingDeposit)
      title = .pendingStakeTitle
      subtitle = .afterTheEndOfTheCycle
      tapClosure = nil
    } else if balanceItem.info.pendingWithdraw > 0 {
      amount = balanceItem.info.pendingWithdraw
      converted = convert(amount: balanceItem.info.pendingWithdraw)
      title = .pendingUntakeTitle
      subtitle = .afterTheEndOfTheCycle
      tapClosure = nil
    } else if balanceItem.info.readyWithdraw > 0 {
      amount = balanceItem.info.readyWithdraw
      converted = convert(amount: balanceItem.info.readyWithdraw)
      title = .unstakeReadyTitle
      subtitle = .tapToCollect
      tapClosure = { [weak self, wallet] in
        guard let poolInfo = balanceItem.poolInfo  else { return }
        self?.didTapCollect?(wallet, poolInfo, balanceItem.info)
      }
    } else {
      didUpdateStakeStateView?(nil)
      return
    }
    
    let amountFormatted = amountFormatter.formatAmount(
      BigUInt(UInt64(amount)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    )
    
    let convertedFormatted = decimalFormatter.format(
      amount: converted,
      maximumFractionDigits: 2,
      currency: currency
    )
    
    let configuration = TKListItemButton.Configuration(
      listItemConfiguration: TKListItemContentView.Configuration(
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: TKListItemTitleView.Configuration(title: title),
          captionViewsConfigurations: [TKListItemTextView.Configuration(
            text: subtitle,
            color: .Text.secondary,
            textStyle: .body2
          )],
          valueViewConfiguration: TKListItemTextView.Configuration(
            text: amountFormatted,
            color: .Text.primary,
            textStyle: .label1
          ),
          valueCaptionViewConfiguration: TKListItemTextView.Configuration(
            text: convertedFormatted,
            color: .Text.secondary,
            textStyle: .body2
          )
        )
      ),
      tapClosure: tapClosure
    )
    
    didUpdateStakeStateView?(configuration)
  }
  
  func updateButtons() {
    let model = TokenDetailsHeaderButtonsView.Model(
      buttons: [
        TokenDetailsHeaderButtonsView.Model.Button(
          configuration: TKUIIconButton.Model(
            image: .TKUIKit.Icons.Size28.plusOutline,
            title: .stakeTitle
          ),
          action: { [weak self, wallet, stakingPoolInfo] in
            self?.didTapStake?(wallet, stakingPoolInfo)
          }
        ),
        TokenDetailsHeaderButtonsView.Model.Button(
          configuration: TKUIIconButton.Model(
            image: .TKUIKit.Icons.Size28.minusOutline,
            title: .unstakeTitle
          ),
          action: { [weak self, wallet, stakingPoolInfo] in
            self?.didTapUnstake?(wallet, stakingPoolInfo)
          }
        )
      ]
    )
    didUpdateButtonsView?(model)
  }
}

private extension String {
  static let mostProfitableTag = TKLocales.max_apy
  static let apy = TKLocales.apy
  static let minimalDeposit = TKLocales.StakingBalanceDetails.minimal_deposit
  static let description = TKLocales.StakingBalanceDetails.description
  static let jettonButtonDescription = TKLocales.StakingBalanceDetails.jetton_button_description
  static let pendingStakeTitle = TKLocales.StakingBalanceDetails.pending_stake
  static let pendingUntakeTitle = TKLocales.StakingBalanceDetails.pending_unstake
  static let unstakeReadyTitle = TKLocales.StakingBalanceDetails.unstake_ready
  static let afterTheEndOfTheCycle = TKLocales.StakingBalanceDetails.after_end_of_cycle
  static let tapToCollect = TKLocales.StakingBalanceDetails.tap_to_collect
  static let stakeTitle = TKLocales.StakingBalanceDetails.stake
  static let unstakeTitle = TKLocales.StakingBalanceDetails.unstake
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
  static let badgeIconSize = CGSize(width: 24, height: 24)
}
