//
//  TonConnectPopupAssembly.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import UIKit
import WalletCoreKeeper

struct TonConnectPopupAssembly {
  static func module(tonConnectController: TonConnectController,
                     output: TonConnectPopupModuleOutput?) -> Module<TonConnectPopupViewController, TonConnectPopupPresenterInput> {
    
    let presenter = TonConnectPopupPresenter(
      tonConnectController: tonConnectController
    )
    let viewController = TonConnectPopupViewController(presenter: presenter)
    
    presenter.viewInput = viewController
    presenter.output = output
    
    return Module(view: viewController, input: presenter)
  }
}
