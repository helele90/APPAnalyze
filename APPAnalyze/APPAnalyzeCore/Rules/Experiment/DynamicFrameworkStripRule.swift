////
////  DynamicFrameworkStripRule.swift
////  APPAnalyze
////
////  Created by hexiao on 2023/6/27.
////
//
//import Foundation
//
//struct DynamicFrameworkStripIssue: IIssue {
//    let name: String = "DynamicFrameworkStrip"
//
//    let module: String
//
//    let severity: Severity = .warning
//
//    let info: [String]
//
//    let message: String = "动态库没有移除调试符号"
//
//    let type: IssueType = .size
//}
//
///// 动态库没有移除调试符号
//enum DynamicFrameworkStripRule: Rule {
//    static func check() async -> [any IIssue] {
//        return []
//        let components = APP.shared.components
//        var issues: [DynamicFrameworkStripIssue] = []
//        // 扫描遍历所有二进制库
//        for component in components {
//            // 查找动态库
//            let dynamicLibraries: [String] = component.libraries.filter { $0.isDynamic && notStripDebugSymbol(path: $0.path) }.map { $0.name }
//            //
//            if !dynamicLibraries.isEmpty {
//                let name = component.name
//                let issue = DynamicFrameworkStripIssue(module: name, info: dynamicLibraries)
//                issues.append(issue)
//            }
//        }
//
//        return issues
//    }
//
//    private static func notStripDebugSymbol(path: String) -> Bool {
//        let newPath = "\(path)_new"
//        _ = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: "/usr/bin/xcrun", arguments: ["strip", "-x", path, "-o", newPath])
//        let a = FileTool.getSize(path: path)
//        let b = FileTool.getSize(path: newPath)
//        try? FileManager.default.removeItem(atPath: newPath)
//        return a > b
//    }
//}
