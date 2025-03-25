import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import BigInt

@MainActor
protocol TransactionConfirmationOutput: AnyObject {
  var didRequireSign: ((TransferData, Wallet) async throws -> SignedTransactions?)? { get set }
  var didConfirmTransaction: (() -> Void)? { get set }
  var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)? { get set }
  var didClose: (() -> Void)? { get set }
}

@MainActor
public protocol TransactionConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }
  func viewDidLoad()
  func didTapCloseButton()
}

@MainActor
final class TransactionConfirmationViewModelImplementation: TransactionConfirmationViewModel, TransactionConfirmationOutput {
  
  // MARK: - TransactionConfirmationOutput
  
  var didRequireSign: ((TransferData, Wallet) async throws -> SignedTransactions?)?
  var didConfirmTransaction: (() -> Void)?
  var didProduceInsufficientFundsError: ((_ error: InsufficientFundsError) -> Void)?
  var didClose: (() -> Void)?
  
  // MARK: - TransactionConfirmationViewModel
  
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
  
  func viewDidLoad() {
    confirmationController.signHandler = { [weak self] transferData, wallet in
      try await self?.didRequireSign?(transferData, wallet)
    }

    state = .processing
    update()
  }
  
  func didTapCloseButton() {
    didClose?()
  }
  
  // MARK: - State
  
  private enum State {
    case idle
    case processing
    case success
    case failed
  }
  
  private var state: State = .idle {
    didSet {
      let model = confirmationController.getModel()
      update(with: model)
    }
  }
  private var amountRate: Rates.Rate?
  private var feeRate: Rates.Rate?
  
  private var updateTask: Task<Void, Never>?
  
  // MARK: - Dependencies
  
  private let confirmationController: TransactionConfirmationController
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  private let fundsValidator: InsufficientFundsValidator
  private let currencyStore: CurrencyStore
  private let ratesService: RatesService

  // MARK: - Init
  
  init(confirmationController: TransactionConfirmationController,
       amountFormatter: AmountFormatter,
       decimalFormatter: DecimalAmountFormatter,
       fundsValidator: InsufficientFundsValidator,
       currencyStore: CurrencyStore,
       ratesService: RatesService) {
    self.confirmationController = confirmationController
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
    self.fundsValidator = fundsValidator
    self.currencyStore = currencyStore
    self.ratesService = ratesService
  }
  
  // MARK: - Private
  
  private func update() {
    self.updateTask?.cancel()
    self.updateTask = Task {
      self.state = .idle
      let result = await confirmationController.emulate()
      if case let .failure(error) = result {
       handleError(error)
      }
      let model = confirmationController.getModel()
      let currency = currencyStore.state
      let rates = await getRates(model: model, currency: currency)
      guard !Task.isCancelled else { return }
      self.amountRate = rates.valueRate
      self.feeRate = rates.feeRate
      update(with: model)
      
      do {
        try await fundsValidator.validateFundsIfNeeded(wallet: model.wallet, emulationModel: model)
      } catch {
        guard !Task.isCancelled else { return }
        if let error = error as? InsufficientFundsError {
          didProduceInsufficientFundsError?(error)
        }
      }
    }
  }
  
  @MainActor
  private func update(with model: TransactionConfirmationModel) {
    let currency = currencyStore.state
    
    var items = [TKPopUp.Item]()
    
    items.append(createHeaderImageItem(transaction: model))
    
    let caption: String = {
      switch model.transaction {
      case .staking:
        return TKLocales.TransactionConfirmation.confirmAction
      case .transfer(let transfer):
        switch transfer {
        case .jetton, .ton:
          return TKLocales.TransactionConfirmation.confirmAction
        case .nft(let nft):
          var result = nft.notNilName
          if let collectionName = nft.collection?.notEmptyName {
            result += " · "
            result += collectionName
          }
          return result
        }
      }
    }()
    items.append(
      TKPopUp.Component.GroupComponent(
        padding: UIEdgeInsets(top: 0, left: 32, bottom: 32, right: 32),
        items: [
          TKPopUp.Component.LabelComponent(
            text: caption.withTextStyle(
              .body1,
              color: .Text.secondary,
              alignment: .center,
              lineBreakMode: .byTruncatingTail),
            numberOfLines: 1,
            bottomSpace: 4
          ),
          createActionNameItem(transaction: model.transaction)
        ]
      )
    )
    items.append(TKPopUp.Component.GroupComponent(
      padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
      items: [createListItem(transaction: model, amountRate: amountRate, feeRate: feeRate, currency: currency)]
    ))
    
    let bottomItems: [TKPopUp.Item] = [
      createActionBar(model: model)
    ]
    
    let configuration = TKPopUp.Configuration(items: items,
                                              bottomItems: bottomItems)
    
    didUpdateConfiguration?(configuration)
  }
  
  private func createActionNameItem(transaction: TransactionConfirmationModel.Transaction) -> TKPopUp.Item {
    let text: String = {
      switch transaction {
      case .staking(let staking):
        switch staking.flow {
        case .withdraw:
          return TKLocales.TransactionConfirmation.unstake
        case .deposit:
          return TKLocales.TransactionConfirmation.deposit
        }
      case .transfer(let transfer):
        switch transfer {
        case .jetton(let jettonInfo):
          return "\(jettonInfo.symbol ?? jettonInfo.name) transfer"
        case .ton:
          return "\(TonInfo.symbol) transfer"
        case .nft:
          return "NFT transfer"
        }
      }
    }()
    return TKPopUp.Component.LabelComponent(
      text: text.withTextStyle(
        .h3,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail),
      numberOfLines: 1,
      bottomSpace: 0
    )
  }
  
  private func createHeaderImageItem(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
    switch transaction.transaction {
    case .staking(let staking):
      return TKPopUp.Component.ImageComponent(
        image: TKImageView.Model(
          image: .image(staking.pool.bigIcon),
          size: .size(CGSize(width: 96, height: 96)),
          corners: .circle,
          padding: .zero
        ),
        bottomSpace: 20
      )
    case .transfer(let transfer):
      switch transfer {
      case .jetton(let jettonInfo):
        return TKPopUp.Component.ImageComponent(
          image: TKImageView.Model(
            image: .urlImage(jettonInfo.imageURL),
            size: .size(CGSize(width: 96, height: 96)),
            corners: .circle,
            padding: .zero
          ),
          bottomSpace: 20
        )
      case .ton:
        return TKPopUp.Component.ImageComponent(
          image: TKImageView.Model(
            image: .image(.TKUIKit.Icons.Size96.tonIcon),
            size: .size(CGSize(width: 96, height: 96)),
            corners: .circle,
            padding: .zero
          ),
          bottomSpace: 20
        )
      case .nft(let nft):
        return TKPopUp.Component.ImageComponent(
          image: TKImageView.Model(
            image: .urlImage(nft.imageURL),
            size: .size(CGSize(width: 96, height: 96)),
            corners: .cornerRadius(cornerRadius: 12),
            padding: .zero
          ),
          bottomSpace: 20
        )
      }
    }
  }
  
  private func createListItem(transaction: TransactionConfirmationModel,
                              amountRate: Rates.Rate?,
                              feeRate: Rates.Rate?,
                              currency: Currency) -> TKPopUp.Item {
    var items = [TKListContainerItem]()
    
    items.append(
      createWalletItem(transaction: transaction)
    )
    if let recipientItem = createRecipientItem(transaction: transaction) {
      items.append(recipientItem)
    }
    if let recipientAddress = createRecipientAddresItem(transaction: transaction) {
      items.append(recipientAddress)
    }
    if let amountItem = createAmountItem(transaction: transaction, rate: amountRate, currency: currency) {
      items.append(amountItem)
    }
    if let apyItem = createAPYItem(transaction: transaction) {
      items.append(
        apyItem
      )
    }
    items.append(
      createFeeListItem(transaction: transaction, rate: feeRate, currency: currency)
    )
    if let commentItem = createCommentItem(transaction: transaction) {
      items.append(commentItem)
    }
    
    let configuration = TKListContainerView.Configuration(
      items: items,
      copyToastConfiguration: .copied
    )
    return TKPopUp.Component.List(
      configuration: configuration,
      bottomSpace: 16
    )
  }
  
  private func handleError(_ error: TransactionConfirmationError) {
    let text: String
    switch error {
    case .failedToCalculateFee:
      text = "Failed to calculate fee"
    case .failedToSendTransaction:
      text = "Failed to send transaction"
    case .failedToSign:
      text = "Failed to sign"
    }
    
    ToastPresenter.showToast(configuration: .defaultConfiguration(text: text))
  }
  
  private func createWalletItem(transaction: TransactionConfirmationModel) -> TKListContainerItemView.Model {
    return TKListContainerItemView.Model(
      title: TKLocales.TransactionConfirmation.wallet,
      value: .value(
        TransactionConfirmationListContainerItemWalletValueView.Configuration(
          wallet: transaction.wallet
        )
      ),
      action: nil
    )
  }
  
  private func createRecipientItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
    guard let recipient = transaction.recipient else { return nil }
    return TKListContainerItemView.Model(
      title: TKLocales.TransactionConfirmation.recipient,
      value: .value(
        TKListContainerItemDefaultValueView.Model(
          topValue: TKListContainerItemDefaultValueView.Model.Value(value: recipient)
        )
      ),
      action: .copy(copyValue: recipient)
    )
  }
  
  private func createRecipientAddresItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
    guard let recipientAddress = transaction.recipientAddress else { return nil }
    return TKListContainerFullValueItemItem(
      title: TKLocales.TransactionConfirmation.recipient,
      value: recipientAddress,
      copyValue: recipientAddress
    )
  }
  
  private func createCommentItem(transaction: TransactionConfirmationModel) -> TKListContainerItem? {
    guard let comment = transaction.comment, !comment.isEmpty else { return nil }
    return TKListContainerItemView.Model(
      title: TKLocales.TransactionConfirmation.comment,
      value: .value(
        TKListContainerItemDefaultValueView.Model(
          topValue: TKListContainerItemDefaultValueView.Model.Value(value: comment)
        )
      ),
      action: .copy(copyValue: comment)
    )
  }
  
  private func createAPYItem(transaction: TransactionConfirmationModel) -> TKListContainerItemView.Model? {
    guard case let .staking(staking) = transaction.transaction,
          case .deposit = staking.flow else { return nil }
    
    let apyPercents = decimalFormatter.format(amount: staking.pool.apy, maximumFractionDigits: 2)
    let value = "\(String.almostEqual) \(apyPercents)%"
    return TKListContainerItemView.Model(
      title: TKLocales.TransactionConfirmation.apy,
      value: .value(
        TKListContainerItemDefaultValueView.Model(
          topValue: TKListContainerItemDefaultValueView.Model.Value(value: value)
        )
      ),
      action: .copy(copyValue: apyPercents)
    )
  }
  
  private func createAmountItem(transaction: TransactionConfirmationModel,
                                rate: Rates.Rate?,
                                currency: Currency) -> TKListContainerItemView.Model? {
    let title: String
    switch transaction.transaction {
    case .staking(let staking):
      switch staking.flow {
      case .withdraw:
        title = TKLocales.TransactionConfirmation.unstakeAmount
      case .deposit:
        title = TKLocales.TransactionConfirmation.amount
      }
    case .transfer(let transfer):
      switch transfer {
      case .jetton, .ton:
        title = TKLocales.TransactionConfirmation.amount
      case .nft:
        return nil
      }
    }
    
    guard let amount = transaction.amount else { return nil }
    
    let value: TKListContainerItemView.Model.Value
    let valueFormatted = formatValueItem(
      amount: amount.value,
      fractionDigits: amount.token.fractionDigits,
      maximumFractionDigits: amount.token.fractionDigits,
      symbol: amount.token.symbol
    )
    var convertedFormatted: String?
    if let rate {
      let converted = RateConverter().convert(
        amount: amount.value,
        amountFractionLength: amount.token.fractionDigits,
        rate: rate
      )
      let formatted = formatValueItem(
        amount: converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        symbol: currency.symbol
      )
      convertedFormatted = formatted
    }
    value = .value(TKListContainerItemDefaultValueView.Model(
      topValue: TKListContainerItemDefaultValueView.Model.Value(value: valueFormatted),
      bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: convertedFormatted)
    ))
    
    return TKListContainerItemView.Model(
      title: title,
      value: value,
      action: .copy(copyValue: valueFormatted)
    )
  }
  
  private func createFeeListItem(transaction: TransactionConfirmationModel,
                                 rate: Rates.Rate?,
                                 currency: Currency) -> TKListContainerItemView.Model {
    var copyValue: String?
    var caption: NSAttributedString?
    var captionButton: TKPlainButton.Model?
    var isRefund: Bool = false
    let value: TKListContainerItemView.Model.Value
    switch transaction.extraState {
    case .loading:
      value = .loading
    case .extra(let extra):
      let (amount, type, refund) = {
        switch extra {
        case .Refund(let amount, let type):
          return (amount, type, true)
        case .Fee(let amount, let type):
          return (amount, type, false)
        }
      }()
      
      isRefund = refund
      
      let feeValueFormatted = formatValueItem(
        amount: amount.value,
        fractionDigits: amount.token.fractionDigits,
        maximumFractionDigits: amount.token.fractionDigits,
        symbol: amount.token.symbol
      )
      copyValue = feeValueFormatted
      var feeConvertedFormatted: String?
      if let rate {
        let converted = RateConverter().convert(
          amount: amount.value,
          amountFractionLength: amount.token.fractionDigits,
          rate: rate
        )
        let formatted = formatValueItem(
          amount: converted.amount,
          fractionDigits: converted.fractionLength,
          maximumFractionDigits: 2,
          symbol: currency.symbol
        )
        feeConvertedFormatted = formatted
      }
      value = .value(TKListContainerItemDefaultValueView.Model(
        topValue: TKListContainerItemDefaultValueView.Model.Value(value: "\(String.almostEqual) \(feeValueFormatted)"),
        bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: feeConvertedFormatted)
      ))
      
      
      switch type {
      case .default:
        caption = nil
        captionButton = nil
      case .battery:
        caption = TKLocales.TransactionConfirmation.battery.withTextStyle(.body2, color: .Text.tertiary)
        captionButton = nil
      case .gasless(let toggleOption):
        caption = nil
        let captionButtonTitle: String = {
          switch toggleOption {
          case .ton:
            return TKLocales.TransactionConfirmation.tapToPay(TonInfo.symbol)
          case .jetton(let jettonItem):
            return TKLocales.TransactionConfirmation.tapToPay(jettonItem.jettonInfo.symbol ?? jettonItem.jettonInfo.name)
          }
        }()
        captionButton = TKPlainButton.Model(title: captionButtonTitle.withTextStyle(.body2, color: .Text.tertiary), action: { [weak self] in
          self?.confirmationController.toggleIsPreferGasless()
          self?.update()
        })
      }
    case .none:
      value = .value(TKListContainerItemDefaultValueView.Model(
        topValue: TKListContainerItemDefaultValueView.Model.Value(value: "?")
      ))
    }
    return TKListContainerItemView.Model(
      title: isRefund ? TKLocales.EventDetails.refund : TKLocales.EventDetails.fee,
      caption: caption,
      captionButtonModel: captionButton,
      value: value,
      action: .copy(copyValue: copyValue)
    )
  }
  
  private func createActionBar(model: TransactionConfirmationModel) -> TKPopUp.Item {
    let buttonTitle: String = {
      switch model.transaction {
      case .staking(let staking):
        switch staking.flow {
        case .deposit:
          return TKLocales.TransactionConfirmation.Buttons.confirmAndStake
        case let .withdraw(isCollect):
          if isCollect {
            return TKLocales.TransactionConfirmation.Buttons.confirmAndUnstake
          } else {
            return TKLocales.TransactionConfirmation.Buttons.confirmAndCollect
          }
        }
      case .transfer:
        return TKLocales.TransactionConfirmation.Buttons.confirmAndSend
      }
    }()

    var btnConf = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    btnConf.content = .init(title: .plainString(buttonTitle))
    btnConf.action = { [weak self] in
      Task { [weak self] in
        guard let self else { return }

        self.state = .processing
        
        do {
          try await fundsValidator.validateFundsIfNeeded(wallet: model.wallet, emulationModel: model)

          let result = await self.confirmationController.sendTransaction()
          switch result {
          case .success:
            self.state = .success
            try await Task.sleep(nanoseconds: 1_000_000_000)
            NotificationCenter.default.postTransactionSendNotification(wallet: model.wallet)
            didConfirmTransaction?()
          case .failure(let error):
            handleError(error)
            self.state = .failed
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.state = .idle
          }
        } catch {
          self.state = .failed
          try? await Task.sleep(nanoseconds: 1_500_000_000)
          self.state = .idle

          if let error = error as? InsufficientFundsError {
            didProduceInsufficientFundsError?(error)
          }
        }
      }
    }
    
    let itemState: TKProcessContainerView.State = {
      switch state {
      case .idle:
        return .idle
      case .processing:
        return .process
      case .success:
        return .success
      case .failed:
        return .failed
      }
    }()
    
    let component = TKPopUp.Component.Process(
      items: [
        TKPopUp.Component.ButtonGroupComponent(buttons: [
          TKPopUp.Component.ButtonComponent(buttonConfiguration: btnConf)
        ])
      ],
      state: itemState,
      successTitle: TKLocales.Result.success,
      errorTitle: TKLocales.Result.failure,
      bottomSpace: 0
    )
    
    return component
  }
  
  private func formatValueItem(amount: BigUInt,
                               fractionDigits: Int,
                               maximumFractionDigits: Int,
                               symbol: String) -> String {
    amountFormatter.formatAmount(
      amount,
      fractionDigits: fractionDigits,
      maximumFractionDigits: maximumFractionDigits,
      symbol: symbol
    )
  }
  
  private func getRates(model: TransactionConfirmationModel,
                        currency: Currency) async -> (valueRate: Rates.Rate?, feeRate: Rates.Rate?) {
    let valueToken = model.amount?.token
    let feeToken: Token? = {
      switch model.extraState {
      case .loading:
        return nil
      case let .extra(extra):
        switch extra {
        case .Fee(let amount, _), .Refund(let amount, _):
          return amount.token
        }
      case .none:
        return nil
      }
    }()

    let jettons: [JettonInfo] = [valueToken, feeToken].compactMap { token -> JettonInfo? in
      switch token {
      case .ton:
        return nil
      case .jetton(let jettonItem):
        return jettonItem.jettonInfo
      case nil:
        return nil
      }
    }
    
    do {
      let rates = try await ratesService.loadRates(jettons: jettons, currencies: [currency])
      let valueRate = {
        switch valueToken {
        case .ton:
          return rates.ton.first(where: { $0.currency == currency })
        case .jetton(let jettonItem):
          return rates.jettonsRates.first(where: { $0.jettonInfo == jettonItem.jettonInfo })?.rates.first(where: { $0.currency == currency })
        case nil:
          return nil
        }
      }()
      let feeRate = {
        switch feeToken {
        case .ton:
          return rates.ton.first(where: { $0.currency == currency })
        case .jetton(let jettonItem):
          return rates.jettonsRates.first(where: { $0.jettonInfo == jettonItem.jettonInfo })?.rates.first(where: { $0.currency == currency })
        case nil:
          return nil
        }
      }()
      
      return (valueRate, feeRate)
    } catch {
      return (nil, nil)
    }
  }
}

private extension String {
  static let almostEqual = "\u{2248}"
}
