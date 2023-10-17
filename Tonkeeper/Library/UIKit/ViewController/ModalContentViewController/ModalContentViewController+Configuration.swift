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
        let title: String?
        let configuration: TKButton.Configuration
        let isEnabled: Bool
        let tapAction: (( @escaping (Bool) -> Void) -> Void)?
        let showActivity: (() -> Bool)?
        let showActivityOnTap: (() -> Bool)?
        let completion: ((Bool) -> Void)?
        
        init(title: String?,
             configuration: TKButton.Configuration,
             isEnabled: Bool = true,
             tapAction: (( @escaping (Bool) -> Void) -> Void)? = nil,
             showActivity: (() -> Bool)? = nil,
             showActivityOnTap: (() -> Bool)? = nil,
             completion: ((Bool) -> Void)? = nil) {
          self.title = title
          self.configuration = configuration
          self.isEnabled = isEnabled
          self.tapAction = tapAction
          self.showActivity = showActivity
          self.showActivityOnTap = showActivityOnTap
          self.completion = completion
        }
      }
      
      struct Checkmark {
        let title: String
        let isMarked: Bool
        let markAction: (Bool) -> Void
      }
      
      struct Warning {
        struct Button {
          let title: String
          let closure: (() -> Void)?
        }
        
        let text: String
        let buttons: [Button]
      }
      
      enum Item {
        case buttons([Button])
        case checkmark(Checkmark)
        case warning(Warning)
      }
      
      let items: [Item]
    }
    
    struct Header {
      enum ImageShape {
        case rect
        case circle
        case roundedRect(cornerRadius: CGFloat)
      }
      
      let image: Image?
      let imageShape: ImageShape
      let title: String?
      let topDescription: String?
      let bottomDescription: String?
      let fixBottomDescription: String?
      
      init(image: Image?,
           imageShape: ImageShape,
           title: String?,
           topDescription: String? = nil,
           bottomDescription: String? = nil,
           fixBottomDescription: String? = nil) {
        self.image = image
        self.imageShape = imageShape
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
