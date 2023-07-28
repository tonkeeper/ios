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
      enum RightItem<T> {
        case loading
        case value(T)
        
        var value: T? {
          guard case let .value(value) = self else { return nil }
          return value
        }
      }
      
      let left: String
      let rightTop: RightItem<String>
      let rightBottom: RightItem<String?>
    }
    
    struct ActionBar {
      struct Button {
        let title: String
        let configuration: TKButton.Configuration
        let tapAction: (( @escaping (Bool) -> Void) -> Void)?
        let showActivity: (() -> Bool)?
        let showActivityOnTap: (() -> Bool)?
        let completion: ((Bool) -> Void)?
        
        init(title: String,
             configuration: TKButton.Configuration,
             tapAction: (( @escaping (Bool) -> Void) -> Void)? = nil,
             showActivity: (() -> Bool)? = nil,
             showActivityOnTap: (() -> Bool)? = nil,
             completion: ((Bool) -> Void)? = nil) {
          self.title = title
          self.configuration = configuration
          self.tapAction = tapAction
          self.showActivity = showActivity
          self.showActivityOnTap = showActivityOnTap
          self.completion = completion
        }
      }
      
      enum Item {
        case buttons([Button])
      }
      
      let items: [Item]
    }
    
    struct Header {
      let image: Image?
      let title: String?
      let topDescription: String?
      let bottomDescription: String?
      let fixBottomDescription: String?
      
      init(image: Image?,
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
    
    var header: Header?
    var listItems: [ListItem]
    var actionBar: ActionBar?
  }
}
