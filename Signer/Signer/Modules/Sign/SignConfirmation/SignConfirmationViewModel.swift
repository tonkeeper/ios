import Foundation
import SignerCore
import SignerLocalize
import UIKit
import TKUIKit
import TonSwift

protocol SignConfirmationModuleOutput: AnyObject {
  var didSignTransaction: ((URL, WalletKey, String) -> Void)? { get set }
  var didRequireConfirmation: (( @escaping (Bool) -> Void) -> Void)? { get set }
  var didOpenEmulateURL: ((URL) -> Void)? { get set }
}

protocol SignConfirmationViewModel: AnyObject {
  var didUpdateHeader: ((String, NSAttributedString?) -> Void)? { get set }
  var didUpdateModel: ((SignConfirmationView.Model) -> Void)? { get set }
  var didCancel: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didConfirmTransaction()
}

final class SignConfirmationViewModelImplementation: SignConfirmationViewModel, SignConfirmationModuleOutput {
  
  // MARK: - SignConfirmationModuleOutput

  var didSignTransaction: ((URL, WalletKey, String) -> Void)?
  var didRequireConfirmation: (( @escaping (Bool) -> Void) -> Void)?
  var didOpenEmulateURL: ((URL) -> Void)?
  
  // MARK: - SignConfirmationViewModel

  var didUpdateHeader: ((String, NSAttributedString?) -> Void)?
  var didUpdateModel: ((SignConfirmationView.Model) -> Void)?
  var didCancel: (() -> Void)?
  
  func viewDidLoad() {
    updateHeader()
    do {
      let transactionModel = try controller.getTransactionModel(
        sendTitle: SignerLocalize.SignTransaction.send
      )
      let model = createModel(transactionModel: transactionModel)
      
      didUpdateModel?(model)
    } catch {
      print("FAILED TO PARSE TRANSACTION")
    }
  }
  
  func didConfirmTransaction() {
    let completion: (Bool) -> Void = { [weak self] isConfirmed in
      guard let self else { return }
      if isConfirmed {
        guard let signedURL = self.controller.signTransaction() else { return }
        self.didSignTransaction?(signedURL, self.controller.walletKey, self.controller.hexBody)
      } else {
        self.didCancel?()
      }
    }
    didRequireConfirmation?(completion)
  }
  
  // MARK: - Dependencies
  
  private let controller: SignConfirmationController
  
  init(controller: SignConfirmationController) {
    self.controller = controller
  }
}

private extension SignConfirmationViewModelImplementation {
  func updateHeader() {
    let subtitle = NSMutableAttributedString()
    subtitle.append("\(controller.walletKey.name) ".withTextStyle(.body2, color: .Text.secondary))
    subtitle.append(controller.walletKey.publicKeyShortHexString.withTextStyle(.body2, color: .Text.tertiary))
    
    didUpdateHeader?(SignerLocalize.SignTransaction.title, subtitle)
  }
  
  func createModel(transactionModel: SignerCore.TransactionModel) -> SignConfirmationView.Model {
    let transactionsModel = SignConfirmationTransactionsView.Model(
      actions: transactionModel.items.map {
        transactionAction in
        SignConfirmationTransactionsView.Model.Action(
          configuration: SignConfirmationTransactionItemView.Model(
            contentConfiguration: TKUIListItemContentView.Configuration(
              leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
                title: transactionAction.title.withTextStyle(.label1, color: .Text.primary),
                tagViewModel: nil,
                subtitle: transactionAction.subtitle.withTextStyle(.body2, color: .Text.secondary),
                description: nil
              ),
              rightItemConfiguration: TKUIListItemContentRightItem.Configuration(
                value: transactionAction.value?.withTextStyle(.label1, color: .Text.primary),
                subtitle: transactionAction.valueSubtitle?.withTextStyle(.body2, color: .Text.tertiary),
                description: nil
              )
            ),
            commentConfiguration: SignConfirmationTransactionItemCommentView.Model(
              comment: transactionAction.comment?.withTextStyle(.body2, color: .Text.primary)
            )
          )
        )
      }
    )
    
    var emulateButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .tertiary,
      size: .small
    )
    emulateButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(SignerLocalize.SignTransaction.emulate))
    emulateButtonConfiguration.action = { [weak self] in
      guard let url = self?.controller.createEmulationURL() else { return }
      self?.didOpenEmulateURL?(url)
    }
    
    var copyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .tertiary,
      size: .small
    )
    copyButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString(SignerLocalize.SignTransaction.copy))
    copyButtonConfiguration.action = { [weak self] in
      guard let self else { return }
      UIPasteboard.general.string = self.controller.hexBody
      ToastPresenter.showToast(configuration: .Signer.copied)
    }
    
    let bocModel = SignConfirmationBocView.Model(
      boc: transactionModel.boc,
      emulateButtonConfiguration: emulateButtonConfiguration,
      copyButtonConfiguration: copyButtonConfiguration
    )
    
    return SignConfirmationView.Model(
      transactionsModel: transactionsModel,
      bocModel: bocModel,
      auditButtonText: SignerLocalize.SignTransaction.audit_transaction
    )
  }
}

public extension Address {
  func toShortString(bounceable: Bool) -> String {
    let string = self.toString(bounceable: bounceable)
    let leftPart = string.prefix(4)
    let rightPart = string.suffix(4)
    return "\(leftPart)...\(rightPart)"
  }
}
