import UIKit
import TKUIKit
import KeeperCore
import BigInt

final class StakingDepositInputAPYViewController: UIViewController, StakingInputDetailsModuleInput {
    
  private var selectedStackingPoolInfo: StackingPoolInfo?
  private var balanceItem: BalanceStakingItemModel?
  
  private let stackView = UIStackView()
  private let headerView = TKListTitleView()
  private let listView = StakingDetailsListView()
  
  private let wallet: Wallet
  private let balanceStore: ConvertedBalanceStoreV3
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  
  init(wallet: Wallet,
       balanceStore: ConvertedBalanceStoreV3,
       amountFormatter: AmountFormatter,
       decimalFormatter: DecimalAmountFormatter) {
    self.wallet = wallet
    self.balanceStore = balanceStore
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    stackView.axis = .vertical
    
    view.addSubview(stackView)
    stackView.addArrangedSubview(headerView)
    stackView.addArrangedSubview(listView)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
    
    headerView.snp.makeConstraints { make in
      make.height.equalTo(48)
    }
  }
  
  func configureWith(stackingPoolInfo: StackingPoolInfo,
                     tonAmount: BigUInt,
                     isMostProfitable: Bool) {
    self.selectedStackingPoolInfo = stackingPoolInfo
    guard let balance = balanceStore.getState()[wallet]?.balance else {
      return
    }
    
    guard let balanceItem = createBalanceItem(balance: balance) else {
      return
    }
    
    let afterStakeAPY = calculateAPY(amount: tonAmount + BigUInt(UInt64(balanceItem.info.amount)), apy: stackingPoolInfo.apy)
    let afterStakeAPYFormatted = amountFormatter.formatAmount(
      afterStakeAPY.0,
      fractionDigits: afterStakeAPY.1,
      maximumFractionDigits: 4,
      symbol: TonInfo.symbol
    )

    let currentAPY = calculateAPY(amount: BigUInt(UInt64(balanceItem.info.amount)), apy: stackingPoolInfo.apy)
    let currentAPYFormatted = amountFormatter.formatAmount(
      currentAPY.0,
      fractionDigits: currentAPY.1,
      maximumFractionDigits: 4,
      symbol: TonInfo.symbol
    )

    let listModel = StakingDetailsListView.Model(
      items: [
        StakingDetailsListView.ItemView.Model(
          title: "After stake".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          tag: nil,
          value: "≈ \(afterStakeAPYFormatted)".withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
        ),
        StakingDetailsListView.ItemView.Model(
          title: "Current".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          tag: nil,
          value: "≈ \(currentAPYFormatted)".withTextStyle(.body2, color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail)
        )
      ]
    )
    
    DispatchQueue.main.async {
      self.headerView.configure(model: TKListTitleView.Model(title: "Your APY", textStyle: .label1))
      self.listView.configure(model: listModel)
    }
    
    func calculateAPY(amount: BigUInt, apy: Decimal) -> (BigUInt, Int) {
      let apyFractionLength = max(Int16(-apy.exponent), 0)
      let apyPlain = NSDecimalNumber(decimal: apy)
        .multiplying(byPowerOf10: apyFractionLength)
      let apyBigInt = BigUInt(stringLiteral: apyPlain.stringValue)
      
      let fractionLength = Int(apyFractionLength) + TonInfo.fractionDigits
      let result = amount / 100 * apyBigInt
      return (result, fractionLength)
    }
  }
}

private extension StakingDepositInputAPYViewController {
  func createBalanceItem(balance: ConvertedBalance) -> BalanceStakingItemModel? {
    guard let stakingPoolInfo = selectedStackingPoolInfo else { return nil }
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
        pendingDeposit: 0,
        pendingWithdraw: 0,
        readyWithdraw: 0
      )
      
      let stakingItem = BalanceStakingItemModel(
        id: info.pool.toRaw(),
        info: info,
        poolInfo: stakingPoolInfo,
        currency: balance.currency,
        converted: stakingPoolJetton.converted,
        price: stakingPoolJetton.price
      )
      
      return stakingItem
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
      return balanceItem
    }
    
    return nil
  }
}
