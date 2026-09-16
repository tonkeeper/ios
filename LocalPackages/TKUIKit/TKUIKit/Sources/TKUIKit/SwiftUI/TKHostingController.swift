import SwiftUI
import UIKit

/// Hosting controller for SwiftUI content; carries TK-specific environment
/// (theming etc.). Use it instead of `UIHostingController`.
open class TKHostingController<Content: View>: SwiftUI.UIHostingController<TKThemedView<Content>> {
    public var content: Content {
        get { rootView.content }
        set { rootView = TKThemedView(content: newValue) }
    }

    public init(content: Content) {
        super.init(rootView: TKThemedView(content: content))
    }

    @available(*, unavailable)
    public dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
