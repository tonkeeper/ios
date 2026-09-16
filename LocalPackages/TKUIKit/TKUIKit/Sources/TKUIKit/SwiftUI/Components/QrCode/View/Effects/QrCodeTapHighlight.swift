import UIKit

struct QrCodeTapHighlight: Equatable {
    let origin: CGPoint
    let transitionID: UUID

    private let startProgress: CGFloat
    private let targetProgress: CGFloat
    private let transitionStartDate: Date
    private let duration: TimeInterval

    init(
        origin: CGPoint,
        date: Date,
        duration: TimeInterval = QrCodeViewLayout.tapHighlightAnimationDuration
    ) {
        self.init(
            origin: origin,
            startProgress: 0,
            targetProgress: 1,
            transitionStartDate: date,
            duration: duration,
            transitionID: UUID()
        )
    }

    private init(
        origin: CGPoint,
        startProgress: CGFloat,
        targetProgress: CGFloat,
        transitionStartDate: Date,
        duration: TimeInterval,
        transitionID: UUID
    ) {
        self.origin = origin
        self.startProgress = startProgress.clamped(to: 0 ... 1)
        self.targetProgress = targetProgress.clamped(to: 0 ... 1)
        self.transitionStartDate = transitionStartDate
        self.duration = max(0, duration)
        self.transitionID = transitionID
    }

    func progress(at date: Date) -> CGFloat {
        guard duration > 0 else {
            return targetProgress
        }

        let elapsed = date.timeIntervalSince(transitionStartDate)
        let linearProgress = CGFloat(elapsed / duration).clamped(to: 0 ... 1)
        let easedProgress = Self.easeInOut(linearProgress)
        let progress = startProgress + (targetProgress - startProgress) * easedProgress
        return progress.clamped(to: 0 ... 1)
    }

    func pressing(
        at date: Date,
        origin: CGPoint,
        duration: TimeInterval = QrCodeViewLayout.tapHighlightAnimationDuration
    ) -> QrCodeTapHighlight {
        guard targetProgress != 1 else {
            return QrCodeTapHighlight(
                origin: origin,
                startProgress: startProgress,
                targetProgress: targetProgress,
                transitionStartDate: transitionStartDate,
                duration: self.duration,
                transitionID: transitionID
            )
        }

        return transitioning(
            to: 1,
            at: date,
            origin: origin,
            duration: duration
        )
    }

    func releasing(
        at date: Date,
        duration: TimeInterval = QrCodeViewLayout.tapHighlightAnimationDuration
    ) -> QrCodeTapHighlight {
        guard targetProgress != 0 else {
            return self
        }

        return transitioning(
            to: 0,
            at: date,
            origin: origin,
            duration: duration
        )
    }

    func isAnimating(at date: Date) -> Bool {
        guard startProgress != targetProgress else {
            return false
        }

        let elapsed = date.timeIntervalSince(transitionStartDate)
        return elapsed >= 0 && elapsed < duration
    }

    func remainingAnimationDuration(at date: Date) -> TimeInterval {
        guard isAnimating(at: date) else {
            return 0
        }

        let elapsed = date.timeIntervalSince(transitionStartDate)
        return max(0, duration - elapsed)
    }

    func resolved(at date: Date) -> QrCodeTapHighlight? {
        let progress = progress(at: date)
        guard progress > 0 || targetProgress > 0 else {
            return nil
        }

        return QrCodeTapHighlight(
            origin: origin,
            startProgress: progress,
            targetProgress: targetProgress,
            transitionStartDate: date,
            duration: duration,
            transitionID: transitionID
        )
    }

    private func transitioning(
        to targetProgress: CGFloat,
        at date: Date,
        origin: CGPoint,
        duration: TimeInterval
    ) -> QrCodeTapHighlight {
        QrCodeTapHighlight(
            origin: origin,
            startProgress: progress(at: date),
            targetProgress: targetProgress,
            transitionStartDate: date,
            duration: duration,
            transitionID: UUID()
        )
    }

    private static func easeInOut(_ progress: CGFloat) -> CGFloat {
        progress * progress * (3 - 2 * progress)
    }
}
