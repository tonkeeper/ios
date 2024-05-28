import UIKit
import TKUIKit
import KeeperCore
import TonSwift
import BigInt

protocol LinkDNSModuleOutput: AnyObject {
  var didCancel: (() -> Void)? { get set }
  var didTapConfirmButton: ((_ dnsLink: DNSLink) async -> Bool)? { get set }
  var didLink: (() -> Void)? { get set }
}

protocol LinkDNSViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  var title: String { get set }
  
  func viewDidLoad()
}

final class LinkDNSViewModelImplementation: LinkDNSViewModel, LinkDNSModuleOutput {
  
  // MARK: - LinkDNSModuleOutput
  
  var didCancel: (() -> Void)?
  var didTapConfirmButton: ((_ dnsLink: DNSLink) async -> Bool)?
  var didLink: (() -> Void)?
  
  // MARK: - LinkDNSViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  var title: String
  
  func viewDidLoad() {
    let model = buildModalCardModel(model: model)
    didUpdateConfiguration?(model)
  }
  
  // MARK: - Dependencies
  
  private let model: SendTransactionModel
  private var dnsLink: DNSLink
  private let amountFormatter: KeeperCore.AmountFormatter
  
  // MARK: - Init
  
  init(model: SendTransactionModel,
       dnsLink: DNSLink,
       amountFormatter: KeeperCore.AmountFormatter) {
    self.model = model
    self.dnsLink = dnsLink
    self.amountFormatter = amountFormatter
    switch dnsLink {
    case .link(let address):
      title = "Confirm Transaction"
    case .unlink:
      title = "Confirm unlink"
    }
  }
}

private extension LinkDNSViewModelImplementation {
  func buildModalCardModel(model: SendTransactionModel) -> TKModalCardViewController.Configuration {
    
    var items = [TKModalCardViewController.Configuration.ListItem]()
    switch dnsLink {
    case .link(let address):
      items.append(
        TKModalCardViewController.Configuration.ListItem(
          left: "Wallet address",
          rightTop: .value(address.shortAddressString, numberOfLines: 1, isFullString: false),
          rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
        )
      )
    case .unlink:
      break
    }
    
    items.append(buildAmountItem())
    items.append(buildFeeItem())
    
    let content = TKModalCardViewController.Configuration.Content(
      items: [
        .list(
          items
        )
      ]
    )
    
    return TKModalCardViewController.Configuration(
      content: content,
      actionBar: buildActionBar()
    )
  }

  func buildAmountItem() -> TKModalCardViewController.Configuration.ListItem {
    let feeFormatted = amountFormatter.formatAmount(
      OP_AMOUNT.DNS_LINK,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      symbol: TonInfo.symbol
    )
    
    return TKModalCardViewController.Configuration.ListItem(
      left: "Amount",
      rightTop: .value(feeFormatted, numberOfLines: 1, isFullString: false),
      rightBottom: .value(nil, numberOfLines: 1, isFullString: false)
    )
  }
  
  func buildFeeItem() -> TKModalCardViewController.Configuration.ListItem {
    let feeFormatted = amountFormatter.formatAmount(
      BigUInt(UInt64(model.fee)),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: TonInfo.fractionDigits,
      symbol: TonInfo.symbol
    )
    
    return TKModalCardViewController.Configuration.ListItem(
      left: "Fee",
      rightTop: .value(feeFormatted, numberOfLines: 1, isFullString: false),
      rightBottom: .value(nil, numberOfLines: 1, isFullString: false)
    )
  }
  
  func buildActionBar() -> TKModalCardViewController.Configuration.ActionBar {
    TKModalCardViewController.Configuration.ActionBar(
      items: [
        .buttonsRow(
          TKModalCardViewController.Configuration.ButtonsRow(
            buttons: [
              TKModalCardViewController.Configuration.Button(
                title: "Cancel",
                size: .large,
                category: .secondary,
                isEnabled: true,
                isActivity: false,
                tapAction: { [weak self] _, _ in
                  self?.didCancel?()
                }
              ),
              TKModalCardViewController.Configuration.Button(
                title: "Confirm",
                size: .large,
                category: .primary,
                isEnabled: true,
                isActivity: false,
                tapAction: { [weak self] isActivity, isSuccessClosure in
                  guard let self else { return }
                  isActivity(true)
                  Task {
                    Task {
                      let isSuccess = await self.didTapConfirmButton?(self.dnsLink) ?? false
                      await MainActor.run {
                        isSuccessClosure(isSuccess)
                      }
                    }
                  }
                },
                completionAction: { [weak self] isSuccess in
                  guard isSuccess else { return }
                  self?.didLink?()
                }
              )
            ]
          ),
          bottomSpacing: 0,
          itemSpacing: 16
        )
      ]
    )
  }
}
