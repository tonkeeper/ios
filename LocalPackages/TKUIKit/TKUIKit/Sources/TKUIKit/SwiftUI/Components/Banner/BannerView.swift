import SwiftUI

public struct BannerView: View {
    @Environment(\.tkPalette) private var palette

    let items: [BannerItem]
    let onDismiss: (BannerItem, _ remainingCount: Int) -> Void
    let onItemShown: ((BannerItem) -> Void)?

    @State private var stackOrder: BannerStackOrder
    @State private var isAnimatingPopStack = false
    @State private var isTrackingHorizontalSwipe = false
    @State private var isCurrentItemTapSuppressed = false
    @GestureState private var isSwipeGestureActive = false
    @State private var currentItemHorizontalOffset: CGFloat = 0
    @State private var dismissalProgress: CGFloat = 0
    @State private var currentItemPromotionProgress: CGFloat = 1
    @State private var outgoingSwipeItem: BannerItem?
    @State private var outgoingSwipeItemOffset: CGFloat = 0

    public init(
        items: [BannerItem],
        onDismiss: @escaping (BannerItem, _ remainingCount: Int) -> Void = { _, _ in },
        onItemShown: ((BannerItem) -> Void)? = nil
    ) {
        self.items = items
        self.onDismiss = onDismiss
        self.onItemShown = onItemShown
        self.stackOrder = BannerStackOrder(itemIDs: items.map(\.id))
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let previousPreviousItem {
                    BannerItemView(
                        item: previousPreviousItem,
                        height: Layout.height
                    )
                    .overlay {
                        palette.background.content
                            .clipShape(bannerItemShape)
                    }
                    .scaleEffect(
                        x: Layout.downscaleCoefficient,
                        y: Layout.downscaleCoefficient,
                        anchor: .topLeading
                    )
                    .offset(
                        x: proxy.size.width * (1 - Layout.downscaleCoefficient) / 2,
                        y: Layout.height * (1 - Layout.downscaleCoefficient) + Layout.downscaleVerticalOffset
                    )
                }
                if let previousItem {
                    BannerItemView(
                        item: previousItem,
                        height: Layout.height
                    )
                    .overlay {
                        palette.background.content
                            .opacity(1 - dismissalProgress)
                            .clipShape(bannerItemShape)
                    }
                    .scaleEffect(
                        x: downscaleCoefficient(progress: dismissalProgress),
                        y: downscaleCoefficient(progress: dismissalProgress),
                        anchor: .topLeading
                    )
                    .offset(
                        x: stackItemHorizontalOffset(containerWidth: proxy.size.width, progress: dismissalProgress),
                        y: stackItemVerticalOffset(progress: dismissalProgress)
                    )
                }
                if let currentItem {
                    BannerItemView(
                        item: currentItem,
                        height: Layout.height,
                        onTapDismiss: {
                            popStack()
                        },
                        isTapEnabled: !isCurrentItemTapSuppressed
                    )
                    .overlay {
                        palette.background.content
                            .opacity(1 - currentItemPromotionProgress)
                            .clipShape(bannerItemShape)
                    }
                    .scaleEffect(
                        x: downscaleCoefficient(progress: currentItemPromotionProgress),
                        y: downscaleCoefficient(progress: currentItemPromotionProgress),
                        anchor: .topLeading
                    )
                    .offset(
                        x: currentItemHorizontalOffset + stackItemHorizontalOffset(
                            containerWidth: proxy.size.width,
                            progress: currentItemPromotionProgress
                        ),
                        y: stackItemVerticalOffset(progress: currentItemPromotionProgress)
                    )
                    .blur(radius: currentItemBlurRadius)
                    .opacity(currentItemOpacity)
                    .simultaneousGesture(horizontalSwipeGesture(containerWidth: proxy.size.width))
                }
                if let outgoingSwipeItem {
                    BannerItemView(
                        item: outgoingSwipeItem,
                        height: Layout.height
                    )
                    .offset(x: outgoingSwipeItemOffset)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: Layout.height, alignment: .top)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.downscaleVerticalOffset)
        .onChange(of: itemIDs) { _ in
            syncStackOrderWithItems()
        }
        .onAppear {
            notifyCurrentItemShown()
        }
        .onChange(of: stackOrder.currentID) { _ in
            notifyCurrentItemShown()
        }
        .onChange(of: isSwipeGestureActive) { isActive in
            guard !isActive else { return }
            DispatchQueue.main.async {
                isCurrentItemTapSuppressed = false
                // GestureState resets before onEnded; the second hop lets a pending
                // onEnded run first, so only a truly cancelled gesture is rolled back.
                DispatchQueue.main.async {
                    guard !isSwipeGestureActive, isTrackingHorizontalSwipe else { return }
                    cancelSwipeDismissal()
                }
            }
        }
    }

    private func notifyCurrentItemShown() {
        guard let currentItem else { return }
        onItemShown?(currentItem)
    }

    private var itemIDs: [String] {
        items.map(\.id)
    }

    private var currentItem: BannerItem? {
        stackItem(id: stackOrder.currentID)
    }

    private var previousItem: BannerItem? {
        stackItem(id: stackOrder.previousID)
    }

    private var previousPreviousItem: BannerItem? {
        stackItem(id: stackOrder.presentationPreviousPreviousID(isSwipePresentationActive: isSwipePresentationActive))
    }

    private var outgoingSwipeItemID: String? {
        outgoingSwipeItem?.id
    }

    private var isSwipeEnabled: Bool {
        stackOrder.canCycleCurrentItem
    }

    private var itemsByID: [String: BannerItem] {
        items.reduce(into: [String: BannerItem]()) { result, item in
            result[item.id] = item
        }
    }

    private func item(id: String?) -> BannerItem? {
        guard let id else {
            return nil
        }

        return itemsByID[id]
    }

    private func stackItem(id: String?) -> BannerItem? {
        guard id != outgoingSwipeItemID || stackOrder.count == 2 else {
            return nil
        }

        return item(id: id)
    }

    private var currentItemBlurRadius: CGFloat {
        isCurrentItemBeingSwiped ? 0 : Layout.blurRadius * dismissalProgress
    }

    private var currentItemOpacity: CGFloat {
        isCurrentItemBeingSwiped ? 1 : 1 - dismissalProgress
    }

    private var isSwipePresentationActive: Bool {
        isTrackingHorizontalSwipe || currentItemHorizontalOffset != 0
    }

    private var isCurrentItemBeingSwiped: Bool {
        isSwipePresentationActive
    }

    private var bannerItemShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: BannerItemModifier.Layout.cornerRadius,
            style: .continuous
        )
    }

    private func downscaleCoefficient(progress: CGFloat) -> CGFloat {
        let initial = Layout.downscaleCoefficient
        return initial + (1 - initial) * progress
    }

    private func stackItemHorizontalOffset(containerWidth: CGFloat, progress: CGFloat) -> CGFloat {
        containerWidth * (1 - downscaleCoefficient(progress: progress)) / 2
    }

    private func stackItemVerticalOffset(progress: CGFloat) -> CGFloat {
        Layout.height * (1 - downscaleCoefficient(progress: progress)) + Layout.downscaleVerticalOffset * (1 - progress)
    }

    private func popStack() {
        guard !isAnimatingPopStack, !isTrackingHorizontalSwipe else {
            return
        }

        guard let dismissedItem = currentItem else {
            return resetDismissalState()
        }

        isAnimatingPopStack = true
        withTransaction(Transaction(animation: nil)) {
            dismissalProgress = 0
        }

        withAnimation(Layout.popAnimation) {
            dismissalProgress = 1
        }

        onDismiss(dismissedItem, max(0, stackOrder.count - 1))

        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.popAnimationDuration) {
            guard isAnimatingPopStack else {
                return
            }

            finishTapDismissal(dismissedItem)
        }
    }

    private func horizontalSwipeGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: Layout.swipeMinimumDistance, coordinateSpace: .local)
            .updating($isSwipeGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                updateSwipe(value, containerWidth: containerWidth)
            }
            .onEnded { value in
                endSwipe(value, containerWidth: containerWidth)
            }
    }

    private func updateSwipe(_ value: DragGesture.Value, containerWidth: CGFloat) {
        guard isSwipeEnabled,
              !isAnimatingPopStack
        else {
            return
        }

        if !isTrackingHorizontalSwipe {
            guard abs(value.translation.width) > abs(value.translation.height) else {
                return
            }

            finishCurrentItemPromotion()
            isTrackingHorizontalSwipe = true
            isCurrentItemTapSuppressed = true
        }

        withTransaction(Transaction(animation: nil)) {
            currentItemHorizontalOffset = value.translation.width
            dismissalProgress = swipeDismissalProgress(
                offset: value.translation.width,
                containerWidth: containerWidth
            )
        }
    }

    private func endSwipe(_ value: DragGesture.Value, containerWidth: CGFloat) {
        guard isSwipeEnabled,
              isTrackingHorizontalSwipe
        else {
            return
        }

        if abs(value.translation.width) >= swipeDismissalThreshold(containerWidth: containerWidth) {
            completeSwipeDismissal(offset: value.translation.width, containerWidth: containerWidth)
        } else {
            cancelSwipeDismissal()
        }
    }

    private func completeSwipeDismissal(offset: CGFloat, containerWidth: CGFloat) {
        guard isSwipeEnabled,
              let dismissedItem = currentItem
        else {
            resetDismissalState()
            return
        }

        let direction: CGFloat = offset < 0 ? -1 : 1
        let initialOffset = currentItemHorizontalOffset
        let promotionProgress = dismissalProgress

        withTransaction(Transaction(animation: nil)) {
            outgoingSwipeItem = dismissedItem
            outgoingSwipeItemOffset = initialOffset
            stackOrder.moveCurrentToBottom()
            currentItemPromotionProgress = promotionProgress
            resetDismissalState()
        }

        DispatchQueue.main.async {
            guard outgoingSwipeItemID == dismissedItem.id else { return }
            withAnimation(Layout.swipeDismissAnimation) {
                outgoingSwipeItemOffset = direction * (containerWidth + Layout.swipeOffscreenOffset)
            }
            withAnimation(Layout.popAnimation) {
                currentItemPromotionProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.swipeDismissAnimationDuration) {
            guard outgoingSwipeItemID == dismissedItem.id else { return }
            resetOutgoingSwipeItem()
        }
    }

    private func cancelSwipeDismissal() {
        isTrackingHorizontalSwipe = false

        withAnimation(Layout.swipeReturnAnimation) {
            currentItemHorizontalOffset = 0
            dismissalProgress = 0
        }
    }

    private func resetDismissalState() {
        currentItemHorizontalOffset = 0
        dismissalProgress = 0
        isTrackingHorizontalSwipe = false
        isAnimatingPopStack = false
    }

    private func finishCurrentItemPromotion() {
        guard currentItemPromotionProgress != 1 else { return }
        withTransaction(Transaction(animation: nil)) {
            currentItemPromotionProgress = 1
        }
    }

    private func resetOutgoingSwipeItem() {
        outgoingSwipeItem = nil
        outgoingSwipeItemOffset = 0
    }

    private func finishTapDismissal(_ dismissedItem: BannerItem) {
        withTransaction(Transaction(animation: nil)) {
            stackOrder.remove(id: dismissedItem.id)
            resetDismissalState()
        }
    }

    private func syncStackOrderWithItems() {
        withTransaction(Transaction(animation: nil)) {
            stackOrder.sync(with: itemIDs)
            resetDismissalState()
            finishCurrentItemPromotion()
            resetOutgoingSwipeItem()
        }
    }

    private func swipeDismissalProgress(offset: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let fullProgressOffset = max(containerWidth, 1)
        return min(abs(offset) / fullProgressOffset, 1)
    }

    private func swipeDismissalThreshold(containerWidth: CGFloat) -> CGFloat {
        min(
            Layout.swipeMaximumDismissThreshold,
            max(Layout.swipeMinimumDismissThreshold, containerWidth * Layout.swipeDismissThresholdRatio)
        )
    }
}

extension BannerView {
    enum Layout {
        static let downscaleCoefficient: CGFloat = 318.0 / 358.0
        static let downscaleVerticalOffset: CGFloat = 10
        static let blurRadius: CGFloat = 5
        static let height: CGFloat = 90
        static let horizontalPadding: CGFloat = 16
        static let popAnimationDuration: TimeInterval = 0.5
        static let popAnimation: Animation = .easeInOut(duration: popAnimationDuration)
        static let swipeMinimumDistance: CGFloat = 3
        static let swipeDismissThresholdRatio: CGFloat = 0.32
        static let swipeMinimumDismissThreshold: CGFloat = 96
        static let swipeMaximumDismissThreshold: CGFloat = 180
        static let swipeOffscreenOffset: CGFloat = 40
        static let swipeDismissAnimationDuration: TimeInterval = 0.24
        static let swipeDismissAnimation: Animation = .easeOut(duration: swipeDismissAnimationDuration)
        static let swipeReturnAnimation: Animation = .easeOut(duration: 0.24)
    }
}
