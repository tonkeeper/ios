import UIKit

enum HintClippedEdge {
    case top
    case bottom
}

struct HintAnchor {
    /// The visible part of the source or, once it is scrolled out, a strip along the edge it left through.
    var frame: CGRect
    /// The scroll view edge the source is cut off at, so the hint stays on screen and its tail points across it.
    var clippedEdge: HintClippedEdge?
    /// An enclosing scroll view hides some of the source.
    var isClipped = false
    /// The user can scroll whatever hides the source into view; a hint points across an edge only then.
    var isRevealable = true
}

extension UIView {
    /// The part of the view that is not scrolled out of an enclosing scroll view or under the bars laid over it.
    func hintVisibleFrame(in window: UIWindow) -> CGRect? {
        let visibleFrame = enclosingScrollViews.reduce(convert(bounds, to: window)) { frame, scrollView in
            frame.intersection(scrollView.convert(scrollView.visibleContentFrame, to: window))
        }
        return visibleFrame.isEmpty ? nil : visibleFrame
    }

    func hintAnchor(in window: UIWindow) -> HintAnchor {
        var anchor = HintAnchor(frame: convert(bounds, to: window))
        for scrollView in enclosingScrollViews {
            let visibleFrame = scrollView.convert(scrollView.visibleContentFrame, to: window)
            guard visibleFrame.width > 0, visibleFrame.height > 0 else {
                continue
            }
            // Less than a point past the edge is rounding, not clipping.
            let isClippedAtTop = visibleFrame.minY - anchor.frame.minY >= 1
            let isClippedAtBottom = anchor.frame.maxY - visibleFrame.maxY >= 1
            let isClippedAtSide = visibleFrame.minX - anchor.frame.minX >= 1 || anchor.frame.maxX - visibleFrame.maxX >= 1
            if isClippedAtTop != isClippedAtBottom {
                anchor.clippedEdge = isClippedAtTop ? .top : .bottom
            }
            if isClippedAtTop || isClippedAtBottom || isClippedAtSide {
                anchor.isClipped = true
                anchor.isRevealable = anchor.isRevealable && scrollView.canReveal(convert(bounds, to: scrollView))
            }
            anchor.frame = anchor.frame.clamped(into: visibleFrame)
        }
        return anchor
    }

    /// The content offsets that put the view's top at the top of the visible area, innermost scroll view first.
    func topAligningMoves() -> [(scrollView: UIScrollView, contentOffset: CGPoint)] {
        var moves = [(scrollView: UIScrollView, contentOffset: CGPoint)]()
        // An inner scroll view's move shifts the view inside every outer one.
        var shift = CGPoint.zero
        for scrollView in enclosingScrollViews {
            let frame = convert(bounds, to: scrollView).offsetBy(dx: -shift.x, dy: -shift.y)
            let contentOffset = scrollView.contentOffset(aligningTopOf: frame)
            shift.x += contentOffset.x - scrollView.contentOffset.x
            shift.y += contentOffset.y - scrollView.contentOffset.y
            if contentOffset != scrollView.contentOffset {
                moves.append((scrollView, contentOffset))
            }
        }
        return moves
    }

    /// Innermost first.
    private var enclosingScrollViews: [UIScrollView] {
        sequence(first: self, next: \.superview).dropFirst().compactMap { $0 as? UIScrollView }
    }
}

public extension UIView {
    var isWithinVisibleScrollArea: Bool {
        guard let window, !bounds.isEmpty, let visibleFrame = hintVisibleFrame(in: window) else {
            return false
        }
        let frame = convert(bounds, to: window)
        return visibleFrame.width >= frame.width - 1 && visibleFrame.height >= frame.height - 1
    }

    var nearestEnclosingScrollView: UIScrollView? {
        enclosingScrollViews.first
    }

    /// Scrolls the enclosing scroll views until the view's top is as close to the top of their visible area as the
    /// content lets it get.
    func scrollToTopOfVisibleArea(animated: Bool) {
        for move in topAligningMoves() {
            move.scrollView.setContentOffset(move.contentOffset, animated: animated)
        }
    }
}

private extension UIScrollView {
    var visibleContentFrame: CGRect {
        bounds.inset(by: safeAreaInsets)
    }

    func canReveal(_ frame: CGRect) -> Bool {
        guard isScrollEnabled, isUserInteractionEnabled else {
            return false
        }
        let offset = contentOffset(revealing: frame)
        let revealedFrame = visibleContentFrame
            .offsetBy(dx: offset.x - contentOffset.x, dy: offset.y - contentOffset.y)
            .intersection(frame)
        return revealedFrame.width >= 1 && revealedFrame.height >= 1
    }

    /// The nearest content offset that shows `frame`, given in the scroll view's own coordinates, as far as the
    /// content lets it scroll.
    func contentOffset(revealing frame: CGRect) -> CGPoint {
        let visibleFrame = visibleContentFrame
        return clampedContentOffset(CGPoint(
            x: contentOffset.x + revealingShift(of: frame.minX ... frame.maxX, into: visibleFrame.minX ... visibleFrame.maxX),
            y: contentOffset.y + revealingShift(of: frame.minY ... frame.maxY, into: visibleFrame.minY ... visibleFrame.maxY)
        ))
    }

    /// Like `contentOffset(revealing:)`, with the top of `frame` brought up to the top of the visible area.
    func contentOffset(aligningTopOf frame: CGRect) -> CGPoint {
        let visibleFrame = visibleContentFrame
        return clampedContentOffset(CGPoint(
            x: contentOffset.x + revealingShift(of: frame.minX ... frame.maxX, into: visibleFrame.minX ... visibleFrame.maxX),
            y: contentOffset.y + frame.minY - visibleFrame.minY
        ))
    }

    func clampedContentOffset(_ offset: CGPoint) -> CGPoint {
        let insets = adjustedContentInset
        let minOffset = CGPoint(x: -insets.left, y: -insets.top)
        let maxOffset = CGPoint(
            x: max(minOffset.x, contentSize.width + insets.right - bounds.width),
            y: max(minOffset.y, contentSize.height + insets.bottom - bounds.height)
        )
        return CGPoint(
            x: min(max(offset.x, minOffset.x), maxOffset.x),
            y: min(max(offset.y, minOffset.y), maxOffset.y)
        )
    }

    /// Moves a range that sticks out of the limits back in, its start first when it is longer than they are.
    func revealingShift(of range: ClosedRange<CGFloat>, into limits: ClosedRange<CGFloat>) -> CGFloat {
        if range.lowerBound < limits.lowerBound {
            return range.lowerBound - limits.lowerBound
        }
        if range.upperBound > limits.upperBound {
            return min(range.upperBound - limits.upperBound, range.lowerBound - limits.lowerBound)
        }
        return 0
    }
}

private extension CGRect {
    /// The overlap with `container`, or a one-point strip inside the container edge this rect lies beyond.
    func clamped(into container: CGRect) -> CGRect {
        let x = (minX ... maxX).clamped(into: container.minX ... container.maxX)
        let y = (minY ... maxY).clamped(into: container.minY ... container.maxY)
        return CGRect(
            x: x.lowerBound,
            y: y.lowerBound,
            width: x.upperBound - x.lowerBound,
            height: y.upperBound - y.lowerBound
        )
    }
}

private extension ClosedRange<CGFloat> {
    func clamped(into limits: Self) -> Self {
        if lowerBound >= limits.upperBound {
            return Swift.max(limits.upperBound - 1, limits.lowerBound) ... limits.upperBound
        }
        if upperBound <= limits.lowerBound {
            return limits.lowerBound ... Swift.min(limits.lowerBound + 1, limits.upperBound)
        }
        return clamped(to: limits)
    }
}
