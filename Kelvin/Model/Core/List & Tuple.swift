//
//  List & Tuple.swift
//  Kelvin
//
//  Created by Jiachen Ren on 1/20/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation

let listAndTupleOperations: [Operation] = [

    // Tuple operations
    .init("tuple", [.leaf, .leaf]) {
        Tuple($0[0], $0[1])
    },
    .init("get", [.tuple, .number]) { nodes in
        let tuple = nodes[0] as! Tuple
        let idx = Int(nodes[1].evaluated!.doubleValue)
        switch idx {
        case 0:
            return tuple.lhs
        case 1:
            return tuple.rhs
        default:
            throw ExecutionError.indexOutOfBounds
        }
    },

    // List operations
    .init("list", [.universal]) {
        List($0)
    },
    .init("get", [.list, .number]) { nodes in
        let list = nodes[0] as! List
        let idx = Int(nodes[1].evaluated!.doubleValue)
        if idx >= list.count || idx < 0 {
            throw ExecutionError.indexOutOfBounds
        } else {
            return list[idx]
        }
    },
    .init("size", [.list]) {
        return ($0[0] as! List).count
    },
    .init("map", [.any, .any]) { nodes in
        guard let list = try nodes[0].simplify() as? List else {
            return nil
        }
        let updated = list.elements.enumerated().map { (idx, e) in
            nodes[1].replacingAnonymousArgs(with: [e, idx])
        }
        return try List(updated).simplify()
    },
    .init("reduce", [.any, .any]) { nodes in
        guard let list = try nodes[0].simplify() as? List else {
            return nil
        }
        let reduced = list.elements.reduce(nil) { (e1, e2) -> Node in
            if e1 == nil {
                return e2
            }
            return nodes[1].replacingAnonymousArgs(with: [e1!, e2])
        }
        return try reduced?.simplify() ?? List([])
    },
    .init("filter", [.any, .any]) { nodes in
        guard let list = try nodes[0].simplify() as? List else {
            return nil
        }
        let updated = try list.elements.enumerated().map {(idx, e) in
                nodes[1].replacingAnonymousArgs(with: [e, idx])
            }.enumerated().map {(idx, predicate) in
                if let b = try predicate.simplify() as? Bool {
                    return b ? idx : nil
                }
                throw ExecutionError.general(errMsg: "predicate must be a boolean")
            }.compactMap {
                $0 == nil ? nil: list[$0!]
            }
        return List(updated)
    },
    .init("zip", [.list, .list]) {
        if let l1 = $0[0] as? List, let l2 = $0[1] as? List {
            return try l1.join(with: l2)
        }
        return nil
    }
]
