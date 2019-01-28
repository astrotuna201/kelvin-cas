//
//  Stat.swift
//  Kelvin
//
//  Created by Jiachen Ren on 1/19/19.
//  Copyright © 2019 Jiachen Ren. All rights reserved.
//

import Foundation
import GameKit

let statOperations: [Operation] = [
    // Statistics, s stands for sample, p stands for population
    .unary("mean", [.list]) {
        return Function("sum", [$0]) / ($0 as! List).count
    },
    .unary("max", [.list]) {
        return Function("max", ($0 as! List).elements)
    },
    .init("max", [.numbers]) {
        let numbers = $0.map {
            $0≈!
        }
        var max: Double = -.infinity
        for n in numbers {
            if n > max {
                max = n
            }
        }
        return max
    },
    .unary("min", [.list]) {
        return Function("min", ($0 as! List).elements)
    },
    .init("min", [.numbers]) {
        let numbers = $0.map {
            $0≈!
        }
        var min: Double = .infinity
        for n in numbers {
            if n < min {
                min = n
            }
        }
        return min
    },
    .init("mean", [.universal]) { nodes in
        return ++nodes / nodes.count
    },
    .unary("ssx", [.list]) {
        return try ssx(($0 as! List).convertToDoubles())
    },
    .unary("variance", [.list]) {
        let list = $0 as! List
        let s = try ssx(list.convertToDoubles())
        guard let n = s as? Double else {
            // If we cannot calculate sum of difference squared,
            // return the error message.
            return s
        }

        return List([
            Tuple("sample", n / (list.count - 1)),
            Tuple("population", n / list.count)
        ])
    },
    .init("stdev", [.list]) { nodes in
        let vars = try Function("variance", nodes).simplify()

        guard let elements = (vars as? List)?.elements else {

            // Forward error message
            return vars
        }

        let vs: [Double] = elements.map {
                    $0 as! Tuple
                }
                .map {
                    $0≈!
                }

        let stdevs = vs.map(sqrt)
        assert(stdevs.count == 2)

        let es = [Tuple("Sₓ", stdevs[0]), Tuple("σₓ", stdevs[1])]
        return List(es)
    },

    // Summation
    .unary("sum", [.list]) {
        let list = $0 as! List
        var nSum: Double = 0
        var nans = [Node]()

        for element in list.elements {
            if element is Int {
                nSum += Double(element as! Int)
            } else if element is Double {
                nSum += element as! Double
            } else {
                nans.append(element)
            }
        }
        return ++nans + nSum
    },
    .init("sum", [.universal]) { nodes in
        return ++nodes
    },
    
    // IQR, 5 number summary
    .unary("sum5n", [.list]) {
        let list = try ($0 as! List).convertToDoubles()
        return try fiveNSummary(list)
    },
    .unary("iqr", [.list]) {
        let list = try ($0 as! List).convertToDoubles()
        let stat = try quartiles(list)
        return stat.q3 - stat.q1
    },
    .unary("median", [.list]) {
        let list = try ($0 as! List).convertToDoubles()
        let (m, _) = median(list)
        return m
    },
    .unary("outliers", [.list]) {
        let list = try ($0 as! List).convertToDoubles()
        return try outliers(list)
    },
    
    // Distribution
    // normCdf from -∞ to x
    .unary("normCdf", [.number]) {
        normCdf($0≈!)
    },
    
    // normCdf from a to b, centered at zero with stdev of 1
    .binary("normCdf", [.number, .number]) {
        normCdf(from: $0≈!, to: $1≈!)
    },
    // normCdf from a to b, centered at zero with stdev of 1
    .init("normCdf", [.number, .number, .number, .number]) {
        let args: [Double] = $0.map {$0≈!}
        return normCdf(from: args[0], to: args[1], μ: args[2], σ: args[3])
    },
    .init("randNorm", [.number, .number, .int]) {
        let elements = randNorm(μ: $0[0]≈!, σ: $0[1]≈!, n: $0[2] as! Int)
        return List(elements)
    },
    .init("invNorm", [.number, .number, .number]) {
        let stdev = $0[2]≈!
        let mean = $0[1]≈!
        return try invNorm($0[0]≈!) * stdev + mean
    },
    .unary("normPdf", [.any]) {
        return normPdf($0)
    },
    .init("normPdf", [.any, .any, .any]) {
        return normPdf($0[0], μ: $0[1], σ: $0[2])
    }
]

fileprivate func outliers(_ list: [Double]) throws -> List {
    let stats = try quartiles(list)
    let iqr = stats.q3 - stats.q1
    let ut = stats.q3 + 1.5 * iqr
    let lt = stats.q1 - 1.5 * iqr
    
    let leOutliers = list.filter {
        $0 < lt
    }
    
    let ueOutliers = list.filter {
        $0 > ut
    }
    
    return List([
        Tuple("lower end", List(leOutliers)),
        Tuple("upper end", List(ueOutliers))
    ])
    
    // TODO: Confidence interval, margin of error.
    // Margin of error = z-score (from confidence interval) * stdev of sampling dist.
    // Confidence interval = estimate +/- margin of error.
}

fileprivate func fiveNSummary(_ list: [Double]) throws -> Node {
    let c = list.count
    if c == 0 {
        throw ExecutionError.general(errMsg: "cannot perform summary statistics on empty list.")
    }
    
    let min = list.first!
    let max = list.last!

    let m = try quartiles(list)
    
    let summary: [Tuple] = [
        .init("min", min),
        .init("q1", m.q1),
        .init("median", m.m),
        .init("q3", m.q3),
        .init("max", max)
    ]
    
    return List(summary)
}

fileprivate func quartiles(_ numbers: [Double]) throws -> (q1: Double, m: Double, q3: Double) {
    let c = numbers.count
    if c == 0 {
        throw ExecutionError.general(errMsg: "cannot perform summary statistics on empty list.")
    }
    
    let (m, i) = median(numbers)
    var l = numbers, r = numbers
    let idx = i ?? c / 2
    l = Array(numbers.prefix(upTo: idx))
    r = Array(numbers.suffix(from: idx + 1))

    let (q1, _) = median(l)
    let (q3, _) = median(r)
    return (q1, m, q3)
}

fileprivate func median(_ numbers: [Double]) -> (Double, idx: Int?) {
    let c = numbers.count
    if c == 0 {
        return (.nan, nil)
    }
    
    if c % 2 == 0 {
        let m = ((numbers[c / 2] + numbers[c / 2 - 1])) / 2
        return (m, nil)
    } else {
        let i = c / 2
        return (numbers[i], i)
    }
}

/// Sum of difference squared.
fileprivate func ssx(_ numbers: [Double]) throws -> Node {

    // Calculate average.
    let sum: Double = numbers.reduce(0) {
        $0 + $1
    }
    let avg: Double = sum / Double(numbers.count)

    // Sum of squared differences
    return numbers.map {
                pow($0 - avg, 2)
            }
            .reduce(0) { (a: Double, b: Double) in
                return a + b
            }
}

/// A lightweight algorithm for calculating cummulative distribution frequency.
fileprivate func normCdf(_ x: Double) -> Double {
    var L: Double, K: Double, w: Double
    
    // Constants
    let a1 = 0.31938153, a2 = -0.356563782, a3 = 1.781477937
    let a4 = -1.821255978, a5 = 1.330274429
    
    L = fabs(x)
    K = 1.0 / (1.0 + 0.2316419 * L)
    w = 1.0 - 1.0 / sqrt(2 * .pi) * exp(-L * L / 2) * (a1 * K + a2 * K * K + a3 * pow(K, 3) + a4 * pow(K, 4) + a5 * pow(K, 5))
    
    if (x < 0 ){
        w = 1.0 - w
    }
    return w
}

/**
 Cummulative distribution frequency from lower bound to upper bound,
 where the normal curve is centered at zero with stdev of 1.
 
 - Parameters:
    - from: Lower bound
    - to: Upper bound
 - Returns: Cummulative distribution frequency from lowerbound to upperbound.
 */
fileprivate func normCdf(from lb: Double, to ub: Double) -> Double {
    return normCdf(ub) - normCdf(lb)
}

/**
 Cummulative distribution frequency from lower bound to upper bound,
 where the normal curve is centered at μ with stdev of σ.
 
 - Parameters:
    - from: Lower bound
    - to: Upper bound
    - μ: mean
    - σ: Standard deviation
 - Returns: Cummulative distribution frequency from lowerbound to upperbound.
 */
fileprivate func normCdf(from lb: Double, to ub: Double, μ: Double, σ: Double) -> Double {
    return normCdf((ub - μ) / σ) - normCdf((lb - μ) / σ)
}

/**
 Normal probability density function.
 Definition: 1 / √(2π) * e ^ (-1 / 2) ^ 2
 */
fileprivate func normPdf(_ x: Node) -> Node {
    return 1 / √(2 * "pi"&) * ("e"& ^ ((-1 / 2) * (x ^ 2)))
}

/**
 normalPdf(x,μ,σ)=1 / σ * normalPdf((x−μ) / σ)
 */
fileprivate func normPdf(_ x: Node, μ: Node, σ: Node) -> Node {
    return 1 / σ * normPdf((x - μ) / σ)
}

fileprivate func randNorm(μ: Double, σ: Double, n: Int) -> [Double] {
    let gaussianDist = GaussianDistribution(
        randomSource: GKRandomSource(),
        mean: Float(μ),
        deviation: Float(σ))
    return [Double](repeating: 0, count: n).map {_ in
        Double(gaussianDist.nextFloat())
    }
}

fileprivate class GaussianDistribution {
    private let randomSource: GKRandomSource
    let mean: Float
    let deviation: Float
    
    init(randomSource: GKRandomSource, mean: Float, deviation: Float) {
        precondition(deviation >= 0)
        self.randomSource = randomSource
        self.mean = mean
        self.deviation = deviation
    }
    
    func nextFloat() -> Float {
        guard deviation > 0 else { return mean }
        
        let x1 = randomSource.nextUniform() // A random number between 0 and 1
        let x2 = randomSource.nextUniform() // A random number between 0 and 1
        let z1 = sqrt(-2 * log(x1)) * cos(2 * Float.pi * x2) // z1 is normally distributed
        
        // Convert z1 from the Standard Normal Distribution to our Normal Distribution
        return z1 * deviation + mean
    }
}

/**
 Convert an area representing cummulative distribution frequency to its
 corresponding standard deviation. Of course I didn't come up with this
 beast myself!
 
 - Credit: https://stackedboxes.org/2017/05/01/acklams-normal-quantile-function/
 */
fileprivate func invNorm(_ p: Double) throws -> Double {
    if p >= 1 || p <= 0  {
        throw ExecutionError.invalidDomain(0, 1)
    }
    
    let a1 = -39.69683028665376
    let a2 = 220.9460984245205
    let a3 = -275.9285104469687
    let a4 = 138.3577518672690
    let a5 = -30.66479806614716
    let a6 = 2.50662827745
    
    let b1 = -54.47609879822406
    let b2 = 161.5858368580409
    let b3 = -155.6989798598866
    let b4 = 66.80131188771972
    let b5 = -13.2806815528
    
    let c1 = -0.007784894002430293
    let c2 = -0.3223964580411365
    let c3 = -2.400758277161838
    let c4 = -2.549732539343734
    let c5 = 4.374664141464968
    let c6 = 2.93816398269
    
    let d1 = 0.007784695709041462
    let d2 = 0.3224671290700398
    let d3 = 2.445134137142996
    let d4 = 3.754408661907416
    
    let p_low =  0.02425
    let p_high = 1 - p_low
    var q: Double, r: Double, e: Double, u: Double
    var x = 0.0
    
    // Rational approximation for lower region.
    if (0 < p && p < p_low) {
        q = sqrt(-2 * log(p))
        x = (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1)
    }
    
    // Rational approximation for central region.
    if (p_low <= p && p <= p_high) {
        q = p - 0.5
        r = q * q
        x = (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q / (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1)
    }
    
    // Rational approximation for upper region.
    if (p_high < p && p < 1) {
        q = sqrt(-2 * log(1 - p))
        x = -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1)
    }
    
    if 0 < p && p < 1 {
        e = 0.5 * erfc(-x / sqrt(2)) - p
        u = e * sqrt(2 * .pi) * exp(x * x / 2)
        x = x - u / (1 + x * u / 2)
    }
    
    return x
}
