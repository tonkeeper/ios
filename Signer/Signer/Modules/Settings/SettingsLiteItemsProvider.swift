import UIKit

protocol SettingsLiteItemsProvider {
  var title: String { get }
  func getSections() -> [SettingsSection]
}
