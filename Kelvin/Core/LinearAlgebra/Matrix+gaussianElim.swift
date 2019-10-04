//
//  GaussianElimination.swift
//  macOS Application
//
//  Created by Jiachen Ren on 2/26/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation

/// Implementation of a generic version of gaussian elimination in Swift.
public extension Matrix {
    
    
    /// Gaussian elimination for matrix of N x (N + 1).
    /// Ported from C. Modified from https://www.geeksforgeeks.org/gaussian-elimination/
    ///
    /// - Parameter mat: A matrix of dimension N x (N + 1)
    /// - Returns: The solution vector for the matrix
    static func gaussianElimination(_ mat: Matrix) throws -> Vector {
        var mat = mat
        let N = mat.count
        
        if N < 2 {
            let msg = "gaussian elimination can only be performed on matrices with dimensions greater than 2"
            throw ExecutionError.general(errMsg: msg)
        } else if mat[0].count != N + 1 {
            let msg = "gaussian elimination can only be performed on matrices of dimension N x (N + 1)"
            throw ExecutionError.general(errMsg: msg)
        }
        
        // Reduction into r.e.f. (forward phase)
        mat = try mat.reduce(into: .ref).mat
        
//        /* If matrix is singular */
//        if (singular_flag != -1) {
//            var errorMsg = "cannot perform gaussian elimination on singular matrix - "
//
//            // If the RHS of equation corresponding to
//            // zero row is 0, * system has infinitely
//            // many solutions, else inconsistent
//            if (mat[singular_flag][N]≈ ?? .nan) == 0 {
//                errorMsg += "inconsistent system"
//            } else {
//                errorMsg += "infinite number of solutions"
//            }
//
//            throw ExecutionError.general(errMsg: errorMsg)
//        }
        
        //get solution to system and print it using backward substitution
        return backSub(mat)
    }
    
    /// Helper function for guassianElimination.
    /// Calculates the values of the unknowns.
    /// - Returns: A vector that represents the values of the unknowns.
    private static func backSub(_ mat: Matrix) -> Vector {
        let N = mat.count
        var x: Vector = Vector(Array(repeatElement(0, count: N)))
        
        //Start calculating from last equation up to the first
        for i in (0..<N).reversed() {
            // Start with the RHS of the equation
            x[i] = mat[i][N]
            
            // Initialize j to i+1 since matrix is upper triangular
            for j in i+1..<N {
                // Subtract all the lhs values except the coefficient of the variable
                // whose value is being calculated
                x[i] = x[i] - mat[i][j] * x[j]
            }
            
            // Divide the RHS by the coefficient of the unknown being calculated
            x[i] = x[i] / mat[i][i]
        }
        
        return x
    }
}
