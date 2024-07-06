import Foundation
import UIKit

enum SettingsListV2Section: Hashable {
  case items(topPadding: CGFloat, items: [AnyHashable])
}
