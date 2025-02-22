//
//  UnusedImagesetRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/9.
//

import Foundation

struct UnusedImagesetIssue: IIssue {
    let name: String = "UnusedImageset"

    let module: String

    let severity: Severity = .warning

    let info: [UnusedFile]

    let message: String = "未使用的Imageset"

    let type: IssueType = .size
}

struct UnusedImagesetRuleConfig {
    let excludeNameRegex: [String]
}

extension Configuration {
    var unusedImagesetRule: UnusedImagesetRuleConfig {
        let excludeNameRegex = rules?["unusedImageset"]["excludeNameRegex"].arrayObject as? [String] ?? []
        return UnusedImagesetRuleConfig(excludeNameRegex: excludeNameRegex)
    }
}

/// 检查未使用的 Imageset。减少包大小
enum UnusedImagesetRule: Rule {
    private static func getPrefixString(text: String) -> String? {
        let filename = text.fileName
        // 移除字符串格式化符号
        if filename.hasSuffix("%@") || filename.hasSuffix("%d") {
            let index = filename.index(filename.endIndex, offsetBy: -2)
            let prefixString = String(filename[..<index])
            if prefixString.count >= 4 && prefixString.count < 40 {
                return prefixString
            }
        }
        // 解决使用图片生成gif的问题
        return text.count >= 4 && text.count < 40 ? text : nil
    }

    static func check() async -> [any IIssue] {
        // 读取配置
        let config = APPAnalyze.shared.config.unusedImagesetRule
        let excludeNameRegex = config.excludeNameRegex
        //
        let components = APP.shared.modules
        var issues: [UnusedImagesetIssue] = []
        var allUsedStrings: Set<String> = []
        var allUsedPrefixStrings: Set<String> = []
        // 业务组件检查
        for component in components {
            var usedStrings: Set<String> = []
            var usedPrefixStrings: Set<String> = []
            component.libraries.forEach { library in
                for usedString in library.usedStrings {
                    if let usedPrefixString = getPrefixString(text: usedString) {
                        usedPrefixStrings.insert(usedPrefixString)
                    }
                    //
                    let fileName = usedString.fileName
                    usedStrings.insert(fileName)
                }
            }
            allUsedPrefixStrings = allUsedPrefixStrings.union(usedPrefixStrings)
            allUsedStrings = allUsedStrings.union(usedStrings)
        }
        // 基础组件检查
        for component in components {
            let name = component.name
            // 查找未使用的imageSets
            var unusedImagesets: [UnusedFile] = []
            for bundle in component.resource.bundles {
                for imageSet in bundle.imageSets {
                    let imageSetName = imageSet.name
                    // 过滤PackedAssetImage
                    if imageSetName == PackedAssetImage {
                        continue
                    }
                    // 正则表达式过滤
                    for regex in excludeNameRegex {
                        let RE = try? NSRegularExpression(pattern: regex, options: .caseInsensitive)
                        if RE?.firstMatch(in: imageSetName, range: NSRange(location: 0, length: imageSetName.count)) != nil {
                            continue
                        }
                    }
                    //
                    if !allUsedStrings.contains(imageSetName) && allUsedPrefixStrings.allSatisfy({ !imageSetName.hasPrefix($0) }) {
                        unusedImagesets.append(UnusedFile(name: imageSetName, size: imageSet.size, bundle: bundle.name))
                    }
                }
            }
            if !unusedImagesets.isEmpty {
                let files = unusedImagesets.sorted(by: { $0.size > $1.size })
                let issue = UnusedImagesetIssue(module: name, info: files)
                issues.append(issue)
            }
            // 查找未使用的datasets
            var unusedDatasets: [UnusedFile] = []
            for bundle in component.resource.bundles {
                for dataSet in bundle.datasets {
                    let dataSetName = dataSet.name
                    // 正则表达式过滤
                    for regex in excludeNameRegex {
                        let RE = try? NSRegularExpression(pattern: regex, options: .caseInsensitive)
                        if RE?.firstMatch(in: dataSetName, range: NSRange(location: 0, length: dataSetName.count)) != nil {
                            continue
                        }
                    }
                    //
                    if !allUsedStrings.contains(dataSetName) && allUsedPrefixStrings.allSatisfy({ !dataSetName.hasPrefix($0) }) {
                        unusedDatasets.append(UnusedFile(name: dataSetName, size: dataSet.size, bundle: bundle.name))
                    }
                }
            }
            //
            if !unusedDatasets.isEmpty {
                let files = unusedDatasets.sorted(by: { $0.size > $1.size })
                let issue = UnusedImagesetIssue(module: name, info: files)
                issues.append(issue)
            }
        }

        return issues
    }
}
