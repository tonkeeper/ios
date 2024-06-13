import UIKit
import TKUIKit

extension UIImage {
  enum Ledger {
    static var deviceBase: UIImage {
      .imageWithName("Images/Ledger/device_base", bundle: .module)
    }
    static var deviceWindowDisconnected: UIImage {
      .imageWithName("Images/Ledger/device_window_disconnected", bundle: .module)
    }
    static var deviceWindowReady: UIImage {
      .imageWithName("Images/Ledger/device_window_ready", bundle: .module)
    }
    static var deviceWindowReview: UIImage {
      .imageWithName("Images/Ledger/device_window_review", bundle: .module)
    }
    static var bluetooth: UIImage {
      .imageWithName("Images/Ledger/bluetooth", bundle: .module)
    }
  }
}
