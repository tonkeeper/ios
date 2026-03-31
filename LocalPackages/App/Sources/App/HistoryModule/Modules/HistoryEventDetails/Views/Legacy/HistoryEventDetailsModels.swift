import KeeperCore
import UIKit

enum Image: Equatable, Hashable {
    case url(URL?)
    case image(UIImage?, tinColor: UIColor?, backgroundColor: UIColor?)
}
