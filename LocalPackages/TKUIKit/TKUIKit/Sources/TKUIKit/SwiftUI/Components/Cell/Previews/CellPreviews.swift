import SwiftUI

public struct CellPreviewsView: View {
    @Environment(\.tkPalette) private var palette
    @State private var shimmering = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Toggle(isOn: $shimmering) {
                    Text("shimmering")
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                }
                .padding(.horizontal, 16)

                initializersGroup
            }
            .padding(.vertical, 16)
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }

    private var initializersGroup: some View {
        VStack(spacing: 16) {
            Cell(
                config: .init(
                    action: {}
                ),
                leading: {
                    CellAssetLeading {
                        AssetAvatarView(
                            imageSource: shimmering
                                ? .shimmer
                                : .image(.TKUIKit.Icons.Size44.btcChain)
                        )
                    }
                },
                center: {
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: shimmering ? .shimmer() : .content(
                                    .init(
                                        title: "Santa Coin",
                                        tags: [
                                            .tag(text: "FFF"),
                                            .accentTag(text: "W5", accent: .accentBlue),
                                        ],
                                        status: .init(
                                            image: .TKUIKit.Icons.Size12.pin,
                                            size: 12
                                        ),
                                        value: .init(
                                            title: "374.14"
                                        )
                                    )
                                )
                            )
                        },
                        secondaryRow: {
                            CellCenterSecondaryRow(
                                config: shimmering ? .shimmer() : .content(
                                    .init(
                                        value: .init(
                                            title: "The one and only super best cool nice unbelievable and amazing crypto token in the world. All holder are literally gods."
                                        )
                                    )
                                )
                            )
                        }
                    )
                }
            )

            Cell(
                config: .init(
                    action: {}
                ),
                leading: {
                    CellAssetLeading {
                        AssetAvatarView(
                            imageSource: shimmering
                                ? .shimmer
                                : .image(.TKUIKit.Icons.Size44.tonChain)
                        )
                    }
                },
                center: {
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: shimmering ? .shimmer() : .content(
                                    .init(
                                        title: "TON",
                                        value: .init(
                                            title: "14,787.32"
                                        )
                                    )
                                )
                            )
                        },
                        secondaryRow: {
                            CellCenterSecondaryRow(
                                config: shimmering ? .shimmer() : .content(
                                    .init(
                                        value: .init(
                                            title: "$ 1.84"
                                        ),
                                        delta: .init(
                                            text: "+ 7.32 %",
                                            isPositive: true
                                        ),
                                        accessory: .init(
                                            title: "$ 24,374.27"
                                        )
                                    )
                                )
                            )
                        }
                    )
                }
            )

            Cell(
                config: .init(
                    action: {}
                ),
                leading: {
                    CellAssetLeading {
                        AssetAvatarView(
                            imageSource: shimmering
                                ? .shimmer
                                : .image(.TKUIKit.Icons.Size44.tonWhalesLogo)
                        )
                    }
                },
                center: {
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: shimmering ? .shimmer(secondaryWidth: nil) : .content(
                                    .init(
                                        title: "Getgems"
                                    )
                                )
                            )
                        },
                        secondaryRow: {
                            CellCenterSecondaryRow(
                                config: shimmering ? .shimmer() : .content(
                                    .init(
                                        value: .init(
                                            title: "The home of NFT collections on The Open Network",
                                            lineLimit: 2
                                        )
                                    )
                                )
                            )
                        }
                    )
                }, trailing: {
                    CellTrailingAccessory(
                        config: .init(
                            color: .iconTertiary,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                            iconSize: 16
                        )
                    )
                }
            )

            Cell(
                config: .init(
                    action: {}
                ),
                leading: {
                    CellAssetLeading {
                        AssetAvatarView(
                            imageSource: shimmering
                                ? .shimmer
                                : .image(.TKUIKit.Icons.Size44.tonChain)
                        )
                    }
                },
                center: {
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: shimmering ? .shimmer() : .content(
                                    .init(
                                        title: "TON",
                                        value: .init(
                                            title: "14,787.32"
                                        )
                                    )
                                )
                            )
                        }
                    )
                }
            )

            Cell(
                config: .init(
                    action: {}
                ),
                leading: {
                    CellAssetLeading {
                        AssetAvatarView(
                            imageSource: shimmering
                                ? .shimmer
                                : .image(.TKUIKit.Icons.Size44.ethChain)
                        )
                    }
                },
                center: {
                    CellCenter(
                        primaryRow: CellCenterPrimaryRow(
                            config: shimmering ? .shimmer(secondaryWidth: nil) : .content(
                                .init(
                                    title: "Ethereum"
                                )
                            )
                        ),
                        secondaryRow: CellCenterSecondaryRow(
                            config: shimmering ? .shimmer() : .content(
                                .init(
                                    value: .init(
                                        title: "UQAK...MALX"
                                    )
                                )
                            )
                        )
                    )
                },
                trailing: {
                    HStack(alignment: .center, spacing: 0) {
                        CellTrailingAccessory(
                            config: .init(
                                color: .iconPrimary,
                                icon: SwiftUI.Image.TKUIKit.Icons.Size28.qrCodeAlternate
                            )
                        )
                        CellTrailingAccessory(
                            config: .init(
                                color: .iconSecondary,
                                icon: SwiftUI.Image.TKUIKit.Icons.Size28.copyOutline
                            )
                        )
                    }
                }
            )

            Cell(
                config: .init(
                    action: {}
                ),
                center: {
                    CellCenter(
                        primaryRow: {
                            CellCenterPrimaryRow(
                                config: .content(
                                    .init(
                                        title: "Settings"
                                    )
                                )
                            )
                        }
                    )
                }, trailing: {
                    CellTrailingAccessory(
                        config: .init(
                            color: .iconTertiary,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                            iconSize: 16
                        )
                    )
                }
            )
        }
    }
}

#Preview {
    CellPreviewsView()
        .tkThemed()
}
