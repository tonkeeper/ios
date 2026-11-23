import Combine
import SwiftUI
import UIKit

/// Hosts SwiftUI content inside `TKBottomSheetViewController` in a scroll view: content taller than
/// the screen leaves for the sheet scrolls instead of being cut off at the bottom.
public final class TKBottomSheetScrollHostingController<Content: View>: UIViewController, TKBottomSheetScrollContentViewController {
    public var didUpdateHeight: (() -> Void)?
    public var headerConfiguration: TKBottomSheetHeaderConfiguration? {
        didSet {
            didUpdateHeaderConfiguration?(headerConfiguration)
        }
    }

    public var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration?) -> Void)?

    public let scrollView = UIScrollView()
    private let hostingController: ContentHostingController<Content>
    private lazy var contentHeightConstraint = hostingController.view.heightAnchor.constraint(equalToConstant: 0)
    private var liveSubtitleCancellable: AnyCancellable?
    private var contentHeight: CGFloat = 0

    var content: Content {
        hostingController.content.content
    }

    public init(header: TKBottomSheetHeaderConfiguration, @ViewBuilder content: () -> Content) {
        hostingController = ContentHostingController(content: MeasuredContent(content: content()))
        super.init(nibName: nil, bundle: nil)
        headerConfiguration = header
        hostingController.didLayoutContent = { [weak self] height in
            guard let self, height != contentHeight else { return }
            contentHeight = height
            contentHeightConstraint.constant = height
            didUpdateHeight?()
        }
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
    }

    public convenience init(
        title: String,
        subtitle: String?,
        liveSubtitle: AnyPublisher<String, Never>?,
        @ViewBuilder content: () -> Content
    ) {
        self.init(header: Self.header(title: title, subtitle: subtitle), content: content)
        liveSubtitleCancellable = liveSubtitle?
            .removeDuplicates()
            .sink { [weak self] in self?.headerConfiguration = Self.header(title: title, subtitle: $0) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)
        addChild(hostingController)
        let hostingView = hostingController.view!
        hostingView.backgroundColor = .clear
        scrollView.addSubview(hostingView)
        hostingController.didMove(toParent: self)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentHeightConstraint,
        ])
    }

    public func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        let height = ceil(hostingController.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        contentHeightConstraint.constant = height
        return height
    }

    private static func header(title: String, subtitle: String?) -> TKBottomSheetHeaderConfiguration {
        TKBottomSheetHeaderConfiguration(title: .title(title: title, subtitle: subtitle))
    }
}

/// The content at its ideal height, the one the sheet measured.
private struct MeasuredContent<Content: View>: View {
    let content: Content

    var body: some View {
        content.fixedSize(horizontal: false, vertical: true)
    }
}

private final class ContentHostingController<Content: View>: TKHostingController<MeasuredContent<Content>> {
    var didLayoutContent: ((CGFloat) -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.width > 0 else { return }
        let height = ceil(sizeThatFits(in: CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)).height)
        didLayoutContent?(height)
    }
}
