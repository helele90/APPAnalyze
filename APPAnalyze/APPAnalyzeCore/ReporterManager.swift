//
//  ReporterManager.swift
//  APPAnalyzeCore
//
//  Created by hexiao on 2023/7/20.
//

import Foundation

/// 报告协议
public protocol Reporter {
    static func generateReport() async
}

/// 报告管理器
///
/// 默认为`包体积`/`问题扫描`报告。可以调用`addReporter`添加自定义报告
public class ReporterManager {
    
    lazy var outputPath = APPAnalyze.shared.config.reportOutputPath!
    
    private(set) var reporters: [Reporter.Type] = [APPPackageSizeReporter.self, IssueReporter.self]

    func print() async {
        //
        try! FileManager.default.createDirectory(atPath: "\(outputPath)", withIntermediateDirectories: true, attributes: nil)
        //
        await withTaskGroup(of: Void.self) { taskGroup in
            for reporter in reporters {
                taskGroup.addTask {
                    await reporter.generateReport()
                }
            }
        }
    }
    
    /// 添加自定义报告类型
    /// - Parameter reporter: 报告类型
    public func addReporter(reporter: Reporter.Type) {
        reporters.append(reporter)
    }

    public func removeReporter(reporter: Reporter.Type) {
        reporters.removeAll(where: { $0 == reporter })
    }
    
    public func generateReport(text: String, fileName: String) {
        let data = text.data(using: .utf8)
        let fileName = "\(outputPath)/\(fileName)"
        FileManager.default.createFile(atPath: fileName, contents: data, attributes: nil)
    }
    
    public func generateReport(data: Data, fileName: String) {
        let fileName = "\(outputPath)/\(fileName)"
        FileManager.default.createFile(atPath: fileName, contents: data, attributes: nil)
    }
    
}
