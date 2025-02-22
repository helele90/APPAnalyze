//
//  Printer.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/5.
//

import Foundation
import OSLog

public extension Encodable {
    
    var data: Data {
        let encoder = JSONEncoder()
        return try! encoder.encode(self)
    }
    
}

public func log(_ message: String, file: String = #file, line: Int = #line) {
    let url = URL(string: file)
    let filename = url?.lastPathComponent ?? ""
//    os_log(message, type: .info)
    print("\(filename)-\(line):\(message)")
}
