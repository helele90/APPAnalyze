//
//  CustomParser.swift
//  APPAnalyzeCommand
//
//  Created by hexiao on 2023/11/14.
//

import Foundation
import APPAnalyzeCore


/// 自定义工程解析器
enum CustomParser: Parser {
    
    func parse() async -> [ModuleInfo] {
        var modules: [ModuleInfo] = []
        let module = ModuleInfo(name: "", version: "", frameworks: [], libraries: [], resources: [], dependencies: [], mainModule: true)
        return modules
    }
    
}
