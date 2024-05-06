import Foundation
import SignerCore
import UIKit
import TKUIKit
import TonSwift

protocol SignConfirmationModuleOutput: AnyObject {
  var didSignTransaction: ((URL, WalletKey, String) -> Void)? { get set }
}

protocol SignConfirmationViewModel: AnyObject {
  var didUpdateHeader: ((String, NSAttributedString?) -> Void)? { get set }
  var didUpdateModel: ((SignConfirmationView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func didConfirmTransaction()
}

final class SignConfirmationViewModelImplementation: SignConfirmationViewModel, SignConfirmationModuleOutput {
  
  // MARK: - SignConfirmationModuleOutput

  var didSignTransaction: ((URL, WalletKey, String) -> Void)?
  
  // MARK: - SignConfirmationViewModel

  var didUpdateHeader: ((String, NSAttributedString?) -> Void)?
  var didUpdateModel: ((SignConfirmationView.Model) -> Void)?
  
  func viewDidLoad() {
    updateHeader()
    
    do {
      let transactionModel = try controller.getTransactionModel()
      let model = createModel(transactionModel: transactionModel)
      
      didUpdateModel?(model)
    } catch {
      print("FAILED TO PARSE TRANSACTION")
    }
  }
  
  func didConfirmTransaction() {
    guard let signedURL = controller.signTransaction() else { return }
    didSignTransaction?(signedURL, controller.walletKey, controller.hexBody)
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
    
    didUpdateHeader?("Sign Transaction", subtitle)
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
    emulateButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Emulate in Browser"))
    emulateButtonConfiguration.action = { }
    
    var copyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .tertiary,
      size: .small
    )
    copyButtonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Copy"))
    
    let bocModel = SignConfirmationBocView.Model(
      boc: transactionModel.boc,
      emulateButtonConfiguration: emulateButtonConfiguration,
      copyButtonConfiguration: copyButtonConfiguration
    )
    
    return SignConfirmationView.Model(
      transactionsModel: transactionsModel,
      bocModel: bocModel,
      auditButtonText: "Audit Transaction"
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
