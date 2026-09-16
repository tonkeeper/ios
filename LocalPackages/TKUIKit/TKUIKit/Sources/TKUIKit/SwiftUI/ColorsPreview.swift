import SwiftUI

public struct ColorsPreview: View {
    @Environment(\.tkPalette) private var palette

    private let sections: [Section]

    public init() {
        sections = Self.makeSections()
    }

    public var body: some View {
        ZStack {
            palette.background.content
                .ignoresSafeArea()
            ScrollView {
                LazyVStack {
                    HStack(alignment: .top) {
                        Text("Colors")
                            .font(.system(size: 20, weight: .bold).monospaced())
                            .foregroundStyle(.textPrimary)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                    .background(.backgroundContent)
                    ForEach(sections) { section in
                        VStack {
                            HStack(alignment: .top) {
                                Text(section.token)
                                    .font(.system(size: 16, weight: .bold).monospaced())
                                    .foregroundStyle(.textPrimary)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)
                                    .padding(.horizontal, 24)
                                Spacer()
                            }
                            ForEach(section.rows) { row in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(row.value)
                                            .font(.system(size: 14, weight: .medium).monospaced())
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                            .foregroundStyle(.textPrimary)
                                        Text(row.prettyId)
                                            .font(.system(size: 12).monospaced())
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                            .foregroundStyle(.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    ForEach(row.variants) { variant in
                                        VStack(spacing: 4) {
                                            variant.color
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                            Text(variant.themeId)
                                                .font(.system(size: 12).monospaced())
                                                .foregroundStyle(.textSecondary)
                                        }
                                    }
                                }
                                .frame(height: 64, alignment: .center)
                            }
                            .padding(.horizontal, 24)
                        }
                        palette.separator.common
                            .frame(height: 1 / UIScreen.main.scale)
                    }
                }
                .background(.backgroundPage)
            }
            .tkImmediateButtonPresses()
        }
    }
}

private extension ColorsPreview {
    struct Variant: Identifiable {
        var id: String
        var themeId: String
        var color: Color
    }

    struct Row: Identifiable {
        var id: String
        var value: String
        var variants: [Variant]

        var prettyId: String {
            let components = id.split(separator: "/")
            return components.enumerated()
                .map { index, value in
                    var newValue = value.split(separator: " ").joined()
                    if index == 0, let first = newValue.first {
                        newValue = String(first) + newValue.dropFirst()
                    }
                    return newValue
                }
                .joined()
        }
    }

    struct Section: Identifiable {
        var id: String {
            token
        }

        var token: String
        var rows: [Row]
    }

    static func makeSections() -> [Section] {
        let themeOrder = ["Dark", "DeepBlue", "Light"]

        struct Parsed {
            var token: String
            var value: String
            var theme: String
            var name: String
            var color: Color
        }

        let parsed = TKUIKitGeneratedColorAsset.allCases.compactMap { asset -> Parsed? in
            let components = asset.rawValue.split(separator: "/").map(String.init)
            guard components.count == 4, components.first == "Colors" else {
                return nil
            }
            return Parsed(
                token: components[1],
                value: components[2],
                theme: components[3],
                name: String(describing: asset),
                color: Color(uiColor: asset.uiColor)
            )
        }

        let tokens = orderedUnique(parsed.map(\.token))
        return tokens.map { token in
            let tokenItems = parsed.filter { $0.token == token }
            let rows = orderedUnique(tokenItems.map(\.value)).map { value in
                let variants = tokenItems
                    .filter { $0.value == value }
                    .sorted {
                        (themeOrder.firstIndex(of: $0.theme) ?? .max)
                            < (themeOrder.firstIndex(of: $1.theme) ?? .max)
                    }
                    .map {
                        Variant(
                            id: $0.name,
                            themeId: $0.theme,
                            color: $0.color
                        )
                    }
                return Row(id: "\(token)/\(value)", value: value, variants: variants)
            }
            return Section(token: token, rows: rows)
        }
    }

    static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

#Preview {
    ColorsPreview()
        .tkThemed()
}
