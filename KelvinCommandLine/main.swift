//
//  main.swift
//  KelvinCommandLine
//
//  Created by Jiachen Ren on 11/10/18.
//  Copyright © 2018 Jiachen Ren. All rights reserved.
//

import Foundation
import Kelvin

let args = CommandLine.arguments

// Set up console
let console = Console(colored: false, verbose: true)
Program.io = console

func compileAndRun(_ document: String) throws {
    do {
        try Program.compileAndRun(document)
        console.flush()
    } catch let e as KelvinError {
        console.error(e.localizedDescription)
        exit(EXIT_FAILURE)
    }
}

// No arguments, enter interactive mode.
if args.count == 1 {
    try console.interactiveLoop()
} else {
    switch try Option.resolve(args[1]) {
    case .expression where args.count == 3:
        let expr = args[2]
        do {
            let output = try Compiler.compile(expr).simplify()
            print(output.stringified)
        } catch let e as KelvinError {
            console.error(e.localizedDescription)
        }
    case .colored:
        console.colored = true
        try console.interactiveLoop()
    case .file where args.count == 3:
        console.colored = false
        console.verbose = false
        try compileAndRun(args[2])
    case .file where args.count == 4:
        let config = try Option.resolve(args[2])
        console.colored = false
        switch config {
        case .verbose:
            console.verbose = true
        case .colored:
            console.colored = true
        case .verboseAndColored:
            console.verbose = true
            console.colored = true
        default:
            print("Unavailable option: \(config.rawValue)")
            Console.printUsage()
            exit(EXIT_FAILURE)
        }
        try compileAndRun(args[3])
    default:
        print("Error: Invalid arguments.")
        Console.printUsage()
        exit(EXIT_FAILURE)
    }
}

exit(EXIT_SUCCESS)
