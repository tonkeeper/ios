import Combine
import SwiftUI
@testable import TKUIKit
import XCTest

@MainActor
final class ThemeEnvironmentTests: XCTestCase {
    func testObjectWillChangeEmitsOnThemeChangeBeforeMutation() {
        let themeManager = TKThemeManager.shared
        let originalTheme = themeManager.theme
        defer {
            themeManager.theme = originalTheme
        }

        themeManager.theme = .light

        var emissions = 0
        var themeInsideEmission: TKTheme?
        let cancellable = themeManager.objectWillChange.sink {
            emissions += 1
            themeInsideEmission = themeManager.theme
        }
        defer {
            cancellable.cancel()
        }

        themeManager.theme = .deepBlue

        XCTAssertEqual(emissions, 1)
        XCTAssertEqual(themeInsideEmission, .light)
        XCTAssertEqual(themeManager.theme, .deepBlue)
        XCTAssertTrue(themeManager.themeAppearance is DeepBlueThemeAppearance)
    }

    func testObjectWillChangeDoesNotEmitWhenThemeIsUnchanged() {
        let themeManager = TKThemeManager.shared
        let originalTheme = themeManager.theme
        defer {
            themeManager.theme = originalTheme
        }

        themeManager.theme = .light

        var emissions = 0
        let cancellable = themeManager.objectWillChange.sink {
            emissions += 1
        }
        defer {
            cancellable.cancel()
        }

        themeManager.theme = .light

        XCTAssertEqual(emissions, 0)
        XCTAssertEqual(themeManager.theme, .light)
    }

    func testResolvedThemeMapsThemeAndSystemScheme() {
        XCTAssertEqual(
            TKResolvedTheme(theme: .deepBlue, systemColorScheme: .light),
            .deepBlue
        )
        XCTAssertEqual(
            TKResolvedTheme(theme: .deepBlue, systemColorScheme: .dark),
            .deepBlue
        )
        XCTAssertEqual(
            TKResolvedTheme(theme: .dark, systemColorScheme: .light),
            .dark
        )
        XCTAssertEqual(
            TKResolvedTheme(theme: .light, systemColorScheme: .dark),
            .light
        )
        XCTAssertEqual(
            TKResolvedTheme(theme: .system, systemColorScheme: .dark),
            .dark
        )
        XCTAssertEqual(
            TKResolvedTheme(theme: .system, systemColorScheme: .light),
            .light
        )
    }

    func testResolvedThemeMapsToConcreteColorScheme() {
        XCTAssertTrue(TKResolvedTheme.light.colorScheme is LightColorScheme)
        XCTAssertTrue(TKResolvedTheme.dark.colorScheme is DarkColorScheme)
        XCTAssertTrue(TKResolvedTheme.deepBlue.colorScheme is DeepBlueColorScheme)
    }

    func testResolvedThemeColorsAreCachedAndEquatableByTheme() {
        for resolvedTheme in [TKResolvedTheme.light, .dark, .deepBlue] {
            XCTAssertEqual(resolvedTheme.palette, resolvedTheme.palette)
            XCTAssertEqual(resolvedTheme.palette.resolvedTheme, resolvedTheme)
        }
        XCTAssertNotEqual(TKResolvedTheme.light.palette, TKResolvedTheme.dark.palette)
        XCTAssertNotEqual(TKResolvedTheme.dark.palette, TKResolvedTheme.deepBlue.palette)
    }

    func testPerThemeThemedColorResolvesAgainstResolvedTheme() {
        let themed = TKColor.perTheme(light: .white, dark: .black, deepBlue: .blue)

        XCTAssertEqual(themed.resolve(TKResolvedTheme.light.palette), .white)
        XCTAssertEqual(themed.resolve(TKResolvedTheme.dark.palette), .black)
        XCTAssertEqual(themed.resolve(TKResolvedTheme.deepBlue.palette), .blue)
    }

    func testClearColorResolvesWithoutChangingItsSemantics() {
        for theme in [TKResolvedTheme.light, .dark, .deepBlue] {
            XCTAssertEqual(TKColor.clear.resolve(theme.palette), .clear)
        }
    }

    func testTokenizedColorCanBeUsedByThemedModifiersAndAsAView() {
        let separator = Rectangle().stroke(.separatorCommon, lineWidth: 1)
        let bordered = RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.fieldActiveBorder, lineWidth: 1)
        let styled = Color.clear
            .background(.backgroundPage)
            .shadow(color: .backgroundOverlayLight, radius: 4)
            .tkScrim(.backgroundPage, edge: .bottom)

        XCTAssertNotNil(TKHostingController(content: AnyView(TKColor.backgroundPage)))
        XCTAssertNotNil(TKHostingController(content: AnyView(separator)))
        XCTAssertNotNil(TKHostingController(content: AnyView(bordered)))
        XCTAssertNotNil(TKHostingController(content: AnyView(styled)))
    }
}
