//
//  CustomReporter.swift
//  APPAnalyzeCommand
//
//  Created by hexiao on 2023/11/14.
//

import Foundation
import APPAnalyzeCore


/// 自定义输出产物
enum CustomReporter: Reporter {
    
    static func generateReport() async {
        let text = ""
        // 保存文件
        APPAnalyze.shared.reporterManager.generateReport(text: text, fileName: "custom.json")
    }
    
}
