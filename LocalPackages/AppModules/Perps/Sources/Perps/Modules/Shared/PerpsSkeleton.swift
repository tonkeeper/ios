import SwiftUI
import TKLocalize
import TKUIKit

struct PerpsSkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.backgroundContentTint)
            .frame(width: width, height: height)
    }
}

struct PerpsSkeletonCircle: View {
    var side: CGFloat = 44

    var body: some View {
        Circle()
            .fill(.backgroundContentTint)
            .frame(width: side, height: side)
    }
}

/// A row placeholder: a circle, two lines on the left and two right-aligned lines.
struct PerpsSkeletonRow: View {
    var leading: [[CGFloat]] = [[40, 24], [64]]
    var trailing: [CGFloat] = [72, 40]

    var body: some View {
        HStack(spacing: 16) {
            PerpsSkeletonCircle()
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(leading.enumerated()), id: \.offset) { index, widths in
                    HStack(spacing: 8) {
                        ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                            PerpsSkeletonBar(width: width)
                        }
                    }
                    .frame(height: index == 0 ? 24 : 20)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(trailing.enumerated()), id: \.offset) { index, width in
                    PerpsSkeletonBar(width: width)
                        .frame(height: index == 0 ? 24 : 20)
                }
            }
        }
        .padding(16)
        .frame(height: 76)
    }
}

struct PerpsSkeletonRowsCard: View {
    var count = 8
    var row = PerpsSkeletonRow()

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< count, id: \.self) { index in
                row.applySeparatorIfNeeded(index: index, total: count, leadingInset: 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.backgroundContent)
        )
        .accessibilityHidden(true)
    }
}

/// The open positions card while they load: the total header and position rows.
struct PerpsOpenPositionsSkeleton: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TKLocales.Perps.totalAmount)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                PerpsSkeletonBar(width: 92, height: 24)
                    .frame(height: 32)
                HStack(spacing: 8) {
                    PerpsSkeletonBar(width: 48)
                    PerpsSkeletonBar(width: 48)
                }
                .frame(height: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Rectangle()
                .fill(.separatorCommon)
                .frame(height: TKUIKit.Constants.separatorWidth)

            ForEach(0 ..< count, id: \.self) { index in
                PerpsSkeletonRow(leading: [[40, 24, 40]], trailing: [56, 40])
                    .applySeparatorIfNeeded(index: index, total: count, leadingInset: 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.backgroundContent)
        )
        .accessibilityHidden(true)
    }
}
