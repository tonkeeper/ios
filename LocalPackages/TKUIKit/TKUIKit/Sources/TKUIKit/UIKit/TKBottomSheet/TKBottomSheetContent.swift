import SnapKit
import SwiftUI
import UIKit

public protocol TKBottomSheetContentViewController: UIViewController {
    var didUpdateHeight: (() -> Void)? { get set }

    var headerConfiguration: TKBottomSheetHeaderConfiguration? { get }
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)? { get set }
    func calculateHeight(withWidth width: CGFloat) -> CGFloat
}

public protocol TKBottomSheetScrollContentViewController: TKBottomSheetContentViewController {
    var scrollView: UIScrollView { get }
}

public protocol TKBottomSheetDynamicScrollContentViewController: TKBottomSheetScrollContentViewController {
    var didUpdateScrollView: ((UIScrollView) -> Void)? { get set }
}
