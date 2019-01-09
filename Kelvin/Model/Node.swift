//
//  Node.swift
//  Kelvin
//
//  Created by Jiachen Ren on 11/10/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

// Unary operation
public typealias Unary = (Node) -> Node

public protocol Node: CustomStringConvertible {
    
    /// Computes the numerical value that the node represents.
    var evaluated: Value? {get}
    
    /// Simplify the node.
    /// TODO: Implement Log
    func simplify() -> Node
    
    /// Formats the expression for ease of computation
    /// - Convert all subtraction to addition + negation
    /// - Convert all division to multiplifications
    /// - Flatten binary operation trees. i.e. (a+b)+c becomes a+b+c
    func format() -> Node
    
    /// Convert all subtractions to additions
    func toAdditionOnlyForm() -> Node
    
    /// Convert all divisions to multiplications and exponentiations
    func toExponentialForm() -> Node
    
    /// Flatten binary operation trees
    func flatten() -> Node
    
    /**
     Replace the designated nodes identical to the node provided with the replacement
     
     - Parameter condition: The condition that needs to be met for a node to be replaced
     - Parameter replace:   A function that takes the old node as input (and perhaps
                            ignores it) and returns a node as replacement.
     */
    func replacing(with replace: Unary, where condition: (Node) -> Bool) -> Node
    
    /// - Returns: Whether the provided node is identical with self.
    func equals(_ node: Node) -> Bool
}

extension Node {
    
    /// TODO: Implement order
    public func format() -> Node {
        return self.toAdditionOnlyForm()
            .toExponentialForm()
            .flatten()
    }
    
    public func replacing(with replace: Unary, where condition: (Node) -> Bool) -> Node {
        return condition(self) ? replace(self) : self
    }
    
}
