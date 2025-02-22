//
//  ModuleFileConfig.swift
//  APPAnalyzeCore
//
//  Created by hexiao on 2023/10/13.
//

import Foundation

/// Module File 解析器
///
/// 将 `IPA`解析为`Macho`和`资源`的数据结构，以`Framework`为粒度
public class ModuleFileParser: Parser {
    
    private let path: String
    
    /// <#Description#>
    /// - Parameter path: <#path description#>
    public init(path: String) {
        self.path = path
    }

    public func parse() async -> [ModuleInfo] {
        let data = try! NSData(contentsOfFile: path) as Data
        let json = JSONDecoder()
        let modules = try! json.decode([ModuleInfo].self, from: data)
        return modules
    }
}
