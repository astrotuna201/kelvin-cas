//
//  Matrix.swift
//  Kelvin
//
//  Created by Jiachen Ren on 1/25/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation

public struct Matrix: MutableListProtocol, NaN {
    
    public typealias Row = Vector
    public typealias Dimension = (rows: Int, cols: Int)
    public typealias Cell = (row: Int, col: Int, node: Node)
    
    public var dim: Dimension
    public var rows: [Row]
    public var cols: [Vector] {
        return transposed().rows
    }
    
    /// True if the matrix is a square matrix.
    public var isSquareMatrix: Bool {
        return rows.count == rows.first!.count
    }
    
    public var cells: [Cell] {
        return rows.enumerated().map {(i, r) in
            r.elements.enumerated().map {(j, e) in
                (i, j, e)
            }
        }.flatMap {$0}
    }
    
    // MARK: - Initializers
    
    /// Initializes a zero matrix of `dim x dim` dimension.
    public init(_ dim: Int) throws {
        try self.init(rows: dim, cols: dim)
    }
    
    /// Initializes a zero matrix of `rows x cols` dimension.
    /// - Throws: `.domain` if either `rows` or `cols` is less than `0`.
    public init(rows r: Int, cols c: Int) throws {
        try self.init(rows: r, cols: c) {_, _ in 0 }
    }
    
    /// Initializes a a matrix of `rows x cols` dimensions using the initilizer.
    /// - Parameter initializer: A transformation that maps `(row, col)` to an element.
    public init(rows: Int, cols: Int, initializer: (Int, Int) -> Node) throws {
        try Assert.validDimension(rows: rows, cols: cols)
        self.rows = (0..<rows).map { r in Vector((0..<cols).map { c in initializer(r, c) }) }
        self.dim = (rows, cols)
    }
    
    /// Initializes a `rows x cols` matrix using elements in `list` as raw values.
    /// For instance, `[1, 0, 0, 1], 2, 2 -> [[1, 0], [0, 1]]`
    public init(_ list: ListProtocol, rows: Int, cols: Int) throws {
        if list.count != rows * cols {
            let msg = "cannot create a \(rows) x \(cols) matrix from a list of \(list.count) elements"
            throw ExecutionError.general(errMsg: msg)
        }
        let elements = list.elements
        self.dim = (rows, cols)
        self.rows = stride(from: 0, to: elements.count, by: cols).map {
            Row(Array(elements[$0..<min($0 + cols, elements.count)]))
        }
    }
    
    /// Initializes the matrix from a 2D list.
    /// Note that the provided list must be in the form `[[Node]]`, where every sublist has same length.
    /// - Throws: `.emptyMatrix` if any sublist is empty; `.nonUniform`.
    public init(_ list: ListProtocol) throws {
        if list.count == 0 {
            throw ExecutionError.emptyMatrix
        }
        let rows = try Assert.specialize(list: list, as: ListProtocol.self).map { Vector($0) }
        try Assert.uniform(rows)
        try self.init(rows)
    }
    
    /// Initializes the matrix by directly copying over the given rows.
    /// - Parameter rows: A list whose elements represent rows of the matrix. Each row must have the same size.
    /// - Throws: `.emptyMatrix` if count of any row is `0`; `.nonUniform` if any rows have different number of elements.
    public init(_ rows: [Row]) throws {
        self.rows = rows
        if rows.count < 1 || rows.first!.count < 1 {
            throw ExecutionError.emptyMatrix
        }
        try Assert.uniform(rows)
        self.dim = (rows: rows.count, cols: rows[0].count)
    }
    
    /// Initializes the matrix from a 2D array.
    /// - Throws: `.nonUniform` if the 2D array is not uniform.
    public init(_ mat: [[Node]]) throws {
        try self.init(mat.map {Row($0)})
    }
    
    // MARK: - Basic Operations
    
    /// The transpose of the matrix `[[A, B], [C, D]]` is `[[A, C], [B, D]]`
    /// - Returns: The transpose of the matrix.
    public func transposed() -> Matrix {
        var trans = try! Matrix(rows: dim.cols, cols: dim.rows)
        for (i, r) in rows.enumerated() {
            for (j, e) in r.elements.enumerated() {
                trans[j][i] = e
            }
        }
        return trans
    }
    
    /// For performing addition and subtraction of matrices of same dimension.
    /// - Warning: Do not pass in mult or div as binary operations, as matrices have no such definitions!
    public func perform(_ bin: Binary, with mat: Matrix) throws -> Matrix {
        try Assert.dimension(self, mat)
        var copy = self
        cells.forEach {(i, j, e) in
            copy[i][j] = bin(e, mat[i][j])
        }
        return copy
    }
    
    /// Transforms each element in the matrix by applying the given unary transformation.
    /// - Parameter unary: A unary transformation that is applied to each node in the matrix.
    /// - Returns: A matrix with each element transformed by `unary`
    public func transform(by unary: Unary) -> Matrix {
        var mat = self
        cells.forEach {(i, j, e) in
            mat[i][j] = unary(e)
        }
        return mat
    }
    
    /// Transforms each element in the matrix by applying the given unary transformation.
    /// - Parameter unary: A unary transformation that is applied to each `Cell, aka. (row, col, element)`.
    /// - Returns: A matrix with each element transformed by `unary`
    public func transform(by unary: (Cell) -> Node) -> Matrix {
        var mat = self
        cells.forEach {cell in
            mat[cell.row][cell.col] = unary(cell)
        }
        return mat
    }
    
    /// Matrix multiplication. The resultant matrix is generated by dotting each row with each column of the input matrix.
    /// `let trans(A) = [a1, a2, a3, ...]`
    /// `let B = [b1, b2, b3, ...]`
    /// `A x B = [a1 • b1, a2 • b2, a3 • b3 ...]`
    /// - Parameter mat: Matrix `B`
    /// - Returns: Matrix `A x B`
    public func mult(_ mat: Matrix) throws -> Matrix {
        let trans = mat.transposed()
        var newRows = [Row]()
        for r in rows {
            var row = [Node]()
            for c in trans.rows {
                row.append(try r.dot(with: c))
            }
            let vec = Vector(row)
            newRows.append(vec)
        }
        
        return try Matrix(newRows)
    }
    
    /// Sets the `jth` column of the matrix to the provided `column`.
    /// Note that number of elements in `column` must be equal to `dim.rows`.
    /// - Throws: `.dimensionMismatch` if `column` does not fit in matrix.
    public func setColumn(_ j: Int, _ column: Vector) throws -> Matrix {
        try Assert.index(dim.cols, j)
        guard column.count == dim.rows else {
            throw ExecutionError.dimensionMismatch(self, column)
        }
        var mat = self
        for i in 0..<dim.rows {
            mat[i][j] = column[i]
        }
        return mat
    }
    
    // MARK: - Determinant
    
    public enum EchelonForm {
        /// Row echelon form
        case ref
        /// Reduced row echelon form
        case rref
    }
    
    /// Reduce the given matrix to either RREF (Row Reduced Echelon Form) or REF.
    /// In RREF, the leading entry of each pivoting column is `1`, and `1` is the only non-zero entry in its column.
    /// In REF, `1` is not necessarily the leading entry in its column.
    /// - Parameter echelonForm: Echelon form to reduce into, either `.ref` or `.rref`.
    /// - Returns: `(swaps: Number of row swaps made, scale: Scalar applied, mat: EF form of the matrix)`
    public func reduce(into echelonForm: EchelonForm) throws -> (swaps: Int, scale: Node, mat: Matrix) {
        var mat = self
        var lead = 0
        // Keep track of row swaps
        var swaps = 0
        // Keep track of scaling operations
        var scale: Node = 1
        
        for r in 0..<mat.dim.rows {
            if mat.dim.cols <= lead {
                break
            }
            var i = r
            while mat[i][lead] === 0 {
                i += 1
                if i == mat.dim.rows {
                    i = r
                    lead += 1
                    if mat.dim.cols == lead {
                        lead -= 1
                        break
                    }
                }
            }
            
            // Swap rows i and r if i and r are different.
            if i != r {
                for j in 0..<mat.dim.cols {
                    let temp = mat[r][j]
                    mat[r][j] = mat[i][j]
                    mat[i][j] = temp
                }
                swaps += 1
            }
            let div = mat[r][lead]
            if div !== 0 {
                // Keep track of divisions
                scale = try (scale * div).simplify()
                for j in 0..<mat.dim.cols {
                    mat[r][j] = try (mat[r][j] / div).simplify()
                }
            }
            for j in 0..<mat.dim.rows {
                if (echelonForm == .rref && j != r) || j > r {
                    let sub = mat[j][lead]
                    for k in 0..<mat.dim.cols {
                        mat[j][k] = try (mat[j][k] - (sub * mat[r][k])).simplify()
                    }
                }
            }
            lead += 1
        }
        
        return (swaps, scale, mat)
    }
    
    /// The strategy to use when calculating the determinant of the matrix.
    public enum DeterminantStrategy {
        /// Calculates determinant using cofactor expansion. `O(n!)`
        case cofactorExpansion
        /// Calculates the determinant using REF form. Much faster `(O(n^3))`
        case ref
    }
    
    /// Calculates the determinant of the matrix using the specified strategy.
    /// REF is generally much, much faster since it involves fewer calculations.
    /// Be ware that calculating a `10 x 10` matrix using `.cofactor expansion is simply impossible.`
    /// - Parameter strategy: The strategy to use, either `.cofactorExpansion` or `.ref`
    /// - Returns: The determinant of the matrix.
    /// - Throws: `ExecutionError.nonSquareMatrix` if the matrix is not a square matrix.
    public func determinant(using strategy: DeterminantStrategy = .ref) throws -> Node {
        switch strategy {
        case .cofactorExpansion:
            return try detCofactor()
        case .ref:
            return try detREF()
        }
    }
    
    /// Calculates the determinant of the matrix by using the diagonal product of its REF form.
    /// `det(A) = (ref(A)[0][0] * ref(A)[1][1] ... * ref(A)[dim(A)][dim(A)])`.
    /// `rref()` keeps track of number of row swaps and scalings.
    /// Currently the fastest algorithm available.
    /// - Complexity: O(n^3)
    /// - Returns: The determinant of the matrix.
    /// - Throws: `ExecutionError.nonSquareMatrix` if the matrix is not a square matrix.
    private func detREF() throws -> Node {
        try Assert.squareMatrix(self)
        let (swaps, scale, _) = try self.reduce(into: .ref)
        return (swaps % 2 == 0) ? scale : -scale
    }
    
    /// Calculates the determinant of the matrix using **cofactor expansion**.
    /// Pick any` i∈{1,…,n}`, then
    /// `det(A)=(−1)^(i+1)*A(i,1)*det(A(i,1))+(−1)^(i+2)*A(i,2)*det(A(i∣2))+⋯+(−1)^(i+n)*A(i,n)*det(A(i∣n))`.
    /// Refer to http://people.math.carleton.ca/~kcheung/math/notes/MATH1107/wk07/07_cofactor_expansion.html.
    /// - Complexity: O(n!)
    /// - Note: The determinant only exists for square matrices.
    private func detCofactor() throws -> Node {
        try Assert.squareMatrix(self)
        if count == 1 { // Base case
            return self[0][0]
        }

        // Expand along the first row
        return try rows[0].elements.enumerated().reduce(0) {
            (det, e) -> Node in
            let sign = e.offset % 2 == 0 ? 1 : -1
            let cofDet = try cofactor(row: 0, col: e.offset).detCofactor()

            // Accelerate by simplifying the expression on the fly
            return try (det + e.element * cofDet * sign)
                .simplify()
        }
    }
    
    /// - Returns: True if the matrix is singular (non-invertible)
    public func isSingular() throws -> Bool {
        guard isSquareMatrix else {
            return false
        }
        return try determinant() === 0
    }
    
    /// Computes the minor cofactor of the matrix
    /// - Parameters:
    ///     - row: The row to be excluded
    ///     - col: The column to be excluded
    public func cofactor(row r: Int, col c: Int) throws -> Matrix {
        try Assert.squareMatrix(self)
        try Assert.index(dim.rows, r)
        try Assert.index(dim.cols, c)
        
        var i = 0, j = 0, n = count
        var cofactor = try! Matrix(n - 1)
        
        // Looping for each element of the matrix
        for row in 0..<n {
            for col in 0..<n {
                
                // Copying into temporary matrix
                // only those element which are
                // not in given row and column
                if (row != r && col != c) {
                    cofactor[i][j] = self[row][col]
                    j += 1
                    
                    // Row is filled, so increase
                    // row index and reset col index
                    if (j == n - 1) {
                        j = 0;
                        i += 1
                    }
                }
            }
        }
        
        return cofactor
    }
    
    /// Computes the cofactor matrix. The cofactor matrix is the cofactor taken at each entry of the matrix.
    /// - Note: Cofactor matrix only exists for square matrices
    public func cofactorMatrix() throws -> Matrix {
        var coMat = try! Matrix(count)
        try cells.forEach {(i, j, _) in
            coMat[i][j] = try cofactor(row: i, col: j).determinant()
        }
        return coMat
    }
    
    /// Calculates adjoint of the matrix.
    /// Ported from C, source: https://www.geeksforgeeks.org/adjoint-inverse-matrix/
    /// - Returns: The adjoint of this matrix, which is an N x N matrix
    public func adjoint() throws -> Matrix {
        try Assert.squareMatrix(self)
        
        var adj = try! Matrix(dim.rows)
        
        let n = count
        if (n == 1) {
            adj = try! Matrix(1)
            adj[0][0] = 1
            return adj
        }
        
        var sign = 1
        
        for i in 0..<n {
            for j in 0..<n {
                // Get cofactor of A[i][j]
                let temp = try cofactor(row: i, col: j)
    
                // Sign of adj[j][i] positive if sum of row
                // and column indexes is even.
                sign = ((i + j) % 2 == 0 ) ? 1: -1
    
                // Interchanging rows and columns to get the
                // transpose of the cofactor matrix
                adj[j][i] = sign * (try temp.determinant())
            }
        }
        
        return adj
    }
    
    /// Calculates inverse of the matrix using the formula
    ///  `inverse(A) = adj(A)/det(A)`
    /// - Returns: The inverse of the matrix
    public func inverse() throws -> Matrix {
        // Find determinant
        let det = try determinant()
        if (det.evaluated?.float80 == 0) {
            throw ExecutionError.singularMatrix
        }
      
        // Find adjoint
        let adj = try adjoint()
      
        // Find inverse using formula "inverse(A) = adj(A)/det(A)"
        var inv = try! Matrix(count)
        for i in 0..<count {
            for j in 0..<count {
                inv[i][j] = try (adj[i][j] / det).simplify()
            }
        }
      
        return inv
    }
    
    /// Creates an identity matrix of the specified dimension
    /// The identity matrix, `I2` for example, is
    /// `[[1, 0], [0, 1]]`; The identity matrix `I3` is
    /// `[[1, 0, 0], [0, 1, 0], [0, 0, 1]]`.
    ///
    /// - Parameter dim: The dimension of the identity matrix.
    /// - Returns: An identity matrix of the specified dimension.
    public static func identityMatrix(_ dim: Int) throws -> Matrix {
        var mat = try Matrix(dim)
        for i in 0..<dim {
            mat[i][i] = 1
        }
        return mat
    }
    
    // MARK: - Node
    
    /// - Returns: True if both are matrix and all elements are equal.
    public func equals(_ node: Node) -> Bool {
        guard let matrix = node as? Matrix else {
            return false
        }
        if matrix.dim != dim {
            return false
        }
        for (i, r) in matrix.rows.enumerated() {
            if r !== self[i] {
                return false
            }
        }
        return true
    }
    
    // MARK: - List Protocol
    
    public subscript(_ idx: Int) -> Row {
        get {
            return rows[idx]
        }
        set {
           rows[idx] = newValue
        }
    }
    
    public var elements: [Node] {
        set {
            if let rows = newValue as? [Row] {
                self.rows = rows
                return
            }
        }
        get {
            return self.rows
        }
    }
    
    // MARK: - Logistics
    
    public var stringified: String {
        let r = rows.reduce(nil) {
            return $0 == nil ? $1.stringified : $0! + ", " + $1.stringified
        }
        return "[\(r!)]"
    }
    
    /// Minimalistic string representation of the matrix.
    public var minimal: String {
        return rows.reduce(nil) {
            return $0 == nil ? $1.minimal : $0! + "\n" + $1.minimal
        } ?? ""
    }
    
    public var ansiColored: String {
        let r = rows.reduce(nil) {
            return $0 == nil ? $1.ansiColored : $0! + ", " + $1.ansiColored
        }
        return "[".red.bold + "\(r!)" + "]".red.bold
    }
    
    public var precedence: Keyword.Precedence {
        return .node
    }
}
