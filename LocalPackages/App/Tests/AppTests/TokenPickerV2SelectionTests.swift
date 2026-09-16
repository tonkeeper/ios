@testable import App
@testable import KeeperCore
import XCTest

final class TokenPickerV2SelectionTests: XCTestCase {
    private let walletFilters: [TokenPickerV2ChainFilter] = [
        .all, .chain(.ton), .chain(.eth), .chain(.base), .chain(.bsc),
    ]

    func test_chainFilters_unrestricted_keepsWalletFiltersAndSelectsAll() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: walletFilters,
            allowedChains: nil,
            initialChain: .eth
        )

        XCTAssertEqual(selection.filters, walletFilters)
        XCTAssertEqual(selection.initialFilter, .all)
    }

    func test_chainFilters_unrestricted_emptyWalletFiltersFallBackToAll() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: [],
            allowedChains: nil,
            initialChain: nil
        )

        XCTAssertEqual(selection.filters, [.all])
        XCTAssertEqual(selection.initialFilter, .all)
    }

    func test_chainFilters_restricted_dropsAllAndDisallowedChains() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: walletFilters,
            allowedChains: [.eth, .base],
            initialChain: .eth
        )

        XCTAssertEqual(selection.filters, [.chain(.eth), .chain(.base)])
    }

    func test_chainFilters_restricted_selectsInitialChain() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: walletFilters,
            allowedChains: [.eth, .base, .bsc],
            initialChain: .bsc
        )

        XCTAssertEqual(selection.initialFilter, .chain(.bsc))
    }

    func test_chainFilters_restricted_missingInitialChainFallsBackToFirstFilter() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: walletFilters,
            allowedChains: [.base, .bsc],
            initialChain: .arb
        )

        XCTAssertEqual(selection.initialFilter, .chain(.base))
    }

    func test_chainFilters_restricted_nilInitialChainFallsBackToFirstFilter() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: walletFilters,
            allowedChains: [.base, .bsc],
            initialChain: nil
        )

        XCTAssertEqual(selection.initialFilter, .chain(.base))
    }

    func test_chainFilters_restrictedToEmpty_fallsBackToAll() {
        let selection = SendTokenV2PickerModel.chainFilters(
            walletFilters: walletFilters,
            allowedChains: [.arb],
            initialChain: nil
        )

        XCTAssertEqual(selection.filters, [.all])
        XCTAssertEqual(selection.initialFilter, .all)
    }
}
