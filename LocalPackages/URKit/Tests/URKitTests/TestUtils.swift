//
//  TestUtils.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

@testable import URKit

func makeMessage(len: Int, seed: String = "Wolf") -> Data {
    let rng = Xoshiro256(string: seed)
    return rng.nextData(count: len)
}

func makeMessageUR(len: Int, seed: String = "Wolf") -> UR {
    let message = makeMessage(len: len, seed: seed)
    return try! UR(type: "bytes", untaggedCBOR: message)
}
