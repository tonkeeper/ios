//
//  BytewordsTests.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import XCTest
@testable import URKit

class BytewordsTests: XCTestCase {
    func test1() {
        let input = Data([0, 1, 2, 128, 255])
        XCTAssertEqual( Bytewords.encode(input, style: .standard), "able acid also lava zoom jade need echo taxi")
        XCTAssertEqual( Bytewords.encode(input, style: .uri), "able-acid-also-lava-zoom-jade-need-echo-taxi")
        XCTAssertEqual( Bytewords.encode(input, style: .minimal), "aeadaolazmjendeoti")

        XCTAssertEqual( try Bytewords.decode("able acid also lava zoom jade need echo taxi", style: .standard), input )
        XCTAssertEqual( try Bytewords.decode("able-acid-also-lava-zoom-jade-need-echo-taxi", style: .uri), input )
        XCTAssertEqual( try Bytewords.decode("aeadaolazmjendeoti", style: .minimal), input )

        // bad checksum
        XCTAssertThrowsError( try Bytewords.decode("able acid also lava zero jade need echo wolf", style: .standard) )
        XCTAssertThrowsError( try Bytewords.decode("able-acid-also-lava-zero-jade-need-echo-wolf", style: .uri) )
        XCTAssertThrowsError( try Bytewords.decode("aeadaolazojendeowf", style: .minimal) )

        // too short
        XCTAssertThrowsError( try Bytewords.decode("wolf", style: .standard) )
        XCTAssertThrowsError( try Bytewords.decode("", style: .standard) )
    }

    func test2() {
        let input = Data([
            245, 215, 20, 198, 241, 235, 69, 59, 209, 205,
            165, 18, 150, 158, 116, 135, 229, 212, 19, 159,
            17, 37, 239, 240, 253, 11, 109, 191, 37, 242,
            38, 120, 223, 41, 156, 189, 242, 254, 147, 204,
            66, 163, 216, 175, 191, 72, 169, 54, 32, 60,
            144, 230, 210, 137, 184, 197, 33, 113, 88, 14,
            157, 31, 177, 46, 1, 115, 205, 69, 225, 150,
            65, 235, 58, 144, 65, 240, 133, 69, 113, 247,
            63, 53, 242, 165, 160, 144, 26, 13, 79, 237,
            133, 71, 82, 69, 254, 165, 138, 41, 85, 24
        ])

        let encoded = """
        yank toys bulb skew when warm free fair tent swan \
        open brag mint noon jury list view tiny brew note \
        body data webs what zinc bald join runs data whiz \
        days keys user diet news ruby whiz zone menu surf \
        flew omit trip pose runs fund part even crux fern \
        math visa tied loud redo silk curl jugs hard beta \
        next cost puma drum acid junk swan free very mint \
        flap warm fact math flap what limp free jugs yell \
        fish epic whiz open numb math city belt glow wave \
        limp fuel grim free zone open love diet gyro cats \
        fizz holy city puff
        """

        let encodedMinimal = """
        yktsbbswwnwmfefrttsnonbgmtnnjyltvwtybwne\
        bydawswtzcbdjnrsdawzdsksurdtnsrywzzemusf\
        fwottppersfdptencxfnmhvatdldroskcljshdba\
        ntctpadmadjksnfevymtfpwmftmhfpwtlpfejsyl\
        fhecwzonnbmhcybtgwwelpflgmfezeonledtgocs\
        fzhycypf
        """

        XCTAssertEqual( Bytewords.encode(input, style: .standard), encoded)
        XCTAssertEqual( Bytewords.encode(input, style: .minimal), encodedMinimal)
    }
}
