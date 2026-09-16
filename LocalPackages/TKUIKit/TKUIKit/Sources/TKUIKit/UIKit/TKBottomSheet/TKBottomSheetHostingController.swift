import SwiftUI
import UIKit

/// Hosts SwiftUI content inside `TKBottomSheetViewController`.
///
/// Height is measured on a detached hosting controller that opts out of safe areas, so the reported
/// height is the content's own; the bottom safe-area inset is then added back explicitly. Measuring
/// the on-screen controller instead would fold the safe area into the content height and count it
/// twice against the sheet.
public final class TKBottomSheetHostingController<Content: View>:
    TKHostingController<TKBottomSheetContentContainer<Content>>,
    TKBottomSheetContentViewController
{
    public var didUpdateHeight: (() -> Void)?
    public var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    public var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        didSet {
            didUpdateHeaderConfiguration?(headerConfiguration)
        }
    }

    private let contentHeightMeasurementController: TKHostingController<Content>
    private var preferredWidth: CGFloat = 0

    public init(
        content: Content,
        headerConfiguration: TKBottomSheetHeaderConfiguration? = nil
    ) {
        self.headerConfiguration = headerConfiguration
        contentHeightMeasurementController = TKHostingController(content: content)
        super.init(content: TKBottomSheetContentContainer(content: content))

        if #available(iOS 16.4, *) {
            contentHeightMeasurementController.safeAreaRegions = []
        }
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        view.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWidthIfNeeded(view.bounds.width, notify: true)
    }

    public func setContent(_ content: Content) {
        self.content = TKBottomSheetContentContainer(content: content)
        contentHeightMeasurementController.content = content
        didUpdateHeight?()
    }

    public func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        updateWidthIfNeeded(width, notify: false)

        let contentHeight = contentHeightMeasurementController.sizeThatFits(
            in: CGSize(
                width: width,
                height: .greatestFiniteMagnitude
            )
        ).height

        return ceil(contentHeight + bottomSafeAreaInset)
    }
}

private extension TKBottomSheetHostingController {
    var bottomSafeAreaInset: CGFloat {
        parent?.view.safeAreaInsets.bottom ?? view.window?.safeAreaInsets.bottom ?? 0
    }

    func updateWidthIfNeeded(_ width: CGFloat, notify: Bool) {
        guard width > 0, preferredWidth != width else { return }
        preferredWidth = width
        if notify {
            didUpdateHeight?()
        }
    }
}
