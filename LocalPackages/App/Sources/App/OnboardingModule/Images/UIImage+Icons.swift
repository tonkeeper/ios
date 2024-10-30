import UIKit

public extension UIImage {
  enum App {
    public enum Icons {
      public enum Size44 {
        public static var tonLogo: UIImage {
          .imageWithName("Icons/Size44/ton_logo")
        }
      }
      public enum Size28 {
        public static var bell: UIImage {
          .imageWithName("Icons/28/ic-bell-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var donemark: UIImage {
          .imageWithName("Icons/28/ic-donemark-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var gear: UIImage {
          .imageWithName("Icons/28/ic-gear-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var `return`: UIImage {
          .imageWithName("Icons/28/ic-return-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var shoppingBag: UIImage {
          .imageWithName("Icons/28/ic-shopping-bag-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var swapHorizontalAlternative: UIImage {
          .imageWithName("Icons/28/ic-swap-horizontal-alternative-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var trayArrowDown: UIImage {
          .imageWithName("Icons/28/ic-tray-arrow-down-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var trayArrowUp: UIImage {
          .imageWithName("Icons/28/ic-tray-arrow-up-28")
          .withRenderingMode(.alwaysTemplate)
        }
        public static var xmark: UIImage {
          .imageWithName("Icons/28/ic-xmark-28")
          .withRenderingMode(.alwaysTemplate)
        }
      }
    }
    public enum Images {
      public enum StakingImplementation {
        public static var tonNominators: UIImage {
          .imageWithName("Icons/StakingImplementation/ton_nominators", bundle: .module)
        }
        public static var tonstakers: UIImage {
          .imageWithName("Icons/StakingImplementation/tonstakers", bundle: .module)
        }
        public static var whales: UIImage {
          .imageWithName("Icons/StakingImplementation/whales", bundle: .module)
        }
      }
    }
    public enum Battery {
      public static var batteryBody24: UIImage {
        .imageWithName("Icons/Battery/battery-body-24")
      }
      public static var batteryBody34: UIImage {
        .imageWithName("Icons/Battery/battery-body-34")
      }
      public static var batteryBody44: UIImage {
        .imageWithName("Icons/Battery/battery-body-44")
      }
      public static var batteryBody128: UIImage {
        .imageWithName("Icons/Battery/battery-body-128")
      }
      public static var gift: UIImage {
        .imageWithName("Images/Battery/battery_gift")
      }
      public static var history: UIImage {
        .imageWithName("Images/Battery/battery_history")
      }
    }
  }
}

private extension UIImage {
  static func imageWithName(_ name: String) -> UIImage {
    return UIImage(named: name, in: .module, with: nil) ?? UIImage()
  }
}
