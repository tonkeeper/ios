//
//  StakeConfirmationViewModel.swift
//
//
//  Created by Semyon on 17/05/2024.
//

import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

protocol StakeConfirmationModuleOutput: AnyObject {
  var didSendTransaction: (() -> Void)? { get set }
}

protocol StakeConfirmationModuleInput: AnyObject {
  
}

protocol StakeConfirmationViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
}

final class StakeConfirmationViewModelImplementation: StakeConfirmationViewModel, StakeConfirmationModuleOutput, StakeConfirmationModuleInput {
  
  // MARK: - SendConfirmationModuleOutput
  
  var didSendTransaction: (() -> Void)?
  
  // MARK: - SendConfirmationModuleInput
  
  // MARK: - SendConfirmationViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    setupControllerBindings()
  }
  
  func viewDidAppear() {
    
  }
  
  func viewWillDisappear() {
    
  }
  
  // MARK: - Dependencies
  
  // MARK: - Init
  
}

private extension StakeConfirmationViewModelImplementation {
  func setupControllerBindings() {
      let configuration = self.mapSendConfirmationModel()
      self.didUpdateConfiguration?(configuration)
  }
  
  func mapSendConfirmationModel() -> TKModalCardViewController.Configuration {
    
    let headerView: UIView
    let view = HistoreEventDetailsTokenHeaderImageView()
    view.configure(
      model: HistoreEventDetailsTokenHeaderImageView.Model(
        image: .image(
          .TKUIKit.Icons.Size96.tonIcon,
          tinColor: nil,
          backgroundColor: nil
        )
      )
    )
    headerView = view
    
    let header = TKModalCardViewController.Configuration.Header(
      items: [
        .customView(headerView, bottomSpacing: 20),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: "Deposit".withTextStyle(.body1, color: .Text.secondary, alignment: .center),
            numberOfLines: 1
          ),
          bottomSpacing: 4
        ),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: "1,000.01 TON".withTextStyle(.h3, color: .Text.primary, alignment: .center),
            numberOfLines: 1
          ),
          bottomSpacing: 0
        ),
        .text(
          TKModalCardViewController.Configuration.Text(
            text: "$ 6,010.01".withTextStyle(.body1, color: .Text.secondary, alignment: .center),
            numberOfLines: 1
          ),
          bottomSpacing: 4
        ),
      ]
    )
    
    var listItems = [TKModalCardViewController.Configuration.ListItem]()
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: "Wallet",
        rightTop: .value("Main", numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: true)
      )
    )
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: "Recipient",
        rightTop: .value("Tonstakers", numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: true)
      )
    )
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: "APY",
        rightTop: .value("≈ 5.01%", numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: true)
      )
    )
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: "Fee",
        rightTop: .value("≈ 0.01 TON", numberOfLines: 0, isFullString: true),
        rightBottom: .value("$ 0.01", numberOfLines: 0, isFullString: true)
      )
    )
    
    let content = TKModalCardViewController.Configuration.Content(items: [
      .list(listItems)
    ])
    
    let actionBar = TKModalCardViewController.Configuration.ActionBar(
      items: [
        .button(
          TKModalCardViewController.Configuration.Button(
            title: TKLocales.ConfirmSend.confirm_button,
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: { [weak self] isActivityClosure, isSuccessClosure in
              guard let self = self else { return }
              Task {
                await MainActor.run {
                  isSuccessClosure(true)
                }
              }
            },
            completionAction: { [weak self] isSuccess in
              guard let self, isSuccess else { return }
              self.didSendTransaction?()
            }
          ),
          bottomSpacing: 0
        )
      ]
    )
    
    return TKModalCardViewController.Configuration(
      header: header,
      content: content,
      actionBar: actionBar
    )
  }
  
  func sendTransaction() async -> Bool {
    return true
  }
}
