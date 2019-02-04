//
//  Function.swift
//  Kelvin
//
//  Created by Jiachen Ren on 11/10/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation

public struct Function: MutableListProtocol {
    
    public var evaluated: Value? {
        return (try? invoke())??.evaluated
    }

    /// Complexity of the function is the complexity of the List of args + 1.
    public var complexity: Int {
        return args.complexity
    }

    /// The name of the function
    let name: String

    /// List of arguments that the function takes in.
    let args: List
    
    /// Conform to MutableListProtocol by returning the list of arguments
    /// as elements; since the function itself is immutable, a new function
    /// is created every time the elements are changed.
    var elements: [Node] {
        get {
            return args.elements
        }
        set {
            self = Function(name, List(newValue))
        }
    }

    /// The syntactic rules of the function (looked up by the name)
    var keyword: Keyword? {
        return Keyword.glossary[name]
    }
    
    /// Whether the function is commutative.
    let isCommutative: Bool

    init(_ name: String, _ args: List) {
        self.name = name
        
        let isCommutative = Operation.has(attr: .commutative, name)
        self.isCommutative = isCommutative
        
        // If the function is commutative, order its arguments.
        self.args = isCommutative ? args.ordered() : args

        flatten()
    }

    init(_ name: String, _ args: [Node]) {
        self.init(name, List(args))
    }

    public var stringified: String {
        return toString()
    }
    
    public var ansiColored: String {
        return toString(colored: true)
    }
    
    private var ansiFormattedName: String {
        return Operation.registered[name] == nil ? name : name.bold.italic
    }

    private func parenthesize(_ s: String, _ colored: Bool) -> String {
        return colored ? "(".bold + s + ")".bold : "(\(s))"
    }
    
    private func toString(colored: Bool = false) -> String {
        let r = elements.map {
            colored ? $0.ansiColored : $0.stringified
        }
        var n = " \(colored ? ansiFormattedName : name) "
        
        func formatted() -> String {
            let l = r.reduce(nil) {
                $0 == nil ? "\($1)" : "\($0!), \($1)"
            }
            return "\(colored ? ansiFormattedName : name)\(parenthesize(l ?? "", colored))"
        }
        
        if let keyword = self.keyword {
            
            // Determine which form of the function to use;
            // there are three options: shorthand, operator, or default.
            let k = keyword.formatted
            let n = colored ? (k.replacingOccurrences(of: " ", with: "").isAlphaNumeric ? k.bold : k) : k
            
            switch keyword.associativity {
            case .infix where count == 1:
                
                // Handle special case of -x.
                let c = keyword.operator?.name ?? (colored ? ansiFormattedName : name)
                return "\(c)\(r[0])"
            case .infix where args.count == 2 || isCommutative:
                if let s = r.enumerated().reduce(nil, { (a, c) -> String in
                    let (i, b) = c
                    let p = usesParenthesis(forNodeAtIndex: i)
                    let b1 = p ? parenthesize(b, colored) : "\(b)"
                    return a == nil ? "\(b1)" : "\(a!)\(n)\(b1)"
                }) {
                    return "\(s)"
                } else {
                    return ""
                }
            case .prefix where r.count == 1:
                let p = usesParenthesis(forNodeAtIndex: 0)
                return p ? "\(n)\(parenthesize(r[0], colored))" : "\(n)\(r[0])"
            case .postfix where r.count == 1:
                let p = usesParenthesis(forNodeAtIndex: 0)
                return p ? "\(parenthesize(r[0], colored))\(n)" : "\(r[0])\(n)"
            default:
                break
            }
        }
        
        return formatted()
    }

    /**
     Whether the child node should be enveloped in parenthesis when printing.
     If the parent and the child are both commutative and have the same name,
     then the parenthesis for the child is omitted; otherwise if the child's
     precedence is larger than that of the parent, the parenthesis is also omitted.
     
     - Note: Parentheses only apply to infix operations.
     - Parameter idx: The index of the child.
     - Returns: Whether a parenthesis should be used for the child when printing.
     */
    private func usesParenthesis(forNodeAtIndex idx: Int) -> Bool {
        let child = args[idx]
        if let fun = child as? Function {
            if let p1 = fun.keyword?.precedence {
                if let p2 = keyword?.precedence {
                    if p1 < p2 {

                        // e.g. (a + b) * c
                        // If the child's precedence is lower, a parenthesis is always needed.
                        return true
                    } else if p1 == p2 {

                        // Always parenthesize unary operations to disambiguate
                        if fun.count == 1 {
                            return true
                        }

                        // e.g. a + b - c
                        // If the child is on the left and has the same precedence,
                        // a parenthesis is not needed.
                        if idx != 0 {
                            if Operation.has(attr: .forwardCommutative, name) {

                                // e.g. case of a - (b + c)
                                // If the parent is only commutative in the forward direction,
                                // then always use a parenthesis for rhs.
                                return true
                            } else if Operation.has(attr: .commutative, name) {

                                // e.g. a + b + c
                                // If the parent is commutative both forward and backward,
                                // then omit parenthesis when the child and parent are the same function.
                                return name != fun.name
                            } else {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    /**
     Resolve the operations associated w/ the function and then perform
     perform them on the arguements.
     
     - Returns: The first successful result acquired by performing the
                operations on the arguments.
     */
    public func invoke() throws -> Node? {
        for operation in Operation.resolve(for: self) {
            if let result = try operation.def(elements) {
                return result
            }
        }
        return nil
    }

    /**
     Simplify each argument, if possible, then perform the operation defined by this
     function on the arguments, if possible. Otherwise, a copy of the original function
     is returned, with each argument simplified.
     
     - Returns: a node representing the simplified(computed) value of the function.
     */
    public func simplify() throws -> Node {

        // Make a copy of self.
        var copy = self

        // If the function's name begins with "$", the compiler preserves it once
        // This enables functions to be used as an input type.
        // Suppose we have "repeat(random(), 5)", it only execute random 1 once
        // and copy the value 5 times to create the list, say {0.1, 0.1, 0.1, 0.1, 0.1};
        // Now if we change it to "repeat($random(),5), it will behave as what you would expect:
        // a list of 5 random numbers.
        if name.starts(with: "$") {
            var name = self.name
            name.removeFirst()
            return Function(name, args)
        }

        // Simplify each argument, if requested.
        if !Operation.has(attr: .preservesArguments, name) {
            let args = try copy.args.simplify() as! List
            copy = Function(name, args)
        }

        // If the operation can be performed on the given arguments, perform the operation.
        // Then, the result of the operation is simplified;
        // otherwise returns a copy of the original function with each argument simplified.
        if let s = try copy.invoke()?.simplify() {
            return s
        } else if Operation.has(attr: .commutative, name) {
            
            // Try simplifying in the reserve order if the function is commutative
            if copy.count > 2 {
                let after = try Operation.simplifyCommutatively(copy.elements, by: name)
                return after.complexity < copy.complexity ? after : copy
            }
        }

        // Cannot be further simplified
        return copy
    }
    
    public func implement(using template: Node) throws {
        // Create function signature
        let signature = [Operation.ArgumentType](repeating: .any, count: args.count)
        
        
        // Make sure the old definition is removed from registry
        Operation.remove(name, signature)
        
        // Create and register function denition as an operation
        let def = try Function.createDefinition(from: template, using: args.elements)
        let op = Operation(name, signature, definition: def)
        Operation.register(op)
    }
    
    /// Creates a definition from the template, by replacing
    /// the variables in template with arguments
    static func createDefinition(from template: Node, using args: [Node]) throws -> Definition {
        
        // Check to make sure that every argument is a variable
        for arg in args {
            if !(arg is Variable) {
                let msg = "function signature should only contain variables"
                throw ExecutionError.general(errMsg: msg)
            }
        }
        
        // Cast the arguments to variables
        let vars = args.map {
            $0 as! Variable
        }
        
        var dict = [String: Int]()
        vars.enumerated().forEach { (args) in
            let (idx, v) = args
            dict[v.name] = idx
        }
        
        return { args in
            var template = template.replacing(by: {
                var rpl = $0 as! Variable
                
                // This is for dealing with the following bug:
                // Suppose we have f(a,b) = a+b^2
                // Call to f(a,b) results in a+b^2,
                // Nevertheless, call to f(b,a) results in b+b^2!
                rpl.name = "#\(rpl.name)"
                return rpl
            }, where: { $0 is Variable })
            
            dict.forEach { (pair) in
                let (key, value) = pair
                template = template.replacing(by: { _ in args[value] }) {
                    ($0 as? Variable)?.name == "#\(key)"
                }
            }
            
            // Revert changes made to the variable names
            return template.replacing(by: {
                var mod = $0 as! Variable
                mod.name.removeFirst()
                return mod
            }, where: { ($0 as? Variable)?.name.starts(with: "#") ?? false })
        }
    }

    /**
     Unravel the binary operation tree.
     e.g. +(d,+(+(a,b),c)) becomes +(a,b,c,d)
     
     - Warning: Before invoking this function, the expression should be in addtion only form.
     Under normal circumstances, don't use this function.
     */
    private mutating func flatten() {
        let elements = self.elements
        
        // Flatten commutative operations
        if isCommutative {
            var newArgs = [Node]()
            var changed = false
            elements.forEach { arg in
                if let fun = arg as? Function, fun.name == name {
                    changed = true
                    newArgs.append(contentsOf: fun.elements)
                } else {
                    newArgs.append(arg)
                }
            }

            // Prevent stackoverflow due to recursive calling to args' setter
            if changed {
                self = Function(name, List(newArgs))
            }
        }
    }

    /// Functions are equal to each other if their names and arguments are the same
    public func equals(_ node: Node) -> Bool {
        if let fun = node as? Function {
            if fun.name == name {
                if equals(list: fun as ListProtocol) {
                    return true
                }
            }
        }
        return false
    }
}
