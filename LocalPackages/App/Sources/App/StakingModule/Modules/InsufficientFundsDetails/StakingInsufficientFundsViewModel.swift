import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

protocol StakingInsufficientFundsViewModuleOutput: AnyObject {
  var didTapBuy: ((Wallet) -> Void)? { get set }
}

protocol StakingInsufficientFundsViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}


final class StakingInsufficientFundsViewModelImplementation:
  StakingInsufficientFundsViewModel, StakingInsufficientFundsViewModuleOutput {
  
  
  // MARK: - StakingInsufficientFundsViewModuleOutput
  
  var didTapBuy: ((Wallet) -> Void)?
  
  // MARK: - StakingInsufficientFundsViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    let configuration = TKModalCardViewController.Configuration(
      header: makeHeader(),
      actionBar: makeActionBar()
    )
    
    didUpdateConfiguration?(configuration)
  }
  
  // MARK: - Dependencies
  
  private let amountFormatter: AmountFormatter
  private let fundsModel: StakingTransactionSendingStatus.InsufficientFunds
  
  init(
    fundsModel: StakingTransactionSendingStatus.InsufficientFunds,
    amountFormatter: AmountFormatter
  ) {
    self.fundsModel = fundsModel
    self.amountFormatter = amountFormatter
  }
}

// MARK: - Private methods

private extension StakingInsufficientFundsViewModelImplementation {
  func makeHeader() -> TKModalCardViewController.Configuration.Header {
    var items = [TKModalCardViewController.Configuration.Item]()
    
    let icon = makeHeaderIconView()
    items.append(.customView(icon, bottomSpacing: 16))
    
    let title = String.cardTitle(wallet: fundsModel.wallet).withTextStyle(.h3, color: .Text.primary, alignment: .center)
    let titleItem: TKModalCardViewController.Configuration.Item = .text(.init(text: title, numberOfLines: 0), bottomSpacing: 4)
    items.append(titleItem)
    
    let subtitle = makeSubtitle().withTextStyle(.body1, color: .Text.secondary, alignment: .center)
    let subtitleItem: TKModalCardViewController.Configuration.Item = .text(.init(text: subtitle, numberOfLines: 0), bottomSpacing: 20)
    items.append(subtitleItem)
    
    return .init(items: items)
  }
  
  func makeSubtitle() -> String {
    let estimatedFee = fundsModel.estimatedFee
    let token = fundsModel.token
    let estimatedFeeFormatted = amountFormatter.formatAmount(
      estimatedFee,
      fractionDigits: token.fractionDigits,
      maximumFractionDigits: token.fractionDigits,
      symbol: token.symbol
    )
    
    let withdrawFee = fundsModel.refundedAmount
    let withdrawFeeFormatted = amountFormatter.formatAmount(
      withdrawFee,
      fractionDigits: token.fractionDigits,
      maximumFractionDigits: token.fractionDigits,
      symbol: token.symbol
    )
    
    return .cardSubtitle(estimatedFee: estimatedFeeFormatted, withdrawFee: withdrawFeeFormatted)
  }
  
  func makeHeaderIconView() -> UIView {
    let view = UIView()
    
    let imageContainer = UIView()
    
    let imageView = UIImageView()
    imageView.image = .TKUIKit.Icons.Size32.exclamationmarkCircle
    imageView.contentMode = .scaleAspectFit
    imageView.tintColor = .Text.secondary
    
    imageContainer.layout(in: view) {
      $0.top.centerX.bottom.equalToSuperview()
    }
    
    imageView.layout(in: imageContainer) {
      $0.size.equalTo(64)
      $0.edges.equalToSuperview()
    }
    
    return view
  }
  
  func makeActionBar() -> TKModalCardViewController.Configuration.ActionBar {
    .init(
      items: [
        .button(
          TKModalCardViewController.Configuration.Button(
            title: "Buy",
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: { [weak self] _, _ in
              guard let self else { return }
              self.didTapBuy?(self.fundsModel.wallet)
            }
          ),
          bottomSpacing: 20
        )
      ]
    )
  }
}

private extension String {
  static func cardTitle(wallet: Wallet) -> String {
    let walletName = "\(wallet.metaData.emoji) \(wallet.metaData.label)"
    return "Insufficient funds\nin wallet \(walletName)"
  }
  
  static func cardSubtitle(estimatedFee: String, withdrawFee: String) -> String {
    "\(withdrawFee) needed for transaction. Estimated\nfee \(estimatedFee) will be deducted,\nthe rest will be refunded"
  }
}
