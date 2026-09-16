import SwiftUI
import UIKit

public extension View {
    /// Presents SwiftUI content in a `TKBottomSheetViewController`, so the sheet chrome, drag
    /// physics and header are the same ones the UIKit screens use.
    ///
    /// - Parameter header: Built with the sheet's own dismissal, so a custom button needs no state
    /// of its own at the call site. Returning `nil` keeps the sheet's default close-only header.
    func tkBottomSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        header: @escaping (_ dismiss: @escaping () -> Void) -> TKBottomSheetHeaderConfiguration? = { _ in nil },
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            TKBottomSheetModifier(
                item: Binding(
                    get: { isPresented.wrappedValue ? TKBottomSheetPresentedItem() : nil },
                    set: { isPresented.wrappedValue = $0 != nil }
                ),
                header: { _, dismiss in header(dismiss) },
                sheetContent: { _ in content() }
            )
        )
    }

    /// - Parameter header: Built with the presented item and the sheet's own dismissal. Returning
    /// `nil` keeps the sheet's default close-only header.
    func tkBottomSheet<Item: Hashable, SheetContent: View>(
        item: Binding<Item?>,
        header: @escaping (_ item: Item, _ dismiss: @escaping () -> Void) -> TKBottomSheetHeaderConfiguration? = { _, _ in nil },
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(
            TKBottomSheetModifier(
                item: item,
                header: header,
                sheetContent: content
            )
        )
    }
}

private struct TKBottomSheetPresentedItem: Hashable {}

private struct TKBottomSheetModifier<Item: Hashable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let header: (Item, @escaping () -> Void) -> TKBottomSheetHeaderConfiguration?
    let sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        content
            .background(
                TKBottomSheetPresenter(
                    item: $item,
                    header: header,
                    sheetContent: sheetContent
                )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            )
    }
}

private struct TKBottomSheetPresenter<Item: Hashable, SheetContent: View>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let header: (Item, @escaping () -> Void) -> TKBottomSheetHeaderConfiguration?
    let sheetContent: (Item) -> SheetContent

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.presenter = self
        context.coordinator.update(item: item, from: uiViewController)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        var presenter: TKBottomSheetPresenter?

        private var presentedItem: Item?
        private weak var sheetViewController: TKBottomSheetViewController?
        private weak var contentViewController: TKBottomSheetHostingController<SheetContent>?

        func update(item: Item?, from viewController: UIViewController) {
            guard let presenter, let item else {
                dismiss()
                return
            }

            guard let contentViewController else {
                present(item: item, from: viewController)
                return
            }

            // Every enclosing render reaches here; re-pushing identical content would make the sheet
            // re-measure and re-animate for nothing, so swap only when the presented item changed.
            guard presentedItem != item else { return }

            presentedItem = item
            contentViewController.headerConfiguration = headerConfiguration(for: item)
            contentViewController.setContent(presenter.sheetContent(item))
        }

        private func present(item: Item, from viewController: UIViewController) {
            guard let presenter else { return }

            // The representable's controller reaches a window only once SwiftUI has installed it, so
            // a sheet presented on appear has to wait for that pass.
            guard viewController.view.window != nil else {
                DispatchQueue.main.async { [weak self, weak viewController] in
                    guard let self, let viewController, self.contentViewController == nil else { return }
                    self.update(item: self.presenter?.item, from: viewController)
                }
                return
            }

            let contentViewController = TKBottomSheetHostingController(
                content: presenter.sheetContent(item),
                headerConfiguration: headerConfiguration(for: item)
            )
            let sheetViewController = TKBottomSheetViewController(
                contentViewController: contentViewController,
                ignoreBottomSafeArea: true
            )
            // Fires for interactive dismissal only — a programmatic one already went through the
            // binding, and reporting it again would write to it twice.
            sheetViewController.didClose = { [weak self] _ in
                self?.clear()
                self?.presenter?.item = nil
            }

            presentedItem = item
            self.contentViewController = contentViewController
            self.sheetViewController = sheetViewController

            sheetViewController.present(fromViewController: viewController)
        }

        private func dismiss() {
            guard let sheetViewController else { return }
            clear()
            sheetViewController.dismiss()
        }

        private func clear() {
            presentedItem = nil
            sheetViewController = nil
            contentViewController = nil
        }

        private func headerConfiguration(for item: Item) -> TKBottomSheetHeaderConfiguration? {
            presenter?.header(item) { [weak self] in
                // Routed through the binding so SwiftUI stays the source of truth and drives the
                // dismissal back down.
                self?.presenter?.item = nil
            }
        }
    }
}
