//
//  Operation+factory.swift
//  Kelvin
//
//  Created by Jiachen Ren on 10/7/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation

/// Factory functions
public extension Operation {
    /// Factory function for type safe quaternary operation
    static func quaternary<T1, T2, T3, T4>(
        _ name: OperationName,
        _ type1: T1.Type,
        _ type2: T2.Type,
        _ type3: T3.Type,
        _ type4: T4.Type,
        quaternary: @escaping (T1, T2, T3, T4) throws -> Node?
    ) -> Operation {
        let parType1: Parameter = .init(type1)
        let parType2: Parameter = .init(type2)
        let parType3: Parameter = .init(type3)
        let parType4: Parameter = .init(type4)
        return .quaternary(name, [parType1, parType2, parType3, parType4]) {
            try quaternary(
                $0 ~> T1.self,
                $1 ~> T2.self,
                $2 ~> T3.self,
                $3 ~> T4.self
            )
        }
    }
    
    /// Factory function for quaternary operation
    static func quaternary(
        _ name: OperationName,
        _ signature: [Parameter],
        quaternary: @escaping (Node, Node, Node, Node) throws -> Node?
    ) -> Operation {
        return Operation(name, signature) {
            try quaternary($0[0], $0[1], $0[2], $0[3])
        }
    }
    
    /// Factory function for type safe ternary operation
    static func ternary<T1, T2, T3>(
        _ name: OperationName,
        _ type1: T1.Type,
        _ type2: T2.Type,
        _ type3: T3.Type,
        ternary: @escaping (T1, T2, T3) throws -> Node?
    ) -> Operation {
        let parType1: Parameter = .init(type1)
        let parType2: Parameter = .init(type2)
        let parType3: Parameter = .init(type3)
        return .ternary(name, [parType1, parType2, parType3]) {
            try ternary(
                $0 ~> T1.self,
                $1 ~> T2.self,
                $2 ~> T3.self
            )
        }
    }
    
    /// Factory function for ternary operation
    static func ternary(
        _ name: OperationName,
        _ signature: [Parameter],
        ternary: @escaping (Node, Node, Node) throws -> Node?
    ) -> Operation {
        return Operation(name, signature) {
            try ternary($0[0], $0[1], $0[2])
        }
    }
    
    /// Factory function for type safe binary operation
    static func binary<T1, T2>(
        _ name: OperationName,
        _ type1: T1.Type,
        _ type2: T2.Type,
        binary: @escaping (T1, T2) throws -> Node?
    ) -> Operation {
        let parType1: Parameter = .init(type1)
        let parType2: Parameter = .init(type2)
        return .binary(name, [parType1, parType2]) {
            try binary($0 ~> T1.self, $1 ~> T2.self)
        }
    }
    
    /// Factory function for binary operation
    static func binary(
        _ name: OperationName,
        _ signature: [Parameter],
        binary: @escaping (Node, Node) throws -> Node?
    ) -> Operation {
        return Operation(name, signature) {
            try binary($0[0], $0[1])
        }
    }
    
    /// Factory function for type safe unary operation
    static func unary<T>(
        _ name: OperationName,
        _ type: T.Type,
        unary: @escaping (T) throws -> Node?
    ) -> Operation {
        let parType: Parameter = .init(type)
        return .unary(name, [parType]) {
            try unary($0 ~> T.self)
        }
    }
    
    /// Factory function for unary operation
    static func unary(
        _ name: OperationName,
        _ signature: [Parameter],
        unary: @escaping (Node) throws -> Node?
    ) -> Operation {
        return Operation(name, signature) {
            try unary($0[0])
        }
    }
    
    /// Factory function for no-arg operation
    static func noArg(
        _ name: OperationName,
        def: @escaping () throws -> Node?
    ) -> Operation {
        return Operation(name, []) { _ in
            try def()
        }
    }
}
