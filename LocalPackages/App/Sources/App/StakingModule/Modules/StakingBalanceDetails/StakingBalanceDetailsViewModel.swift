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
  var didTapUnstake: ((_ wallet: Wallet) -> Void)? { get set }
  var didTapCollect: ((_ wallet: Wallet) -> Void)? { get set }
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
  var didTapUnstake: ((_ wallet: Wallet) -> Void)?
  var didTapCollect: ((_ wallet: Wallet) -> Void)?
  
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
  private var balanceItem: BalanceStakingItemModel?
  private var jettonBalanceItem: BalanceJettonItemModel?
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let stakingPoolInfo: StackingPoolInfo
  private let listViewModelBuilder: StakingListViewModelBuilder
  private let linksViewModelBuilder: StakingLinksViewModelBuilder
  private let balanceItemMapper: BalanceItemMapper
  private let stakingPoolsStore: StakingPoolsStore
  private let balanceStore: ConvertedBalanceStoreV2
  private let tonRatesStore: TonRatesStoreV2
  private let currencyStore: CurrencyStoreV2
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
       balanceStore: ConvertedBalanceStoreV2,
       tonRatesStore: TonRatesStoreV2,
       currencyStore: CurrencyStoreV2,
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
    guard let address = try? wallet.friendlyAddress else { return }
    let profitablePool = stakingPoolsStore.getState()[address]?.profitablePool
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
    guard let address = try? wallet.friendlyAddress,
          let balance = balanceStore.getState()[address]?.balance else {
      return
    }
    
    if let stakingPoolJetton = balance.jettonsBalance
      .first(where: { $0.jettonBalance.item.jettonInfo.address == stakingPoolInfo.liquidJettonMaster }) {
      var amount: Int64 = 0
      if let tonRate = stakingPoolJetton.jettonBalance.rates[.TON] {
        let converted = RateConverter().convertToDecimal(
          amount: stakingPoolJetton.jettonBalance.quantity,
          amountFractionLength: stakingPoolJetton.jettonBalance.item.jettonInfo.fractionDigits,
          rate: tonRate
        )
        let convertedFractionLength = min(Int16(TonInfo.fractionDigits),max(Int16(-converted.exponent), 0))
        amount = Int64(NSDecimalNumber(decimal: converted)
          .multiplying(byPowerOf10: convertedFractionLength).doubleValue)
      }
      
      let info = AccountStackingInfo(
        pool: stakingPoolInfo.address,
        amount: amount,
        pendingDeposit: accountStackingInfo.pendingDeposit,
        pendingWithdraw: accountStackingInfo.pendingWithdraw,
        readyWithdraw: accountStackingInfo.readyWithdraw
      )
      
      let stakingItem = BalanceStakingItemModel(
        id: info.pool.toRaw(),
        info: info,
        poolInfo: stakingPoolInfo,
        currency: balance.currency,
        converted: stakingPoolJetton.converted,
        price: stakingPoolJetton.price
      )
      let jettonBalanceItem = BalanceJettonItemModel(
        id: stakingPoolJetton.jettonBalance.item.jettonInfo.address.toRaw(),
        jetton: stakingPoolJetton.jettonBalance.item,
        amount: stakingPoolJetton.jettonBalance.quantity,
        fractionalDigits: stakingPoolJetton.jettonBalance.item.jettonInfo.fractionDigits,
        tag: nil,
        currency: balance.currency,
        converted: stakingPoolJetton.converted,
        price: stakingPoolJetton.price,
        diff: stakingPoolJetton.diff
      )
      
      self.jettonBalanceItem = jettonBalanceItem
      self.balanceItem = stakingItem
      
      return
    }
    
    if let stakingItem = balance.stackingBalance.first(where: { $0.stackingInfo.pool == stakingPoolInfo.address }) {
      let balanceItem = BalanceStakingItemModel(
        id: stakingItem.stackingInfo.pool.toRaw(),
        info: stakingItem.stackingInfo,
        poolInfo: stakingPoolInfo,
        currency: balance.currency,
        converted: stakingItem.amountConverted,
        price: stakingItem.price
      )
      self.balanceItem = balanceItem
    }
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
      amount: balanceItem.converted,
      maximumFractionDigits: 2,
      currency: balanceItem.currency
    )
    
    let model = TokenDetailsInformationView.Model(
      imageConfiguration: TKUIListItemImageIconView.Configuration(
        image: .image(
          .TKCore.Icons.Size44.tonLogo
        ),
        tintColor: .clear,
        backgroundColor: .clear,
        size: CGSize(width: 64, height: 64),
        cornerRadius: 32,
        contentMode: .scaleAspectFit,
        imageSize: CGSize(width: 64, height: 64)
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
    
    let configuration = balanceItemMapper.mapJettonItem(jettonBalanceItem, isSecure: false)
    didUpdateJettonItemView?(
      TKUIListItemButton.Model(
        listItemConfiguration: configuration,
        tapClosure: { [weak self] in
          guard let self else { return }
          self.openJettonDetails?(self.wallet, jettonBalanceItem.jetton)
        }
      )
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
        self?.didTapCollect?(wallet)
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
          action: { [weak self, wallet] in
            self?.didTapUnstake?(wallet)
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
