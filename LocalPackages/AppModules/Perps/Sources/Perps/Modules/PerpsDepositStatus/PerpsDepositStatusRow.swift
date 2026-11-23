import Lottie
import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct PerpsDepositStatusSelection: Identifiable, Hashable {
    let id: String
    static let multiple = Self(id: "multiple")
}

struct PerpsDepositStatusRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: PerpsDepositStatusViewModel
    @State private var selection: PerpsDepositStatusSelection?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let banner = model.banner {
                Button {
                    switch banner {
                    case let .single(id):
                        selection = .init(id: id)
                        model.didOpen(id)
                    case let .completed(ids) where ids.count == 1:
                        if let id = ids.first {
                            selection = .init(id: id)
                            model.didOpen(id)
                        }
                    case let .completed(ids):
                        model.willOpenList(announcing: ids)
                        selection = .multiple
                    case .multiple, .problems:
                        selection = .multiple
                    }
                } label: {
                    HStack(spacing: 8) {
                        indicator(banner)
                        Text(title(banner, at: context.date))
                            .textStyle(.label2)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if banner.showsChevron {
                            HStack(spacing: 6) {
                                if let duration = duration(banner, at: context.date) {
                                    Text(duration).textStyle(.body2).foregroundStyle(.textSecondary)
                                }
                                Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                                    .foregroundStyle(.iconSecondary)
                            }
                            .fixedSize()
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .frame(minHeight: 52)
                    .background(.backgroundContentTint)
                    .clipShape(PerpsDepositStatusRowShape(radius: 16))
                    .contentShape(PerpsDepositStatusRowShape(radius: 16))
                }
                .padding(.horizontal, 16)
                .buttonStyle(.plain)
                .accessibilityIdentifier("perps_deposit_status")
                .task(id: banner) { model.didShowBanner() }
                .transition(reduceMotion ? .opacity : .offset(y: -44).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.22, 1, 0.36, 1, duration: 0.7), value: model.banner)
        .tkBottomSheet(item: $selection, header: { _, _ in .depositStatusContent }) { selection in
            if selection.id == PerpsDepositStatusSelection.multiple.id {
                PerpsDepositStatusesView(model: model) { self.selection = nil }
            } else {
                PerpsDepositStatusDetailsView(model: model, depositId: selection.id) { self.selection = nil }
            }
        }
    }

    @ViewBuilder
    private func indicator(_ banner: PerpsDepositStatusViewModel.Banner) -> some View {
        if case .completed = banner {
            PerpsDepositStepLoader(step: nil)
        } else if case .problems = banner {
            Image(uiImage: .TKUIKit.Icons.Size28.trayArrowDown)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(.iconSecondary)
        } else if case let .single(id) = banner, let deposit = model.deposit(id), deposit.state != .pending {
            Image(uiImage: .TKUIKit.Icons.Size16.exclamationMarkCircle).foregroundStyle(.accentOrange)
        } else if case let .single(id) = banner, let deposit = model.deposit(id), deposit.state == .pending, let step = deposit.step {
            PerpsDepositStepLoader(step: step)
        } else {
            CircularLoader(mode: .indeterminate, preset: .small)
        }
    }

    private func duration(_ banner: PerpsDepositStatusViewModel.Banner, at date: Date) -> String? {
        switch banner {
        case let .single(id):
            guard let deposit = model.deposit(id), deposit.state == .pending, !deposit.isDelayed(at: date) else { return nil }
            return model.duration(deposit)
        case .multiple, .problems, .completed:
            return nil
        }
    }

    private func title(_ banner: PerpsDepositStatusViewModel.Banner, at date: Date) -> String {
        switch banner {
        case .multiple: return TKLocales.Perps.DepositStatus.multiple
        case .problems: return TKLocales.Perps.DepositStatus.statuses
        case let .completed(ids): return model.completionText(ids)
        case let .single(id):
            guard let deposit = model.deposit(id) else { return "" }
            if deposit.state == .refunded || deposit.state == .failed { return TKLocales.Perps.DepositStatus.failed }
            if deposit.state == .unconfirmed { return TKLocales.Perps.DepositStatus.unconfirmed }
            if deposit.isDelayed(at: date) { return TKLocales.Perps.DepositStatus.delayed }
            switch deposit.step {
            case .sending: return TKLocales.Perps.DepositStatus.sendingAmount(model.amount(deposit))
            case .converting: return deposit.isUSDC ? TKLocales.Perps.DepositStatus.transferring : TKLocales.Perps.DepositStatus.converting
            case .adding: return TKLocales.Perps.DepositStatus.awaitingConfirmation
            case nil: return TKLocales.Perps.DepositStatus.inProgress
            }
        }
    }
}

public extension TKBottomSheetHeaderConfiguration {
    static var depositStatusContent: Self {
        .init(title: .empty, rightButton: nil, contentInsets: .zero)
    }
}

private extension PerpsDepositStatusViewModel.Banner {
    var showsChevron: Bool {
        if case .completed = self { return false }
        return true
    }
}

/// The row slides under the balance card, so only the bottom corners show.
private struct PerpsDepositStatusRowShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

private struct PerpsDepositStepLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tkPalette) private var palette
    let step: PerpsDepositStatus.Step?

    var body: some View {
        LottieView(animation: LottieAnimation.named(resource.name, bundle: resource.bundle))
            .resizable()
            .playbackMode(reduceMotion
                ? .paused(at: .progress(step == nil ? 1 : 0.5))
                : .playing(.fromProgress(0, toProgress: 1, loopMode: step == nil ? .playOnce : .loop)))
            .configure { view in
                view.backgroundBehavior = .pauseAndRestore
                view.setValueProvider(
                    ColorValueProvider(UIColor(TKColor.iconPrimary.resolve(palette)).lottieColorValue),
                    keypath: AnimationKeypath(keypath: step == nil ? "Ring.**.Color" : "**.Color")
                )
                if step == nil {
                    view.setValueProvider(
                        ColorValueProvider(UIColor(TKColor.accentGreen.resolve(palette)).lottieColorValue),
                        keypath: AnimationKeypath(keypath: "Circle.**.Color")
                    )
                }
            }
            .frame(width: 16, height: 16)
            .id(resource.name)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var resource: LottieResource {
        switch step {
        case .sending: .loaderStepsStep1Loop
        case .converting: .loaderStepsStep2Loop
        case .adding: .loaderStepsStep3Loop
        case nil: .loaderStepsSuccess
        }
    }
}
