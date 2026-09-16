@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainSendRecipientStateTests: XCTestCase {
    private let tonAddress = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
    private let tronAddress = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"

    func test_emptyStateHasNoRecipientAndNoError() {
        let state = MultichainSendRecipientState.empty

        XCTAssertEqual(state.validation(expectedChain: .ton), .empty)
        XCTAssertNil(state.recipient)
        XCTAssertEqual(state.input, "")
    }

    func test_resolvingStateHidesErrorWhileInFlight() {
        let state = MultichainSendRecipientState.resolving(
            input: "test.ton",
            generation: 1,
            task: Task {}
        )

        XCTAssertEqual(state.validation(expectedChain: .ton), .resolving)
        XCTAssertNil(state.recipient)
        XCTAssertEqual(state.input, "test.ton")
    }

    func test_resolvedRecipientMatchingChainIsValid() {
        let recipient = MultichainRecipient(chain: .ton, address: tonAddress)
        let state = MultichainSendRecipientState.resolved(input: tonAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(state.validation(expectedChain: .ton), .valid)
        XCTAssertEqual(state.recipient, recipient)
    }

    func test_resolvedRecipientForOtherChainIsChainMismatch() {
        let recipient = MultichainRecipient(chain: .ton, address: tonAddress)
        let state = MultichainSendRecipientState.resolved(input: tonAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(state.validation(expectedChain: .eth), .chainMismatch)
    }

    func test_resolvedRecipientWithoutExpectedChainIsChainMismatch() {
        let recipient = MultichainRecipient(chain: .ton, address: tonAddress)
        let state = MultichainSendRecipientState.resolved(input: tonAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(state.validation(expectedChain: nil), .chainMismatch)
    }

    func test_ownAddressWithForbiddenSelfSend_isSelfSendForbidden() {
        let recipient = MultichainRecipient(chain: .tron, address: tronAddress)
        let state = MultichainSendRecipientState.resolved(input: tronAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(
            state.validation(expectedChain: .tron, forbiddenSelfSendAddress: tronAddress),
            .selfSendForbidden
        )
    }

    func test_ownAddressWithoutForbiddenSelfSend_staysValid() {
        let recipient = MultichainRecipient(chain: .tron, address: tronAddress)
        let state = MultichainSendRecipientState.resolved(input: tronAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(state.validation(expectedChain: .tron), .valid)
    }

    func test_otherAddressWithForbiddenSelfSend_staysValid() {
        let recipient = MultichainRecipient(chain: .tron, address: tronAddress)
        let state = MultichainSendRecipientState.resolved(input: tronAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(
            state.validation(
                expectedChain: .tron,
                forbiddenSelfSendAddress: "TKoUnkRBggFPbbsPnXqdnbjfVzRhDfnhoc"
            ),
            .valid
        )
    }

    func test_chainMismatchWinsOverSelfSendCheck() {
        let recipient = MultichainRecipient(chain: .ton, address: tonAddress)
        let state = MultichainSendRecipientState.resolved(input: tonAddress, recipient: recipient, isMemoRequired: false)

        XCTAssertEqual(
            state.validation(expectedChain: .tron, forbiddenSelfSendAddress: tonAddress),
            .chainMismatch
        )
    }

    func test_failedStateMapsReasonToValidation() {
        XCTAssertEqual(
            MultichainSendRecipientState.failed(input: "abc", reason: .invalidAddress)
                .validation(expectedChain: .ton),
            .invalidAddress
        )
        XCTAssertEqual(
            MultichainSendRecipientState.failed(input: "scam.ton", reason: .scam)
                .validation(expectedChain: .ton),
            .scam
        )
    }

    func test_resolutionResult_domainKeepsDomainAndResolvedAddress() throws {
        let friendly = try FriendlyAddress(string: tonAddress)
        let resolved = LegacyRecipient.ton(TonRecipient(
            recipientAddress: .domain(Domain(domain: "test.ton", friendlyAddress: friendly)),
            isMemoRequired: false,
            isScam: false
        ))

        let state = MultichainSendRecipientState.resolutionResult(input: "test.ton", resolved: resolved)

        XCTAssertEqual(state.input, "test.ton")
        XCTAssertEqual(
            state.recipient,
            MultichainRecipient(chain: .ton, address: friendly.toString(), domain: "test.ton")
        )
        XCTAssertEqual(state.validation(expectedChain: .ton), .valid)
        XCTAssertFalse(state.isMemoRequired)
    }

    func test_resolutionResult_memoRequiredAccountKeepsRequirement() throws {
        let friendly = try FriendlyAddress(string: tonAddress)
        let resolved = LegacyRecipient.ton(TonRecipient(
            recipientAddress: .domain(Domain(domain: "exchange.ton", friendlyAddress: friendly)),
            isMemoRequired: true,
            isScam: false
        ))

        let state = MultichainSendRecipientState.resolutionResult(input: "exchange.ton", resolved: resolved)

        XCTAssertTrue(state.isMemoRequired)
        XCTAssertNotNil(state.recipient)
        XCTAssertEqual(state.validation(expectedChain: .ton), .valid)
    }

    func test_isMemoRequired_isFalseForNonResolvedStates() {
        XCTAssertFalse(MultichainSendRecipientState.empty.isMemoRequired)
        XCTAssertFalse(
            MultichainSendRecipientState.failed(input: "abc", reason: .invalidAddress).isMemoRequired
        )
        XCTAssertFalse(
            MultichainSendRecipientState.resolving(input: "test.ton", generation: 1, task: Task {}).isMemoRequired
        )
    }

    func test_resolutionResult_scamAccountFailsAsScam() throws {
        let friendly = try FriendlyAddress(string: tonAddress)
        let resolved = LegacyRecipient.ton(TonRecipient(
            recipientAddress: .domain(Domain(domain: "scam.ton", friendlyAddress: friendly)),
            isMemoRequired: false,
            isScam: true
        ))

        let state = MultichainSendRecipientState.resolutionResult(input: "scam.ton", resolved: resolved)

        XCTAssertNil(state.recipient)
        XCTAssertEqual(state.validation(expectedChain: .ton), .scam)
    }

    func test_resolutionResult_tronResolutionIsInvalid() throws {
        let resolved = try LegacyRecipient.tron(TronRecipient(address: tronAddress))

        let state = MultichainSendRecipientState.resolutionResult(input: tronAddress, resolved: resolved)

        XCTAssertNil(state.recipient)
        XCTAssertEqual(state.validation(expectedChain: .ton), .invalidAddress)
    }

    func test_resolutionResult_failedResolutionIsInvalid() {
        let state = MultichainSendRecipientState.resolutionResult(input: "nonexistent.ton", resolved: nil)

        XCTAssertNil(state.recipient)
        XCTAssertEqual(state.validation(expectedChain: .ton), .invalidAddress)
    }
}
