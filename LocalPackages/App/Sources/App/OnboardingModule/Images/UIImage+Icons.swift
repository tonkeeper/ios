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
            public enum Size44 {
                public static var clock: UIImage {
                    .imageWithName("Images/44/clock", bundle: .module)
                }

                public static var gift: UIImage {
                    .imageWithName("Images/44/gift", bundle: .module)
                }

                public static var exclamationMark: UIImage {
                    .imageWithName("Images/44/exclamation_mark", bundle: .module)
                }
            }

            public enum Size72 {
                public static var supportLight: UIImage {
                    .imageWithName("Images/72/support-light-72")
                }

                public static var supportDark: UIImage {
                    .imageWithName("Images/72/support-dark-72")
                }

                public static var supportBlue: UIImage {
                    .imageWithName("Images/72/support-blue-72")
                }
            }

            public enum StakingImplementation {
                public static var tonNominators: UIImage {
                    .imageWithName("Images/StakingImplementation/ton_nominators", bundle: .module)
                }

                public static var tonstakers: UIImage {
                    .imageWithName("Images/StakingImplementation/tonstakers", bundle: .module)
                }

                public static var whales: UIImage {
                    .imageWithName("Images/StakingImplementation/whales", bundle: .module)
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

                public static var batteryBody52: UIImage {
                    .imageWithName("Icons/Battery/battery-body-52")
                }

                public static var batteryBody128: UIImage {
                    .imageWithName("Icons/Battery/battery-body-128")
                }

                public static var batteryBanner: UIImage {
                    .imageWithName("Icons/Battery/battery-banner")
                }
            }
        }

        public enum Currency {
            enum Size44 {
                public static var usdt: UIImage {
                    .imageWithName("Icons/Currency/44/usdt")
                }

                public static var usde: UIImage {
                    .imageWithName("Icons/Currency/44/usde44")
                }
            }

            enum Size60 {
                public static var usdtTrc20: UIImage {
                    .imageWithName("Icons/Currency/60/usdt_trc20")
                }
            }

            enum Size64 {
                public static var usde: UIImage {
                    .imageWithName("Icons/Currency/64/usde64")
                }
            }

            enum Size96 {
                public static var usdt: UIImage {
                    .imageWithName("Icons/Currency/96/usdt")
                }
            }

            enum Vector {
                public static var trc20: UIImage {
                    .imageWithName("Icons/Currency/Vector/trc20")
                }

                public static var ton: UIImage {
                    .imageWithName("Icons/Currency/Vector/ton")
                }

                public static var ethena: UIImage {
                    .imageWithName("Icons/Currency/Vector/ethena")
                }
            }
        }

        public enum Stories {
            enum Size44 {
                public static var stories: UIImage {
                    .imageWithName("Icons/Stories/44/ic-stories-44")
                }
            }
        }
    }
}

private extension UIImage {
    static func imageWithName(_ name: String) -> UIImage {
        return UIImage(named: name, in: .module, with: nil) ?? UIImage()
    }
}
