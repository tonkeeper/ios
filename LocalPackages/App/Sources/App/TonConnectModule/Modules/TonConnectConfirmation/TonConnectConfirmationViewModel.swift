import Foundation
import KeeperCore
import TKCore
import UIKit
import TKUIKit
import TKLocalize
import BigInt

protocol TonConnectConfirmationModuleOutput: AnyObject {
  var didTapConfirmButton: (() async -> Bool)? { get set }
  var didTapCancelButton: (() -> Void)?  { get set }
  var didConfirm: (() -> Void)? { get set }
  var didTapRiskInfo: ((_ total: String, _ caption: String) -> Void)? { get set }
}

protocol TonConnectConfirmationViewModel: AnyObject {
  var contentView: ((TonConnectConfirmationContentView.Model) -> TonConnectConfirmationContentView)? { get set }
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  var didUpdateHeader: ((String, NSAttributedString?) -> Void)? { get set }
  
  func viewDidLoad()
}

final class TonConnectConfirmationViewModelImplementation: TonConnectConfirmationViewModel, TonConnectConfirmationModuleOutput {
  
  // MARK: - TonConnectConfirmationModuleOutput
  
  var didTapConfirmButton: (() async -> Bool)?
  var didTapCancelButton: (() -> Void)?
  var didConfirm: (() -> Void)?
  var didTapRiskInfo: ((_ title: String, _ caption: String) -> Void)?

  // MARK: - TonConnectConfirmationViewModel
  
  var contentView: ((TonConnectConfirmationContentView.Model) -> TonConnectConfirmationContentView)?
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  var didUpdateHeader: ((String, NSAttributedString?) -> Void)?
  
  func viewDidLoad() {
    let wallet = "\(TKLocales.ConfirmSend.wallet): ".withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    let walletName = model.wallet.iconWithName(
      attributes: TKTextStyle.body2.getAttributes(
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      ),
      iconColor: .Icon.primary,
      iconSide: 16
    )
    let subtitle = NSMutableAttributedString(attributedString: wallet)
    subtitle.append(walletName)

    didUpdateHeader?(
      TKLocales.ConfirmSend.TokenTransfer.title,
      subtitle
    )
    prepareContent()
  }
  
  // MARK: - Dependencies
  
  private let model: ConfirmTransactionModel
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let totalBalanceStore: TotalBalanceStore
  private let historyEventMapper: HistoryEventMapper

  private let decimalAmountFormatter: DecimalAmountFormatter

  init(model: ConfirmTransactionModel,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       totalBalanceStore: TotalBalanceStore,
       decimalAmountFormatter: DecimalAmountFormatter,
       historyEventMapper: HistoryEventMapper
  ) {
    self.model = model
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.totalBalanceStore = totalBalanceStore
    self.decimalAmountFormatter = decimalAmountFormatter
    self.historyEventMapper = historyEventMapper
  }
}

private extension TonConnectConfirmationViewModelImplementation {

  func prepareContent() {
    var contentItems = [TKModalCardViewController.Configuration.ContentItem]()
    if let contentItem = contentItem() {
      contentItems.append(.item(contentItem))
    }
    
    var actionBarItems: [TKModalCardViewController.Configuration.Item] = [
      .buttonsRow(.init(buttons: [
        cancelButton(),
        confirmButton()
      ]), bottomSpacing: 8, itemSpacing: 8)
    ]

    if let riskItem = createRiskItem() {
      actionBarItems.append(.customView(riskItem, bottomSpacing: 8))
    }

    let configuration = TKModalCardViewController.Configuration(
      header: nil,
      content: .init(items: contentItems, copyToastConfiguration: .copied),
      actionBar: .init(items: actionBarItems)
    )
    didUpdateConfiguration?(configuration)
  }

  func confirmButton() -> TKModalCardViewController.Configuration.Button {
    TKModalCardViewController.Configuration.Button(
      title: TKLocales.ConfirmSend.confirm,
      size: .large,
      category: .primary,
      isEnabled: true,
      isActivity: false,
      tapAction: { [weak self] isActivityClosure, isSuccessClosure in
        guard let self = self else { return }
        isActivityClosure(true)
        Task {
          let isSuccess = await self.didTapConfirmButton?() ?? false
          await MainActor.run {
            isSuccessClosure(isSuccess)
          }
        }
      },
      completionAction: { [weak self] isSuccess in
        guard isSuccess else { return }
        self?.didConfirm?()
      })
  }
  
  func cancelButton() -> TKModalCardViewController.Configuration.Button {
    TKModalCardViewController.Configuration.Button(
      title: TKLocales.Actions.cancel,
      size: .large,
      category: .secondary,
      isEnabled: true,
      isActivity: false,
      tapAction: { [weak self] _, _ in
        self?.didTapCancelButton?()
      },
      completionAction: { [weak self] _ in
        self?.didTapCancelButton?()
      })
  }

  func createRiskItem() -> UIView? {
    let tonRates = tonRatesStore.state
    let tonRisk = model.risk.ton
    let currency = currencyStore.state
    let totalRisk = tonRisk + model.fee

    guard let totalBalanceState = totalBalanceStore.state[model.wallet],
          let totalBalance = totalBalanceState.totalBalance,
          let rate = tonRates.first(with: currency, at: \.currency)
    else {
      return nil
    }

    let convertedTonRisk = RateConverter().convertToDecimal(
      amount: BigUInt(totalRisk),
      amountFractionLength: TonInfo.fractionDigits,
      rate: rate
    )
    let riskLowMark = totalBalance.amount * 0.2
    let isRisk = convertedTonRisk >= riskLowMark
    let totalFormatted = decimalAmountFormatter.format(
      amount: convertedTonRisk,
      maximumFractionDigits: 2,
      currency: currency
    )

    let formattedTitle: String
    let caption: String
    if model.risk.nfts.isEmpty {
      formattedTitle = TKLocales.ConfirmSend.Risk.total(totalFormatted)
      caption = TKLocales.ConfirmSend.Risk.captionWithoutNft
    } else {
      formattedTitle = TKLocales.ConfirmSend.Risk.totalNft(totalFormatted, model.risk.nfts.count)
      caption = TKLocales.ConfirmSend.Risk.nftCaption
    }

    let riskView = TonConnectRiskView()
    riskView.configure(model: TonConnectRiskView.Model(
      title: formattedTitle,
      isRisk: isRisk
    ) { [weak self] in
      self?.didTapRiskInfo?(formattedTitle, caption)
    })

    return riskView
  }

  func contentItem() -> TKModalCardViewController.Configuration.Item? {
    let model = TonConnectConfirmationContentView.Model(
      actionsConfiguration: mapEvent(model.event),
      feeModel: .init(title: TKLocales.ConfirmSend.fee, fee: model.formattedFee)
    )
    guard let view = contentView?(model) else { return nil }
    return .customView(view, bottomSpacing: 32)
  }
  
  func mapEvent(_ event: AccountEventModel) -> HistoryCellContentView.Model {
    return historyEventMapper.mapEventContentConfiguration(
      event,
      isSecureMode: false,
      nftAction: { _ in },
      encryptedCommentAction: { _ in
        
      },
      tapAction: { _ in }
    )
  }
}
