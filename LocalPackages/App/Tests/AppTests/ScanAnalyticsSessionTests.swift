@testable import App
import Foundation
import KeeperCore
import TKCore
import XCTest

final class ScanAnalyticsSessionTests: XCTestCase {
    func testOpenFromOutsideTheAppCarriesTheEntryLinkUtmOnce() {
        let service = AnalyticsServiceSpy()
        let session = makeSession(service: service, openUtm: UtmParameters(link: "tonkeeper://scan?utm_source=widget&utm_content=scan"))

        session.logOpen()
        session.logOpen()

        XCTAssertEqual(service.calls.map(\.name), ["scan_open"])
        XCTAssertEqual(service.calls[0].args[utmSourceKey] as? String, "widget")
        XCTAssertEqual(service.calls[0].args[utmContentKey] as? String, "scan")
    }

    func testOpenFromInsideTheAppHasNoUtm() {
        let service = AnalyticsServiceSpy()

        makeSession(service: service).logOpen()

        XCTAssertEqual(service.calls.map(\.name), ["scan_open"])
        XCTAssertNil(service.calls[0].args[utmSourceKey])
    }

    func testSuccessCarriesTheScannedLinkUtmAndInput() {
        let service = AnalyticsServiceSpy()
        let session = makeSession(service: service, openUtm: UtmParameters(link: "tonkeeper://widget?utm_source=widget"))

        session.logSuccess(code: "\(transferLink)?amount=1&utm_source=poster&utm_medium=qr", input: .camera)
        session.logSuccess(code: address, input: .gallery)

        XCTAssertEqual(service.calls.map(\.name), ["scan_success", "scan_success"])
        XCTAssertEqual(service.calls[0].args[ScanSuccess.CodingKeys.input.rawValue] as? String, "camera")
        XCTAssertEqual(service.calls[0].args[utmSourceKey] as? String, "poster")
        XCTAssertEqual(service.calls[0].args[AnalyticsEventMobileNative.CodingKeys.utmMedium.rawValue] as? String, "qr")
        XCTAssertEqual(service.calls[1].args[ScanSuccess.CodingKeys.input.rawValue] as? String, "gallery")
        XCTAssertNil(service.calls[1].args[utmSourceKey])
    }

    func testSameCodeIsReportedOncePerSessionAcrossSuccessAndError() {
        let service = AnalyticsServiceSpy()
        let session = makeSession(service: service)

        session.logSuccess(code: address, input: .camera)
        session.logSuccess(code: address, input: .camera)
        session.logError(code: address, input: .gallery, rejection: .invalidLink)
        session.logError(code: "garbage", input: .camera, rejection: .invalidLink)
        session.logError(code: "garbage", input: .camera, rejection: .unsupportedHere)
        session.logSuccess(code: "garbage", input: .camera)

        XCTAssertEqual(service.calls.map(\.name), ["scan_success", "scan_error"])
    }

    func testErrorCarriesInputAndErrorTypeWithoutTheLinkUtm() {
        let service = AnalyticsServiceSpy()
        let session = makeSession(service: service)

        session.logError(code: "\(transferLink)?utm_source=poster", input: .gallery, rejection: .unsupportedHere)
        session.logError(code: "garbage", input: .camera, rejection: .invalidLink)

        XCTAssertEqual(service.calls.map(\.name), ["scan_error", "scan_error"])
        XCTAssertEqual(service.calls[0].args[ScanError.CodingKeys.input.rawValue] as? String, "gallery")
        XCTAssertEqual(service.calls[0].args[ScanError.CodingKeys.errorType.rawValue] as? String, "unsupported_here")
        XCTAssertNil(service.calls[0].args[utmSourceKey])
        XCTAssertEqual(service.calls[1].args[ScanError.CodingKeys.errorType.rawValue] as? String, "invalid_link")
    }

    func testNoCodeIsAGalleryErrorReportedEveryTime() {
        let service = AnalyticsServiceSpy()
        let session = makeSession(service: service)

        session.logNoCode()
        session.logNoCode()

        XCTAssertEqual(service.calls.map(\.name), ["scan_error", "scan_error"])
        XCTAssertEqual(service.calls[0].args[ScanError.CodingKeys.input.rawValue] as? String, "gallery")
        XCTAssertEqual(service.calls[0].args[ScanError.CodingKeys.errorType.rawValue] as? String, "no_code")
    }

    func testScannedDeeplinkReportsTheFirstOutcomeOnly() {
        let service = AnalyticsServiceSpy()
        let code = "\(transferLink)?utm_source=poster"
        let scanned = ScannedDeeplink(
            deeplink: .staking,
            code: code,
            input: .camera,
            session: makeSession(service: service)
        )

        XCTAssertEqual(scanned.utm, UtmParameters(link: code))
        scanned.accept()
        scanned.rejectUnsupported()

        XCTAssertEqual(service.calls.map(\.name), ["scan_success"])
        XCTAssertEqual(service.calls[0].args[utmSourceKey] as? String, "poster")
    }

    func testScannedDeeplinkWithoutSessionReportsNothing() {
        let scanned = ScannedDeeplink(
            deeplink: .staking,
            code: address,
            input: .camera,
            session: nil
        )

        scanned.accept()
        scanned.rejectUnsupported()

        XCTAssertTrue(scanned.utm.isEmpty)
    }

    private let address = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    private var transferLink: String {
        "tonkeeper://transfer/\(address)"
    }

    private let utmSourceKey = AnalyticsEventMobileNative.CodingKeys.utmSource.rawValue
    private let utmContentKey = AnalyticsEventMobileNative.CodingKeys.utmContent.rawValue

    private func makeSession(service: AnalyticsServiceSpy, openUtm: UtmParameters = .empty) -> ScanAnalyticsSession {
        let coreAssembly = CoreAssembly()
        let provider = AnalyticsProvider(
            analyticsServices: [service],
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            appInfoProvider: coreAssembly.appInfoProvider,
            keysCountryCodeProvider: coreAssembly.keysCountryCodeProvider
        )
        return ScanAnalyticsSession(analyticsProvider: provider, openUtm: openUtm)
    }
}

private final class AnalyticsServiceSpy: AnalyticsService {
    private(set) var calls = [(name: String, args: [String: Any])]()

    func logEvent(name: String, args: [String: Any]) {
        calls.append((name: name, args: args))
    }
}
