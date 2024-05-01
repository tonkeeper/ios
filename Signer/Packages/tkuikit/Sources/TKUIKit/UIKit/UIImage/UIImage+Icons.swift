import UIKit

public extension UIImage {
  enum TKUIKit {
    public enum Icons {
      public enum Button {
        public enum Header {
          public static var back: UIImage? {
            .imageWithName("Icons/16/ic-chevron-left-16")?.withRenderingMode(.alwaysTemplate)
          }
          
          public static var close: UIImage? {
            .imageWithName("Icons/16/ic-close-16")?.withRenderingMode(.alwaysTemplate)
          }
        }
        
        public enum Flat {
          public static var scan: UIImage? {
            .imageWithName("Icons/28/ic-qr-viewfinder-thin-28")?.withRenderingMode(.alwaysTemplate)
          }
          
          public static var add: UIImage? {
            .imageWithName("Icons/28/ic-plus-outline-28")?.withRenderingMode(.alwaysTemplate)
          }
          
          public static var settings: UIImage? {
            .imageWithName("Icons/28/ic-gear-outline-28")?.withRenderingMode(.alwaysTemplate)
          }
        }
      }
      public enum List {
        public enum Accessory {
          public static var disclosure: UIImage? {
            .imageWithName("Icons/16/ic-chevron-right-16")?.withRenderingMode(.alwaysTemplate)
          }
          public static var edit: UIImage? {
            .imageWithName("Icons/28/ic-pencil-28")?.withRenderingMode(.alwaysTemplate)
          }
          public static var copy: UIImage? {
            .imageWithName("Icons/28/ic-copy-28")?.withRenderingMode(.alwaysTemplate)
          }
          public static var key: UIImage? {
            .imageWithName("Icons/28/ic-key-28")?.withRenderingMode(.alwaysTemplate)
          }
          public static var delete: UIImage? {
            .imageWithName("Icons/28/ic-trash-bin-28")?.withRenderingMode(.alwaysTemplate)
          }
          public static var password: UIImage? {
            .imageWithName("Icons/28/ic-lock-28")?.withRenderingMode(.alwaysTemplate)
          }
          public static var support: UIImage? {
            .imageWithName("Icons/28/ic-message-bubble-28")?.withRenderingMode(.alwaysTemplate)
          }
          public static var legal: UIImage? {
            .imageWithName("Icons/28/ic-doc-28")?.withRenderingMode(.alwaysTemplate)
          }
        }
      }
    }
  }
}
