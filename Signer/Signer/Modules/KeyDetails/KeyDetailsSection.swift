import Foundation

enum KeyDetailsSectionType: Int {
  case qrCode
  case deviceLink
  case webLink
  case actions
  case delete
}

struct KeyDetailsSection: Hashable {
  let type: KeyDetailsSectionType
  let items: [AnyHashable]
}
