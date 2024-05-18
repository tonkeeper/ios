//
//  StakeInfoViewModel.swift
//
//
//  Created by Semyon on 18/05/2024.
//

import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

protocol StakeInfoModuleOutput: AnyObject {

}

protocol StakeInfoModuleInput: AnyObject {
  
}

protocol StakeInfoViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
}

final class StakeInfoViewModelImplementation: StakeInfoViewModel, StakeInfoModuleOutput, StakeInfoModuleInput {
  
  // MARK: - StakeInfoModuleOutput
  
  // MARK: - StakeInfoModuleInput
  
  // MARK: - StakeInfoViewModel
  
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

private extension StakeInfoViewModelImplementation {
  func setupControllerBindings() {
      let configuration = self.mapSendConfirmationModel()
      self.didUpdateConfiguration?(configuration)
  }
  
  func mapSendConfirmationModel() -> TKModalCardViewController.Configuration {
    
    var listItems = [TKModalCardViewController.Configuration.ListItem]()
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: "APY",
        rightTop: .value("≈ 5.01%", numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: true)
      )
    )
    listItems.append(
      TKModalCardViewController.Configuration.ListItem(
        left: "Minimal deposit",
        rightTop: .value("1 TON", numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: true)
      )
    )
    
    let tagCollection = TagsListView(model: .init(
      tags: [
        .init(icon: .TKUIKit.Icons.Size16.globe, title: "tonstakers.com"),
        .init(icon: .TKUIKit.Icons.Size16.twitter, title: "Twitter"),
        .init(icon: .TKUIKit.Icons.Size16.telegram, title: "Community"),
        .init(icon: .TKUIKit.Icons.Size16.magnifyingGlass, title: "tonviewer.com"),
      ]
    ))
    
    let content = TKModalCardViewController.Configuration.Content(items: [
      .list(listItems),
      .item(
        .text(
          TKModalCardViewController.Configuration.Text(
            text: "Staking is based on smart contracts by third parties. Tonkeeper is not responsible for staking experience.".withTextStyle(
              .body3,
              color: .Text.tertiary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            ),
            numberOfLines: 0
          ),
          bottomSpacing: 14
        )
      ),
      .item(
        .text(
          TKModalCardViewController.Configuration.Text(
            text: "Links".withTextStyle(
              .h3,
              color: .Text.primary,
              alignment: .left,
              lineBreakMode: .byTruncatingTail
            ),
            numberOfLines: 1
          ),
          bottomSpacing: 14
        )
      ),
      .item(.customView(tagCollection, bottomSpacing: 0))
    ])
    
    return TKModalCardViewController.Configuration(
      header: nil,
      content: content,
      actionBar: nil
    )
  }
}
