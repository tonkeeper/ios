import Foundation
import TKCore
import KeeperCore
import TonSwift

struct LinkDNSAssembly {
  private init() {}
  static func module(model: SendTransactionModel,
                     dnsLink: DNSLink,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly) -> MVVMModule<LinkDNSViewController, LinkDNSModuleOutput, Void> {
    let viewModel = LinkDNSViewModelImplementation(
      model: model,
      dnsLink: dnsLink,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let viewController = LinkDNSViewController(viewModel: viewModel)
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
