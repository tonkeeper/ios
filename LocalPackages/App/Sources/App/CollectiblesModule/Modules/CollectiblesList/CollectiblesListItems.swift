import SwiftUI
import TKUIKit
import UIKit

struct CollectiblesListItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let subtitleColor: TKColor
    let imageSource: NFTImageViewImageSource
    let isSecureMode: Bool
    let isOnSale: Bool
}
