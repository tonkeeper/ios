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
        let tapAction: (( @escaping (Bool) -> Void) -> Void)?
        let showActivityClosure: (() -> Bool)?
        let completion: (() -> Void)?
        
        init(title: String,
             configuration: TKButton.Configuration,
             tapAction: (( @escaping (Bool) -> Void) -> Void)? = nil,
             showActivityClosure: (() -> Bool)? = nil,
             completion: (() -> Void)? = nil) {
          self.title = title
          self.configuration = configuration
          self.tapAction = tapAction
          self.showActivityClosure = showActivityClosure
          self.completion = completion
        }
      }
      
      enum Item {
        case buttons([Button])
      }
      
      let items: [Item]
    }
    
    struct Header {
      enum Image {
        case none
        case image(image: UIImage?, tintColor: UIColor, backgroundColor: UIColor)
      }
      
      let image: Image
      let title: String?
      let topDescription: String?
      let bottomDescription: String?
      let fixBottomDescription: String?
      
      init(image: Image,
           title: String?,
           topDescription: String? = nil,
           bottomDescription: String? = nil,
           fixBottomDescription: String? = nil) {
        self.image = image
        self.title = title
        self.topDescription = topDescription
        self.bottomDescription = bottomDescription
        self.fixBottomDescription = fixBottomDescription
      }
    }
    
    let header: Header
    let listItems: [ListItem]
    let actionBar: ActionBar
  }
}
