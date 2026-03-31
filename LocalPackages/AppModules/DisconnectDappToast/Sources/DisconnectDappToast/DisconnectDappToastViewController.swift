import SwiftUI
import TKLogging
import TKUIKit
import UIKit

final class DisconnectDappToastViewController: GenericViewViewController<TKPassthroughView> {
    var didHide: (() -> Void)?

    private var currentToastViewController: UIHostingController<DisconnectDappToastView>?
    private var presentAction: (() -> Void)?
    private var dismissTask: DispatchWorkItem?

    deinit {
        Log.d("\(String(describing: self)) deinit")
    }

    func present(model: DisconnectDappToastModel) {
        let presentAction = { [weak self] in
            guard let self else { return }
            let toastViewController = UIHostingController(
                rootView: DisconnectDappToastView(
                    text: model.title,
                    buttonTitle: model.buttonTitle,
                    buttonAction: { [weak self] in
                        self?.hide {
                            self?.didHide?()
                        }
                        model.buttonAction()
                    }
                )
            )
            toastViewController.view.backgroundColor = .clear
            if #available(iOS 16.4, *) {
                toastViewController.safeAreaRegions = []
            }
            setupToastViewGesture(toastView: toastViewController.view)

            currentToastViewController = toastViewController

            addChild(toastViewController)
            view.addSubview(toastViewController.view)
            toastViewController.didMove(toParent: self)

            toastViewController.view.snp.makeConstraints { make in
                make.left.right.equalTo(self.view)
                    .inset(16)
                make.bottom.equalTo(self.view.snp.top)
            }

            view.layoutIfNeeded()

            toastViewController.view.snp.remakeConstraints { make in
                make.left.right.equalTo(self.view)
                    .inset(16)
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            }

            UIView.animate(
                withDuration: Constants.springAnimationDuration,
                delay: 0,
                usingSpringWithDamping: Constants.springAnimationDamping,
                initialSpringVelocity: Constants.springAnimationInitialVelocity,
                options: .allowUserInteraction,
                animations: {
                    self.view.layoutIfNeeded()
                }, completion: { [weak self] _ in
                    let dismissTask = DispatchWorkItem { [weak self] in
                        guard self?.dismissTask?.isCancelled == false else { return }
                        self?.dismissTask = nil
                        self?.hide(completion: {
                            self?.didHide?()
                        })
                    }
                    self?.dismissTask = dismissTask
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Constants.hideTimeout,
                        execute: dismissTask
                    )
                }
            )
        }

        if currentToastViewController != nil {
            hide(completion: presentAction)
        } else {
            presentAction()
        }
    }

    func hide(completion: (() -> Void)?) {
        guard let currentToastViewController else {
            completion?()
            return
        }
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveEaseOut
        ) {
            currentToastViewController.view.alpha = 0
        } completion: { _ in
            completion?()
        }
    }

    func setupToastViewGesture(toastView: UIView) {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognizerHandle(recognizer:)))
        toastView.addGestureRecognizer(gesture)
    }

    @objc
    func panGestureRecognizerHandle(recognizer: UIPanGestureRecognizer) {
        let velocity = recognizer.velocity(in: recognizer.view)
        let translation = recognizer.translation(in: recognizer.view)
        let isBottom = velocity.y > 0

        switch recognizer.state {
        case .changed:
            let yTranslation = min(30, translation.y)
            recognizer.view?.transform = CGAffineTransform(translationX: 0, y: yTranslation)
        case .ended:
            if !isBottom, velocity.y <= -Constants.draggingVelocityTreshold || translation.y <= -(recognizer.view?.bounds.height ?? 0) * 0.6 {
                UIView.animate(
                    withDuration: Constants.springAnimationDuration,
                    delay: 0,
                    usingSpringWithDamping: Constants.springAnimationDamping,
                    initialSpringVelocity: Constants.springAnimationInitialVelocity, animations: {
                        recognizer.view?.transform = CGAffineTransform(translationX: 0, y: -(recognizer.view?.bounds.height ?? 0) - self.view.safeAreaInsets.top)
                    }, completion: { _ in
                        self.didHide?()
                    }
                )
            } else {
                UIView.animate(
                    withDuration: Constants.springAnimationDuration,
                    delay: 0,
                    usingSpringWithDamping: Constants.springAnimationDamping,
                    initialSpringVelocity: Constants.springAnimationInitialVelocity
                ) {
                    recognizer.view?.transform = .identity
                }
            }
        case .cancelled, .failed:
            UIView.animate(
                withDuration: Constants.springAnimationDuration,
                delay: 0,
                usingSpringWithDamping: Constants.springAnimationDamping,
                initialSpringVelocity: Constants.springAnimationInitialVelocity
            ) {
                recognizer.view?.transform = .identity
            }
        default:
            break
        }
    }
}

private enum Constants {
    static let hideTimeout: TimeInterval = 15
    static let springAnimationDuration: TimeInterval = 0.3
    static let springAnimationDamping: CGFloat = 0.7
    static let springAnimationInitialVelocity: CGFloat = 0.5
    static let draggingVelocityTreshold: CGFloat = 1000
}
