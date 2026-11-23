@testable import App
import Combine
import CryptoKit
import MoonPay
import TKTestSupport
import XCTest

@MainActor
final class MoonPayRampServiceSignInTests: XCTestCase {
    func test_silentConnect_needingSignIn_thenSignIn_reusesTheCheckedClientToken() async throws {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 600)
        var sessions = 0
        let service = makeService(frames: frames) { sessions += 1 }

        await assertThrows(.signInRequired) { try await service.ensureConnected(interactive: false) }
        let credentials = try await service.ensureConnected()

        XCTAssertEqual(sessions, 1)
        XCTAssertEqual(frames.checks, 1)
        XCTAssertEqual(frames.signInClientTokens, ["client-check"])
        XCTAssertEqual(credentials.accessToken, "access-connected")
    }

    func test_signIn_withAnExpiringClientToken_checksAgain() async throws {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 30)
        var sessions = 0
        let service = makeService(frames: frames) { sessions += 1 }

        await assertThrows(.signInRequired) { try await service.ensureConnected(interactive: false) }
        _ = try await service.ensureConnected()

        XCTAssertEqual(sessions, 2)
        XCTAssertEqual(frames.checks, 2)
        XCTAssertEqual(frames.signInClientTokens, ["client-check"])
    }

    func test_signIn_cancelled_thenAgain_checksAgain() async throws {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 600)
        frames.closesSignIn = true
        var sessions = 0
        let service = makeService(frames: frames) { sessions += 1 }

        await assertThrows(.signInRequired) { try await service.ensureConnected(interactive: false) }
        await assertThrows(.verificationCancelled) { try await service.ensureConnected() }
        frames.closesSignIn = false
        _ = try await service.ensureConnected()

        XCTAssertEqual(sessions, 2)
        XCTAssertEqual(frames.signInClientTokens, ["client-check", "client-check"])
    }

    func test_signIn_cancelledBeforeTheCheckEnds_presentsNothing() async {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 600)
        let service = makeService(frames: frames) {}

        let signIn = Task { try await service.ensureConnected() }
        signIn.cancel()
        let result = await signIn.result

        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError, "\($0)") }
        XCTAssertEqual(frames.signInClientTokens, [])
    }

    func test_aCallerJoiningACancelledSignIn_connectsItself() async {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 600)
        frames.holdsNextCheck = true
        let service = makeService(frames: frames) {}

        let signIn = Task { try await service.ensureConnected() }
        await waitUntil(frames.changes) { frames.checks == 1 }
        signIn.cancel()
        let joiner = Task { try await service.ensureConnected(interactive: false) }
        // Main-actor jobs run in order: the joiner has joined the cancelled connect by now.
        Task { frames.releaseHeldCheck() }
        let joined = await joiner.result

        XCTAssertThrowsError(try joined.get()) { XCTAssertEqual($0 as? MoonPayRampError, .signInRequired, "\($0)") }
        XCTAssertEqual(frames.checks, 2)
        XCTAssertEqual(frames.signInClientTokens, [])
        _ = await signIn.result
    }

    func test_aCallerJoiningASignInCancelledDuringTheSession_connectsItself() async {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 600)
        let sessions = HeldSession()
        let service = MoonPayRampService(
            api: MoonPayPlatformAPI(environment: .sandbox),
            makeSessionToken: { try await sessions.next() },
            framePresenter: frames
        )

        let signIn = Task { try await service.ensureConnected() }
        await waitUntil(sessions.changes) { sessions.isHolding }
        signIn.cancel()
        let joiner = Task { try await service.ensureConnected(interactive: false) }
        // Main-actor jobs run in order: the joiner has joined the cancelled connect by now.
        Task { sessions.failHeld(with: URLError(.cancelled)) }
        let joined = await joiner.result

        XCTAssertThrowsError(try joined.get()) { XCTAssertEqual($0 as? MoonPayRampError, .signInRequired, "\($0)") }
        XCTAssertEqual(frames.checks, 1)
        XCTAssertEqual(frames.signInClientTokens, [])
        _ = await signIn.result
    }

    func test_aCallerJoiningASignInTheUserCloses_afterItsOwnerWasCancelled_doesNotSignInAgain() async {
        let frames = FakeFramePresenter(check: .connectionRequired, checkClientExpiresIn: 600)
        frames.holdsSignIn = true
        let service = makeService(frames: frames) {}

        let signIn = Task { try await service.ensureConnected() }
        await waitUntil(frames.changes) { frames.signInClientTokens.count == 1 }
        signIn.cancel()
        let joiner = Task { try await service.ensureConnected(interactive: false) }
        // Main-actor jobs run in order: the joiner has joined the connect by now.
        Task { frames.closeHeldSignIn() }
        let joined = await joiner.result

        XCTAssertThrowsError(try joined.get()) { XCTAssertEqual($0 as? MoonPayRampError, .verificationCancelled, "\($0)") }
        XCTAssertEqual(frames.checks, 1)
        XCTAssertEqual(frames.signInClientTokens.count, 1)
        _ = await signIn.result
    }

    private func makeService(frames: FakeFramePresenter, onSession: @escaping () -> Void) -> MoonPayRampService {
        MoonPayRampService(
            api: MoonPayPlatformAPI(environment: .sandbox),
            makeSessionToken: {
                onSession()
                return "session"
            },
            framePresenter: frames
        )
    }

    private func assertThrows(
        _ expected: MoonPayRampError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> some Any
    ) async {
        do {
            _ = try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? MoonPayRampError, expected, file: file, line: line)
        }
    }
}

/// Holds the first session request until the test fails it; later ones return at once.
@MainActor
private final class HeldSession {
    let changes = PassthroughSubject<Void, Never>()
    private var held: CheckedContinuation<String, Error>?
    private var hasHeld = false

    var isHolding: Bool {
        held != nil
    }

    func next() async throws -> String {
        guard !hasHeld else { return "session" }
        hasHeld = true
        return try await withCheckedThrowingContinuation { continuation in
            held = continuation
            changes.send()
        }
    }

    func failHeld(with error: Error) {
        let continuation = held
        held = nil
        continuation?.resume(throwing: error)
    }
}

@MainActor
private final class FakeFramePresenter: MoonPayRampFramePresenting {
    private let check: MoonPayConnectionStatus
    private let checkClientExpiresIn: TimeInterval
    var closesSignIn = false
    var holdsNextCheck = false
    var holdsSignIn = false
    private var heldSignInClose: (() -> Void)?
    let changes = PassthroughSubject<Void, Never>()
    private var heldCheck: (() -> Void)?
    private(set) var checks = 0
    private(set) var signInClientTokens: [String] = []

    init(check: MoonPayConnectionStatus, checkClientExpiresIn: TimeInterval) {
        self.check = check
        self.checkClientExpiresIn = checkClientExpiresIn
    }

    func runHeadless(
        _ frame: MoonPayFrame,
        environment _: MoonPayEnvironment,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure _: @escaping (MoonPayFrameError) -> Void
    ) -> MoonPayRampFrameHandle {
        guard case let .checkConnection(_, publicKeyHex, _) = frame else {
            XCTFail("unexpected headless frame \(frame)")
            return MoonPayRampFrameHandle(dismiss: {})
        }
        checks += 1
        let credentials = Self.encrypt(
            accessToken: "",
            clientToken: "client-check",
            expiresIn: checkClientExpiresIn,
            to: publicKeyHex
        )
        let result = MoonPayConnectionResult(status: check, encryptedCredentials: credentials)
        let deliver = { onEvent(.complete(.connection(result))) }
        if holdsNextCheck {
            holdsNextCheck = false
            heldCheck = deliver
        } else {
            Task { @MainActor in deliver() }
        }
        changes.send()
        return MoonPayRampFrameHandle(dismiss: {})
    }

    func closeHeldSignIn() {
        let close = heldSignInClose
        heldSignInClose = nil
        close?()
    }

    func releaseHeldCheck() {
        let deliver = heldCheck
        heldCheck = nil
        deliver?()
    }

    func presentModal(
        _ frame: MoonPayFrame,
        environment _: MoonPayEnvironment,
        onEvent: @escaping (MoonPayFrameEvent) -> Void,
        onFailure _: @escaping (MoonPayFrameError) -> Void,
        onClose: @escaping () -> Void,
        closesAtTap _: Bool
    ) -> MoonPayRampFrameHandle {
        guard case let .connect(clientToken, publicKeyHex, _) = frame else {
            XCTFail("unexpected modal frame \(frame)")
            return MoonPayRampFrameHandle(dismiss: {})
        }
        signInClientTokens.append(clientToken)
        defer { changes.send() }
        if holdsSignIn {
            heldSignInClose = onClose
        } else if closesSignIn {
            Task { @MainActor in onClose() }
        } else {
            let credentials = Self.encrypt(
                accessToken: "access-connected",
                clientToken: "client-connected",
                expiresIn: 3600,
                to: publicKeyHex
            )
            let result = MoonPayConnectionResult(status: .active, encryptedCredentials: credentials)
            Task { @MainActor in onEvent(.complete(.connection(result))) }
        }
        return MoonPayRampFrameHandle(dismiss: {})
    }

    /// The frame side of MoonPay's scheme: X25519 with an ephemeral key, HKDF-SHA256 with an empty
    /// salt and info, AES-GCM with the tag after the ciphertext, hex fields in a base64 JSON envelope.
    private static func encrypt(
        accessToken: String,
        clientToken: String,
        expiresIn: TimeInterval,
        to publicKeyHex: String
    ) -> MoonPayEncryptedCredentials {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiresAt = formatter.string(from: Date().addingTimeInterval(expiresIn))
        let plaintext = #"{"accessToken":"\#(accessToken)","clientToken":"\#(clientToken)","expiresAt":"\#(expiresAt)"}"#
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let hostKey = try! Curve25519.KeyAgreement.PublicKey(rawRepresentation: hexDecode(publicKeyHex))
        let secret = try! ephemeral.sharedSecretFromKeyAgreement(with: hostKey)
        let key = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
        let nonce = AES.GCM.Nonce()
        let sealed = try! AES.GCM.seal(Data(plaintext.utf8), using: key, nonce: nonce)
        let envelope = [
            "iv": hexEncode(nonce.withUnsafeBytes { Data($0) }),
            "ephemeralPublicKey": hexEncode(ephemeral.publicKey.rawRepresentation),
            "ciphertext": hexEncode(sealed.ciphertext + sealed.tag),
        ]
        let json = try! JSONSerialization.data(withJSONObject: envelope)
        return MoonPayEncryptedCredentials(base64: json.base64EncodedString())
    }

    private static func hexEncode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func hexDecode(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index ..< next], radix: 16)!)
            index = next
        }
        return data
    }
}
