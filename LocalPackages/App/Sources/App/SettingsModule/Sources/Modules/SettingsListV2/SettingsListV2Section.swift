import Foundation
import UIKit

enum SettingsListV2Section: Hashable {
  case items(topPadding: CGFloat,
             items: [AnyHashable],
             header: String? = nil,
             bottomDescription: SettingsTextDescriptionView.Model? = nil)
}
