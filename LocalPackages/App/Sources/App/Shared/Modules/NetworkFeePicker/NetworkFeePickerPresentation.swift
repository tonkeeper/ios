import TKUIKit
import UIKit

@MainActor
struct NetworkFeePickerPresentation {
    let configuration: NetworkFeePickerConfiguration
    let dataSource: any NetworkFeePickerDataSource
    let didSelectItem: (NetworkFeePickerItem, NetworkFeePickerCategory?) -> Void
}
