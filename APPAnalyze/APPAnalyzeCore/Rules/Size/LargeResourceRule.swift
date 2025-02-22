//
//  LargeResourceRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/9.
//

import Foundation

struct LargeResourceItem: Encodable {
    let name: String
    let size: Int
    let bundle: String
    let inAssetsCar: Bool?
}

struct LargeResourceIssue: IIssue {
    let name: String = "LargeResource"

    let module: String

    let severity: Severity = .warning

    let info: [LargeResourceItem]

    let message: String = "大资源"

    let type: IssueType = .size
}

struct LargeResourceRuleConfig {
    let maxSize: Int
}

extension Configuration {
    var largeResourceRule: LargeResourceRuleConfig {
        let maxSize = rules?["largeResource"]["maxSize"].int ?? 1024 * 20
        return LargeResourceRuleConfig(maxSize: maxSize)
    }
}

/// 检查大资源
enum LargeResourceRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [LargeResourceIssue] = []
        // 读取配置
        let maxResourceSize = APPAnalyze.shared.config.largeResourceRule.maxSize
        // 遍历扫描所有资源
        for component in components {
            let name = component.name
            let bundles = component.resource.bundles
            //
            var largeFiles: [LargeResourceItem] = []
            for bundle in bundles {
                for file in bundle.files {
                    // 大于尺寸限制
                    if file.size > maxResourceSize {
                        let largeFile = LargeResourceItem(name: file.name, size: file.size, bundle: bundle.name, inAssetsCar: nil)
                        largeFiles.append(largeFile)
                    }
                }
                // 扫描datasets
                for imageSet in bundle.imageSets {
                    // 过滤PackedAssetImage
                    if imageSet.name == PackedAssetImage {
                        continue
                    }
                    // 大于尺寸限制
                    if imageSet.size > maxResourceSize {
                        let inAssetsCar = imageSet.assetsCar != nil ? true : nil
                        let largeFile = LargeResourceItem(name: imageSet.name, size: imageSet.size, bundle: bundle.name, inAssetsCar: inAssetsCar)
                        largeFiles.append(largeFile)
                    }
                }
                // 扫描datasets
                for dataSet in bundle.datasets {
                    // 大于尺寸限制
                    if dataSet.size > maxResourceSize {
                        let inAssetsCar = dataSet.assetsCar != nil ? true : nil
                        let largeFile = LargeResourceItem(name: dataSet.name, size: dataSet.size, bundle: bundle.name, inAssetsCar: inAssetsCar)
                        largeFiles.append(largeFile)
                    }
                }
            }
            // 查找大资源
            let largeResources = largeFiles.sorted(by: { $0.size > $1.size })
            if !largeResources.isEmpty {
                let issue = LargeResourceIssue(module: name, info: largeResources)
                issues.append(issue)
            }
        }

        return issues
    }
}
