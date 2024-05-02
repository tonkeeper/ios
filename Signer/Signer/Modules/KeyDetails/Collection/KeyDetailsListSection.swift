import Foundation

enum KeyDetailsListSection: Hashable {
  case anotherDeviceExport([KeyDetailsListKeyItem])
  case sameDeviceExport([KeyDetailsListKeyItem])
  case webExport([KeyDetailsListKeyItem])
  case actions([KeyDetailsListKeyItem])
  
  var items: [KeyDetailsListKeyItem] {
    switch self {
    case .anotherDeviceExport(let array):
      return array
    case .sameDeviceExport(let array):
      return array
    case .webExport(let array):
      return array
    case .actions(let array):
      return array
    }
  }
}
