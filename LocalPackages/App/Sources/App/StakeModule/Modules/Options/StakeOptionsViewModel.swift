//
//  StakeOptionsViewModel.swift
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

protocol StakeOptionsModuleOutput: AnyObject {
  
}

protocol StakeOptionsModuleInput: AnyObject {
  
}

protocol StakeOptionsViewModel: AnyObject {
  
  func viewDidLoad()
  func viewDidAppear()
  func viewWillDisappear()
}

final class StakeOptionsViewModelImplementation: StakeOptionsViewModel, StakeOptionsModuleOutput, StakeOptionsModuleInput {
  
  // MARK: - StakeOptionsModuleOutput
  
  // MARK: - StakeOptionsModuleInput
  
  // MARK: - StakeOptionsViewModel
  
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

private extension StakeOptionsViewModelImplementation {
  func setupControllerBindings() {
    
  }
}

