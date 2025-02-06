import Foundation

struct BrowserHeaderRightButtonModel {
  let title: String?
  let disabled: Bool?
  let action: (() -> Void)
}
