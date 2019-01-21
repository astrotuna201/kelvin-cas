//
//  Tuple.swift
//  Kelvin
//
//  Created by Jiachen Ren on 1/18/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation

public struct Tuple: BinaryNode, NaN {
    
    public var stringified: String {
        return "(\(lhs) : \(rhs))"
    }
    
    /// First value of the tuple
    var lhs: Node
    
    /// Second value of the tuple
    var rhs: Node
    
    init(_ v1: Node, _ v2: Node) {
        self.lhs = v1
        self.rhs = v2
    }
    
    public func equals(_ node: Node) -> Bool {
        if let t = node as? Tuple {
            return equals(list: t)
        }
        return false
    }
}