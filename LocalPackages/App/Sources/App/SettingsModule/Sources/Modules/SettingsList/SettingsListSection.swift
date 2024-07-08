import Foundation
import UIKit

enum SettingsListSection: Hashable {
  case items(topPadding: CGFloat,
             items: [AnyHashable],
             header: String? = nil,
             bottomDescription: SettingsTextDescriptionView.Model? = nil)
}
