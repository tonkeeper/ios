//
//  URUtils.swift
//
//  Copyright © 2020 by Blockchain Commons, LLC
//  Licensed under the "BSD-2-Clause Plus Patent License"
//

import Foundation

extension Character {
    var isURType: Bool {
        if "a" <= self && self <= "z" { return true }
        if "0" <= self && self <= "9" { return true }
        if self == "-" { return true }
        return false
    }
}

extension String {
    var isURType: Bool { allSatisfy { $0.isURType } }
}
