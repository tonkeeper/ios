@testable import App
@testable import KeeperCore
import TKCoordinator
import TKUIKit
import UIKit
import XCTest

@MainActor
final class PasscodeInputCoordinatorTests: XCTestCase {
    func testCancellationWithoutAnyUIKitCallbackResumesThePasscodeAndRemovesTheChildOnce() async throws {
        let presenter = Presenter()
        let parent = Parent()
        let presented = expectation(description: "passcode presented")
        presenter.didPresent = { presented.fulfill() }
        var answers: [String?] = []
        let task = Task {
            let answer = await getPasscode(parent: parent, presenter: presenter)
            answers.append(answer)
        }
        await fulfillment(of: [presented], timeout: 5)
        let navigation = try XCTUnwrap(presenter.presented as? TKNavigationController)
        let coordinator = try XCTUnwrap(parent.children.first as? PasscodeInputCoordinator)
        let lateInput = try XCTUnwrap(coordinator.didInputPasscode)
        let externalDismissal = try XCTUnwrap(navigation.didDismiss)

        task.cancel()
        await task.value
        lateInput("1234")
        externalDismissal()

        XCTAssertEqual(answers, [nil])
        XCTAssertEqual(presenter.dismissals, 0, "The request host owns dismissal of its entire stack")
        XCTAssertTrue(parent.children.isEmpty)
        XCTAssertNil(coordinator.didCancel)
        XCTAssertNil(coordinator.didInputPasscode)
    }

    func testNormalAnswerAndDismissalCallbacksResumeOnlyOnce() throws {
        for answer in [nil, "1234"] as [String?] {
            let presenter = Presenter()
            let parent = Parent()
            var answers: [String?] = []
            PasscodeInputCoordinator.present(
                parentCoordinator: parent,
                parentRouter: ViewControllerRouter(rootViewController: presenter),
                validator: Validator(),
                securityStore: securityStore(),
                onCancel: { answers.append(nil) },
                onInput: { answers.append($0) }
            )
            let coordinator = try XCTUnwrap(parent.children.first as? PasscodeInputCoordinator)
            let navigation = try XCTUnwrap(presenter.presented as? TKNavigationController)
            let dismissed = try XCTUnwrap(navigation.didDismiss)
            let input = try XCTUnwrap(coordinator.didInputPasscode)
            let cancel = try XCTUnwrap(coordinator.didCancel)

            if let answer { input(answer) } else { cancel() }
            cancel()
            input("late")
            XCTAssertTrue(answers.isEmpty)
            XCTAssertEqual(presenter.dismissals, 1)

            dismissed()
            XCTAssertTrue(answers.isEmpty, "Normal answers wait for the dismissal completion")
            XCTAssertEqual(parent.children.count, 1)
            presenter.completeDismissal?()
            dismissed()

            XCTAssertEqual(answers, [answer])
            XCTAssertTrue(parent.children.isEmpty)
        }
    }

    func testAnAlreadyCancelledRequestNeverPresentsPasscode() async {
        let parent = Parent()
        let presenter = Presenter()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await getPasscode(parent: parent, presenter: presenter)
        }
        let answer = await task.value

        XCTAssertNil(answer)
        XCTAssertNil(presenter.presented)
        XCTAssertTrue(parent.children.isEmpty)
    }

    func testStandaloneCancellationWaitsForPresentationAndDismissalCompletion() async {
        let parent = Parent()
        let presenter = Presenter()
        let presented = expectation(description: "passcode presented")
        let waiting = expectation(description: "waiting for transition")
        let dismissed = expectation(description: "dismissal requested")
        let pause = Pause()
        presenter.isPresenting = true
        presenter.didPresent = { presented.fulfill() }
        presenter.didDismiss = { dismissed.fulfill() }
        var returned = false
        let task = Task {
            let answer = await getPasscode(parent: parent, presenter: presenter, dismissOnCancellation: true, waitForTransitions: { _ in
                waiting.fulfill()
                await pause.wait()
            })
            returned = true
            return answer
        }
        await fulfillment(of: [presented], timeout: 5)

        task.cancel()
        await fulfillment(of: [waiting], timeout: 5)
        XCTAssertFalse(returned)
        XCTAssertEqual(parent.children.count, 1)
        XCTAssertEqual(presenter.dismissals, 0)

        presenter.isPresenting = false
        pause.release()
        await fulfillment(of: [dismissed], timeout: 5)
        (presenter.presented as? TKNavigationController)?.didDismiss?()
        XCTAssertFalse(returned)
        XCTAssertEqual(parent.children.count, 1)
        presenter.completeDismissal?()
        let answer = await task.value

        XCTAssertNil(answer)
        XCTAssertEqual(presenter.dismissals, 1)
        XCTAssertTrue(parent.children.isEmpty)
    }

    func testCancellationDoesNotDismissAModalThatReplacedThePasscode() async {
        let parent = Parent()
        let presenter = Presenter()
        let presented = expectation(description: "passcode presented")
        presenter.didPresent = { presented.fulfill() }
        let task = Task { await getPasscode(parent: parent, presenter: presenter, dismissOnCancellation: true) }
        await fulfillment(of: [presented], timeout: 5)
        presenter.presented = UIViewController()

        task.cancel()
        let answer = await task.value

        XCTAssertNil(answer)
        XCTAssertEqual(presenter.dismissals, 0)
        XCTAssertTrue(parent.children.isEmpty)
    }

    private func getPasscode(
        parent: Parent,
        presenter: Presenter,
        dismissOnCancellation: Bool = false,
        waitForTransitions: @escaping ModalTransitionWaiter.Wait = ModalTransitionWaiter.wait
    ) async -> String? {
        await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: parent,
            parentRouter: ViewControllerRouter(rootViewController: presenter),
            validator: Validator(),
            securityStore: securityStore(),
            dismissOnCancellation: dismissOnCancellation,
            waitForTransitions: waitForTransitions
        )
    }

    private func securityStore() -> SecurityStore {
        SecurityStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfo()))
    }
}

private extension PasscodeInputCoordinatorTests {
    final class Presenter: UIViewController {
        var presented: UIViewController?
        override var presentedViewController: UIViewController? {
            presented
        }

        var didPresent: (() -> Void)?
        var didDismiss: (() -> Void)?
        var isPresenting = false
        override var isBeingPresented: Bool {
            isPresenting
        }

        var dismissals = 0
        var completeDismissal: (() -> Void)?

        override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
            presented = viewControllerToPresent
            didPresent?()
            completion?()
        }

        override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
            dismissals += 1
            completeDismissal = completion
            didDismiss?()
        }
    }

    final class Parent: Coordinator {
        var children: [any Coordinator] = []

        func addChild(_ child: any Coordinator) {
            children.append(child)
        }

        func removeChild(_ child: (any Coordinator)?) {
            children.removeAll { $0 === child }
        }

        func start() {}
        func start(deeplink: CoordinatorDeeplink?) {}
        func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
            false
        }

        func didMoveTo(toParent parent: (any Coordinator)?) {}
    }

    struct Validator: PasscodeInputValidator {
        func validate(passcode: String) async -> PasscodeInputValidationResult {
            .none
        }

        func getPasscode() throws -> String {
            "1234"
        }

        func refreshStoredPasscode(_ passcode: String) throws {}
    }

    struct EmptyKeeperInfo: KeeperInfoRepository {
        func getKeeperInfo() throws -> KeeperInfo {
            throw CancellationError()
        }

        func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {}
        func removeKeeperInfo() throws {}
    }

    @MainActor
    final class Pause {
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false
        func wait() async {
            guard !released else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }
}
