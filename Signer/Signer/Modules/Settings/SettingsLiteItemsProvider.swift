import UIKit
import TKUIKit

protocol SettingsLiteItemsProvider {
  var title: String { get }
  var didUpdate: (() -> Void)? { get set }
  
  var showPopupMenu: (([TKPopupMenuItem], Int?, IndexPath) -> Void)? { get set }
  
  func getSections() -> [SettingsSection]
}
