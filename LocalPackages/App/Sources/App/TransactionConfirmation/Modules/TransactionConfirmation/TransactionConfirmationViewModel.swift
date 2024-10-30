import UIKit
import TKUIKit
import TKLocalize
import KeeperCore
import BigInt

@MainActor
protocol TransactionConfirmationOutput: AnyObject {
  var didRequireSign: ((TransferMessageBuilder, Wallet) async throws -> String?)? { get set }
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
  
  var didRequireSign: ((TransferMessageBuilder, Wallet) async throws -> String?)?
  var didClose: (() -> Void)?
  
  // MARK: - TransactionConfirmationViewModel
  
  var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?
  
  func viewDidLoad() {
    confirmationController.signHandler = { [weak self] transferBuilder, wallet in
      try await self?.didRequireSign?(transferBuilder, wallet)
    }
    
    let model = confirmationController.getModel()
    update(with: model)
    Task {
      do {
        try await confirmationController.emulate().get()
        let model = confirmationController.getModel()
        update(with: model)
      } catch {
        ToastPresenter.showToast(configuration: .failed)
      }
    }
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
  
  // MARK: - Dependencies
  
  private let confirmationController: TransactionConfirmationController
  private let amountFormatter: AmountFormatter
  private let decimalFormatter: DecimalAmountFormatter
  
  // MARK: - Init
  
  init(confirmationController: TransactionConfirmationController,
       amountFormatter: AmountFormatter,
       decimalFormatter: DecimalAmountFormatter) {
    self.confirmationController = confirmationController
    self.amountFormatter = amountFormatter
    self.decimalFormatter = decimalFormatter
  }
  
  // MARK: - Private
  
  @MainActor
  private func update(with model: TransactionConfirmationModel) {
    var items = [TKPopUp.Item]()
    
    items.append(createHeaderImageItem(transaction: model))
    
    items.append(
      TKPopUp.Component.GroupComponent(
        padding: UIEdgeInsets(top: 0, left: 32, bottom: 32, right: 32),
        items: [
          TKPopUp.Component.LabelComponent(
            text: TKLocales.TransactionConfirmation.confirmAction.withTextStyle(
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
      items: [createListItem(transaction: model)]
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
          return "NFT name"
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
          image: .image(staking.pool.implementation.bigIcon),
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
      case .nft:
        return TKPopUp.Component.LabelComponent(text: "dsd".withTextStyle(.body3, color: .red))
      }
    }
  }
  
  private func createListItem(transaction: TransactionConfirmationModel) -> TKPopUp.Item {
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
    if let amountItem = createAmountItem(transaction: transaction) {
      items.append(amountItem)
    }
    if let apyItem = createAPYItem(transaction: transaction) {
      items.append(
        apyItem
      )
    }
    items.append(
      createFeeListItem(transaction: transaction)
    )
    
    let configuration = TKListContainerView.Configuration(
      items: items,
      copyToastConfiguration: .copied
    )
    return TKPopUp.Component.List(
      configuration: configuration,
      bottomSpace: 16
    )
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
  
  private func createAmountItem(transaction: TransactionConfirmationModel) -> TKListContainerItemView.Model? {
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
    
    let value: TKListContainerItemView.Model.Value
    let valueFormatted = formatValueItem(
      amount: transaction.amount.amount.value,
      fractionDigits: transaction.amount.amount.decimals,
      maximumFractionDigits: transaction.amount.amount.decimals,
      item: transaction.amount.amount.item
    )
    var convertedFormatted: String?
    if let converted = transaction.amount.converted {
      let formatted = formatValueItem(
        amount: converted.value,
        fractionDigits: converted.decimals,
        maximumFractionDigits: 2,
        item: converted.item
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
  
  private func createFeeListItem(transaction: TransactionConfirmationModel) -> TKListContainerItemView.Model {
    var copyValue: String?
    let value: TKListContainerItemView.Model.Value
    switch transaction.fee {
    case .loading:
      value = .loading
    case let .value(feeValue,
                    feeConverted,
                    isBattery):
      if let feeValue {
        let feeValueFormatted = formatValueItem(
          amount: feeValue.value,
          fractionDigits: feeValue.decimals,
          maximumFractionDigits: feeValue.decimals,
          item: feeValue.item
        )
        copyValue = feeValueFormatted
        var feeConvertedFormatted: String?
        if let feeConverted {
          let formatted = formatValueItem(
            amount: feeConverted.value,
            fractionDigits: feeConverted.decimals,
            maximumFractionDigits: 2,
            item: feeConverted.item
          )
          feeConvertedFormatted = "\(String.almostEqual) \(formatted)"
        }
        value = .value(TKListContainerItemDefaultValueView.Model(
          topValue: TKListContainerItemDefaultValueView.Model.Value(value: "\(String.almostEqual) \(feeValueFormatted)"),
          bottomValue: TKListContainerItemDefaultValueView.Model.Value(value: feeConvertedFormatted)
        ))
      } else {
        value = .value(TKListContainerItemDefaultValueView.Model(
          topValue: TKListContainerItemDefaultValueView.Model.Value(value: "?")
        ))
      }
    }
    
    return TKListContainerItemView.Model(
      title: TKLocales.EventDetails.fee,
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
        return "Confirm and Send"
      }
    }()
    
    var btnConf = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
    btnConf.content = .init(title: .plainString(buttonTitle))
    btnConf.action = { [weak self] in
      Task { [weak self] in
        guard let self else { return }
        self.state = .processing
        do {
          try await self.confirmationController.sendTransaction().get()
          self.state = .success
          NotificationCenter.default.postTransactionSendNotification(wallet: model.wallet)
        } catch {
          ToastPresenter.showToast(configuration: .failed)
          self.state = .failed
          try? await Task.sleep(nanoseconds: 1_500_000_000)
          self.state = .idle
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
      bottomSpace: 0
    )
    
    return component
  }
  
  private func formatValueItem(amount: BigUInt,
                               fractionDigits: Int,
                               maximumFractionDigits: Int,
                               item: TransactionConfirmationModel.Amount.Item) -> String {
    switch item {
    case .currency(let currency):
      return amountFormatter.formatAmount(
        amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: maximumFractionDigits,
        currency: currency
      )
    case .symbol(let string):
      return amountFormatter.formatAmount(
        amount,
        fractionDigits: fractionDigits,
        maximumFractionDigits: maximumFractionDigits,
        symbol: string
      )
    }
  }
}

private extension String {
  static let almostEqual = "\u{2248}"
}
