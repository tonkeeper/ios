//
//  ModalContentViewController+Configuration.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit

extension ModalContentViewController {
  struct Configuration {
    struct ListItem {
      let left: String
      let rightTop: String
      let rightBottom: String?
    }
    
    struct ActionBar {
      struct Button {
        let title: String
        let configuration: TKButton.Configuration
        let tapAction: (() -> Void)?
      }
      
      enum Item {
        case buttons([Button])
      }
      
      let items: [Item]
    }
    
    struct Header {
      let title: String?
      let description: String?
    }
    
    let header: Header
    let listItems: [ListItem]
    let actionBar: ActionBar
  }
}
