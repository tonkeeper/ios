import OperationReviewModels
import TKLogging
import TKUIKit
import UIKit

/// Asks the user about a review on a findings sheet over the host screen. The answer comes once the
/// sheet is gone, so a passcode or Ledger sheet that follows never presents from a sheet on its way out.
@MainActor
public final class OperationConsentPresenter {
    /// Presents the sheet and calls `sheetIsGone` once it is taken off screen, or at once when it never
    /// got on it.
    typealias Present = @MainActor (
        _ sheet: TKBottomSheetViewController,
        _ source: UIViewController,
        _ sheetIsGone: @escaping () -> Void
    ) -> Void
    typealias Dismiss = @MainActor (_ sheet: TKBottomSheetViewController, _ completion: @escaping () -> Void) -> Void

    private struct Asking {
        let sheet: TKBottomSheetViewController
        let continuation: CheckedContinuation<Bool, Never>
        /// The button the user tapped; the sheet is on its way out then.
        var tapped: Bool?
    }

    private enum State {
        case ready
        case asking(Asking)
        case hostLeft
    }

    fileprivate enum Refusal: String, Error {
        case pending, hostLeft, cancelled, offScreen, overClosingSheet
    }

    private let host: @MainActor () -> UIViewController?
    private let present: Present
    private let dismiss: Dismiss
    private var state = State.ready

    public convenience init(host: @escaping @MainActor () -> UIViewController?) {
        self.init(
            host: host,
            present: { sheet, source, sheetIsGone in
                sheet.present(fromViewController: source)
                guard let navigation = sheet.navigationController as? TKNavigationController,
                      navigation.presentingViewController != nil
                else {
                    // UIKit drops a presentation it cannot make, e.g. from a modal still sliding in.
                    sheetIsGone()
                    return
                }
                navigation.didDismiss = sheetIsGone
            },
            dismiss: { sheet, completion in sheet.dismiss(completion: completion) }
        )
    }

    init(host: @escaping @MainActor () -> UIViewController?, present: @escaping Present, dismiss: @escaping Dismiss) {
        self.host = host
        self.present = present
        self.dismiss = dismiss
    }

    /// `true` when the user confirms anyway. Refused without asking when the host is not in a window or
    /// has left, when the sheet would land on one that is closing, while another review is asked and in
    /// a cancelled task; a task cancelled while the sheet is up refuses and closes it.
    public func ask(_ review: OperationReview) async -> Bool {
        let source: UIViewController
        switch sheetSource() {
        case let .success(found):
            source = found
        case let .failure(refusal):
            Log.w("Operation review was refused without asking", extraInfo: ["review": review.id, "reason": refusal.rawValue])
            return false
        }
        let sheet = makeSheet(review)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                state = .asking(Asking(sheet: sheet, continuation: continuation))
                present(sheet, source) { [weak self, weak sheet] in
                    sheet.map { self?.sheetIsGone($0) }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.refuse(on: sheet)
            }
        }
    }

    /// For the host's `viewDidDisappear` once it has left for good: a pending review is refused and
    /// its sheet closed, and every later one is refused. Set `dismissSheet` to false when the host's
    /// presenter dismisses the whole modal stack itself.
    public func hostDidLeave() {
        hostDidLeave(dismissSheet: true)
    }

    public func hostDidLeave(dismissSheet: Bool) {
        if case let .asking(asking) = state {
            finish(false, on: asking.sheet)
            state = .hostLeft
            if dismissSheet {
                dismiss(asking.sheet) {}
            }
        }
        state = .hostLeft
    }

    /// A fresh confirm attempt that asks through this presenter.
    public func consent() -> OperationConsent {
        OperationConsent { [weak self] review in
            await self?.ask(review) ?? false
        }
    }
}

private extension OperationConsentPresenter {
    func sheetSource() -> Result<UIViewController, Refusal> {
        switch state {
        case .asking:
            return .failure(.pending)
        case .hostLeft:
            return .failure(.hostLeft)
        case .ready:
            break
        }
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        guard let host = host(), host.viewIfLoaded?.window != nil else {
            return .failure(.offScreen)
        }
        let source = host.modalPresentationSourceViewController()
        return source.isLeaving ? .failure(.overClosingSheet) : .success(source)
    }

    func makeSheet(_ review: OperationReview) -> TKBottomSheetViewController {
        weak var shown: TKBottomSheetViewController?
        // A scroll host: a long list of findings would push the buttons off a short screen otherwise.
        let sheet = TKBottomSheetViewController(contentViewController: TKBottomSheetScrollHostingController(header: .popup) {
            OperationFindingsView(review: review) { [weak self] in
                shown.map { self?.answer(true, on: $0) }
            } onCancel: { [weak self] in
                shown.map { self?.answer(false, on: $0) }
            }
        })
        // Called once a sheet the user swiped or tapped away is gone.
        sheet.didClose = { [weak self, weak sheet] _ in
            sheet.map { self?.finish(false, on: $0) }
        }
        shown = sheet
        return sheet
    }

    /// The sheet's own buttons. A sheet already on its way out takes no other answer.
    func answer(_ isConfirmed: Bool, on sheet: TKBottomSheetViewController) {
        guard case var .asking(asking) = state, asking.sheet === sheet, asking.tapped == nil, !sheet.isDismissing else {
            return
        }
        asking.tapped = isConfirmed
        state = .asking(asking)
        dismiss(sheet) { [weak self] in
            self?.finish(isConfirmed, on: sheet)
        }
    }

    /// The sheet is off screen, whoever took it, a deeplink closing every modal say: unanswered, that is
    /// Cancel. After a tap the sheet's own dismissal answers instead, unless the sheet was taken while it
    /// slid out, which can drop that dismissal's completion.
    func sheetIsGone(_ sheet: TKBottomSheetViewController) {
        guard case let .asking(asking) = state, asking.sheet === sheet, asking.tapped == nil || sheet.isDismissing else {
            return
        }
        finish(asking.tapped ?? false, on: sheet)
    }

    func refuse(on sheet: TKBottomSheetViewController) {
        guard isAsking(on: sheet) else {
            return
        }
        finish(false, on: sheet)
        dismiss(sheet) {}
    }

    func finish(_ answer: Bool, on sheet: TKBottomSheetViewController) {
        guard case let .asking(asking) = state, asking.sheet === sheet else {
            return
        }
        state = .ready
        asking.continuation.resume(returning: answer)
    }

    func isAsking(on sheet: TKBottomSheetViewController) -> Bool {
        guard case let .asking(asking) = state else {
            return false
        }
        return asking.sheet === sheet
    }
}

private extension UIViewController {
    /// A modal on its way out takes whatever is presented on it along.
    var isLeaving: Bool {
        isBeingDismissed || ((self as? UINavigationController)?.viewControllers.first as? TKBottomSheetViewController)?.isDismissing == true
    }
}
