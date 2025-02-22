//
//  Command.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/15.
//

import Foundation

enum Command {
    static func shell(in directory: String, launchPath: String, arguments: [String], encoding: String.Encoding = .utf8) -> String {
        if !FileManager.default.fileExists(atPath: launchPath) {
            print("launchPath不存在-\(launchPath)")
            return ""
        }
//        print("start------------\(arguments)")
        //
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.launchPath = launchPath
        process.arguments = arguments
        process.currentDirectoryPath = directory
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            print("Command执行错误-\(error)")
            assertionFailure()
        }

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(),
                            encoding: encoding) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8)
        if let errorOutput = errorOutput, !errorOutput.isEmpty {
            log("错误输出:-\(arguments)-\(errorOutput)")
        }

        if output.isEmpty {
            log("空输出:-\(arguments)")
        }
        //
        if output.hasSuffix("\n") {
            let endIndex = output.index(output.endIndex, offsetBy: -1)
            return String(output[output.startIndex ..< endIndex])
        } else {
            return output
        }
    }
}
