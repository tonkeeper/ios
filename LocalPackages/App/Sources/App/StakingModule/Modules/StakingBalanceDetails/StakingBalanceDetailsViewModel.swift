import UIKit
import TKUIKit
import TKCore
import KeeperCore
import BigInt

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
  var title: String { get }
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)? { get set }
  var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)? { get set }
  var didUpdateDescription: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model) -> Void)? { get set }
  var didUpdateJettonItemView: ((TKUIListItemButton.Model?) -> Void)? { get set }
  var didUpdateJettonButtonDescription: ((NSAttributedString?) -> Void)? { get set }
  var didUpdateStakeStateView: ((TKUIListItemButton.Model?) -> Void)? { get set }
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
  
  var title: String {
    stakingPoolInfo.name
  }
  
  var didUpdateInformationView: ((TokenDetailsInformationView.Model) -> Void)?
  var didUpdateListViewModel: ((StakingDetailsListView.Model) -> Void)?
  var didUpdateDescription: ((NSAttributedString?) -> Void)?
  var didUpdateLinksViewModel: ((StakingDetailsLinksView.Model) -> Void)?
  var didUpdateJettonItemView: ((TKUIListItemButton.Model?) -> Void)?
  var didUpdateJettonButtonDescription: ((NSAttributedString?) -> Void)?
  var didUpdateStakeStateView: ((TKUIListItemButton.Model?) -> Void)?
  var didUpdateButtonsView: ((TokenDetailsHeaderButtonsView.Model) -> Void)?
  
  // MARK: - State
  
  private let queue = DispatchQueue(label: "StakingBalanceDetailsViewModelImplementationQueue")
  private var accountStackingInfo: AccountStackingInfo
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
       accountStackingInfo: AccountStackingInfo,
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
    self.accountStackingInfo = accountStackingInfo
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
//    guard let jettonBalanceItem else {
//      didUpdateJettonItemView?(nil)
//      return
//    }
//    
//    let configuration = balanceItemMapper.mapJettonItem(jettonBalanceItem, isSecure: false)
//    didUpdateJettonItemView?(
//      TKUIListItemButton.Model(
//        listItemConfiguration: configuration,
//        tapClosure: { [weak self] in
//          guard let self else { return }
//          self.openJettonDetails?(self.wallet, jettonBalanceItem.jetton)
//        }
//      )
//    )
//    
//    didUpdateJettonButtonDescription?(
//      String.jettonButtonDescription.withTextStyle(
//        .body3,
//        color: .Text.tertiary,
//        alignment: .left,
//        lineBreakMode: .byWordWrapping
//      )
//    )
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
      tapClosure = { [weak self, wallet, stakingPoolInfo, accountStackingInfo] in
        self?.didTapCollect?(wallet, stakingPoolInfo, accountStackingInfo)
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
    
    let model = TKUIListItemButton.Model(
      listItemConfiguration: TKUIListItemView.Configuration(
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: title.withTextStyle(.label1, color: .Text.primary, alignment: .left, lineBreakMode: .byTruncatingTail),
            tagViewModel: nil,
            subtitle: subtitle.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            description: nil
          ),
          rightItemConfiguration: TKUIListItemContentRightItem.Configuration(
            value: amountFormatted.withTextStyle(
              .label1,
              color: .Text.primary,
              alignment: .right,
              lineBreakMode: .byTruncatingTail
            ),
            subtitle: convertedFormatted.withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail),
            description: nil
          ),
          isVerticalCenter: true
        ),
        accessoryConfiguration: .none
      ),
      tapClosure: tapClosure
    )
    
    didUpdateStakeStateView?(model)
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
  static let mostProfitableTag = "MAX APY"
  static let apy = "APY"
  static let minimalDeposit = "Minimal Deposit"
  static let description = "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience."
  static let jettonButtonDescription = "When you stake TON in a Tonstakers pool, you receive a token called tsTON that represents your share in the pool. As the pool accumulates profits, your tsTON represents larger amount of TON."
  static let pendingStakeTitle = "Pending Stake"
  static let pendingUntakeTitle = "Pending Unstake"
  static let unstakeReadyTitle = "Unstake ready"
  static let afterTheEndOfTheCycle = "after the end of the cycle"
  static let tapToCollect = "Tap to collect"
  static let stakeTitle = "Stake"
  static let unstakeTitle = "Unstake"
}

private extension CGSize {
  static let iconSize = CGSize(width: 44, height: 44)
  static let badgeIconSize = CGSize(width: 24, height: 24)
}
