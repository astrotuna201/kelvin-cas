//
//  Int+Number.swift
//  Kelvin
//
//  Created by Jiachen Ren on 1/20/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation
import BigInt

extension Int: Integer {
    public var float80: Float80 { Float80(self) }
    public var ansiColored: String { "\(self)".blue }
    public var int64: Int? { self }
    public var bigInt: BigInt { BigInt(self) }
    public func abs() -> Int { Swift.abs(self) }
    public func negate() -> Int { -self }
    
    /// - Returns: The factorial of this integer
    public func factorial() -> BigInt {
        if self == 0 { return 1 }
        return (1...self).map { BigInt($0) }.reduce(BigInt(1), *)
    }
}
