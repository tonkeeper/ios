@testable import App
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit
import XCTest

@MainActor
final class ReceiveLegacyViewModelTests: XCTestCase {
    func test_preselectsTronTab_forTronInitialToken() {
        let viewModel = makeViewModel(
            tokens: [.ton(.ton), .tron(.trx)],
            initialToken: .tron(.trx)
        )

        var receivedSegments: [String]?
        var selectedIndex: Int?
        var displayedToken: ReceiveLegacyToken?
        viewModel.didUpdateSegmentedControl = { receivedSegments = $0 }
        viewModel.didChangeIndex = { selectedIndex = $0 }
        viewModel.didDisplayToken = { displayedToken = $0 }

        viewModel.viewDidLoad()

        XCTAssertEqual(receivedSegments, [
            TKLocales.Receive.Multichain.Networks.Ton.title,
            TKLocales.Receive.Segments.trc20,
        ])
        XCTAssertEqual(selectedIndex, 1)
        XCTAssertEqual(displayedToken, .tron(.trx))
    }

    func test_preselectsTonTab_forTonInitialToken() {
        let viewModel = makeViewModel(
            tokens: [.ton(.ton), .tron(.trx)],
            initialToken: .ton(.ton)
        )

        var selectedIndexCalls: [Int] = []
        var displayedToken: ReceiveLegacyToken?
        viewModel.didChangeIndex = { selectedIndexCalls.append($0) }
        viewModel.didDisplayToken = { displayedToken = $0 }

        viewModel.viewDidLoad()

        // Index 0 is already selected once the control gets its tabs, so no explicit sync fires.
        XCTAssertTrue(selectedIndexCalls.isEmpty)
        XCTAssertEqual(displayedToken, .ton(.ton))
    }

    func test_defaultsToFirstToken_whenNoInitialToken() {
        let viewModel = makeViewModel(
            tokens: [.ton(.ton), .tron(.trx)],
            initialToken: nil
        )

        var selectedIndexCalls: [Int] = []
        var displayedToken: ReceiveLegacyToken?
        viewModel.didChangeIndex = { selectedIndexCalls.append($0) }
        viewModel.didDisplayToken = { displayedToken = $0 }

        viewModel.viewDidLoad()

        XCTAssertTrue(selectedIndexCalls.isEmpty)
        XCTAssertEqual(displayedToken, .ton(.ton))
    }

    func test_singleToken_hidesSegmentedControlAndSkipsIndexSync() {
        let viewModel = makeViewModel(
            tokens: [.ton(.ton)],
            initialToken: .ton(.ton)
        )

        var segmentsCallCount = 0
        var receivedSegments: [String]?
        var selectedIndexCalls: [Int] = []
        viewModel.didUpdateSegmentedControl = {
            segmentsCallCount += 1
            receivedSegments = $0
        }
        viewModel.didChangeIndex = { selectedIndexCalls.append($0) }

        viewModel.viewDidLoad()

        // A single-token receive has no segmented control to index into; driving it would crash.
        XCTAssertEqual(segmentsCallCount, 1)
        XCTAssertNil(receivedSegments)
        XCTAssertTrue(selectedIndexCalls.isEmpty)
    }
}

private extension ReceiveLegacyViewModelTests {
    func makeViewModel(
        tokens: [ReceiveLegacyToken],
        initialToken: ReceiveLegacyToken?
    ) -> ReceiveLegacyViewModelImplementation {
        ReceiveLegacyViewModelImplementation(
            tokens: tokens,
            initialToken: initialToken,
            tokenModuleViewControllerProvider: { _ in
                ReceiveTabViewController(viewModel: StubReceiveTabViewModel())
            }
        )
    }
}

private final class StubReceiveTabViewModel: ReceiveTabViewModel {
    var didUpdateModel: ((ReceiveTabView.Model) -> Void)?
    var didGenerateQRCode: ((QrCodeMatrix?) -> Void)?
    var didTapShare: ((String?) -> Void)?
    func viewDidLoad() {}
}
