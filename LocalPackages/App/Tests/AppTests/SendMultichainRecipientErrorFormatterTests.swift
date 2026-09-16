@testable import App
import KeeperCore
import TKLocalize
import XCTest

final class SendMultichainRecipientErrorFormatterTests: XCTestCase {
    func test_invalidAddressDescription_namesSelectedChainNetworkAndTokenType() {
        let description = SendMultichainRecipientErrorFormatter.invalidAddressDescription(
            selectedChain: .eth
        )

        XCTAssertEqual(description, TKLocales.Send.invalidAddressForNetwork("Ethereum (ERC20)"))
    }

    func test_invalidAddressDescription_distinguishesNetworksOfSameToken() {
        let tronDescription = SendMultichainRecipientErrorFormatter.invalidAddressDescription(
            selectedChain: .tron
        )
        let bscDescription = SendMultichainRecipientErrorFormatter.invalidAddressDescription(
            selectedChain: .bsc
        )

        XCTAssertTrue(tronDescription.contains("TRON (TRC20)"))
        XCTAssertTrue(bscDescription.contains("BSC (BEP20)"))
        XCTAssertNotEqual(tronDescription, bscDescription)
    }

    func test_invalidAddressDescription_deduplicatesIdenticalNetworkAndTokenTypeTitles() {
        let description = SendMultichainRecipientErrorFormatter.invalidAddressDescription(
            selectedChain: .ton
        )

        XCTAssertEqual(description, TKLocales.Send.invalidAddressForNetwork("TON"))
        XCTAssertFalse(description.contains("TON (TON)"))
    }

    func test_invalidAddressDescription_fallsBackToGenericInvalidAddressWithoutChain() {
        let description = SendMultichainRecipientErrorFormatter.invalidAddressDescription(
            selectedChain: nil
        )

        XCTAssertEqual(description, TKLocales.Send.invalidAddress)
    }
}
