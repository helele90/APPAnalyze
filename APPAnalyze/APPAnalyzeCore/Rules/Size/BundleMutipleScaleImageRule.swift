//
//  BundleScaleImageRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/6/29.
//

import Foundation

struct BundleMutipleScaleImageIssue: IIssue {
    let name: String = "BundleMutipleScaleImage"

    let module: String

    let severity: Severity = .warning

    let info: [BundleScaleImage]

    let message: String = "Bundle图片包含多Scale"

    let type: IssueType = .size
}

private struct Key: Hashable {
    let bundle: String
    let name: String
    let module: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(bundle)
    }

    static func == (lhs: Key, rhs: Key) -> Bool {
        return lhs.name == rhs.name && lhs.bundle == rhs.bundle
    }
}

struct BundleScaleImage: Encodable {
    let bundle: String
    let items: [BundleScaleImageItem]
    
    var maxSize: Int {
        return items.max(by: { $0.size > $1.size })?.size ?? 0
    }
    
}

struct BundleScaleImageItem: Encodable {
    let name: String
    let size: Int
}

private struct Value: Hashable {
    let name: String
    let size: Int
    let scale: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(scale)
    }

    static func == (lhs: Value, rhs: Value) -> Bool {
        return lhs.scale == rhs.scale
    }
}

/// 扫描`Bundle`内同一个图片有多个 scale
enum BundleMutipleScaleImageRule: Rule {
    /// 解析文件全名为文件和 Scale
    /// - Parameter text: 文件全名
    /// - Returns: 文件名，scale
    private static func getNameAndScale(text: String) -> (String, Int)? {
        guard let index = text.lastIndex(of: ".") else {
            return nil
        }

        var fileName = String(text[text.startIndex ..< index])
        //
        var scale = 1
        if fileName.hasSuffix("@2x") {
            let endIndex = fileName.index(fileName.endIndex, offsetBy: -3)
            fileName = String(fileName[fileName.startIndex ..< endIndex])
            //
            scale = 2
        } else if fileName.hasSuffix("@3x") {
            let endIndex = fileName.index(fileName.endIndex, offsetBy: -3)
            fileName = String(fileName[fileName.startIndex ..< endIndex])
            //
            scale = 3
        }
        //
        let type = String(text[index ..< text.endIndex])
        let name = "\(fileName)\(type)"
        return (name, scale)
    }

    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [BundleMutipleScaleImageIssue] = []
        //
        var map: [Key: Set<Value>] = [:]
        // 遍历扫描所有文件
        for component in components {
            let bundles = component.resource.bundles
            for bundle in bundles {
                for file in bundle.files {
                    // 过滤AppIcon
                    if bundle.name == MainBundleName && file.name.hasPrefix("AppIcon") {
                        continue
                    }
                    //
                    guard let (name, scale) = getNameAndScale(text: file.name) else {
                        continue
                    }

                    let key = Key(bundle: bundle.name, name: name, module: component.name)
                    if var files = map[key] {
                        files.insert(Value(name: file.name, size: file.size, scale: scale))
                        map[key] = files
                    } else {
                        map[key] = [Value(name: file.name, size: file.size, scale: scale)]
                    }
                }
            }
        }
        //
        var moduleImages: [String: [BundleScaleImage]] = [:]
        // 同一个图片有多个scale
        for (key, value) in map where value.count > 1 {
            var files = value.sorted(by: { $0.scale > $1.scale })
            files.removeFirst()
            let items = files.map { BundleScaleImageItem(name: $0.name, size: $0.size) }
            let bundleScaleImage = BundleScaleImage(bundle: key.bundle, items: items)
            if var images = moduleImages[key.module] {
                images.append(bundleScaleImage)
                moduleImages[key.module] = images
            } else {
                moduleImages[key.module] = [bundleScaleImage]
            }
        }
        //
        for (module, images) in moduleImages {
            let sortedImages = images.sorted(by: { $0.maxSize > $1.maxSize })
            let issue = BundleMutipleScaleImageIssue(module: module, info: sortedImages)
            issues.append(issue)
        }
        //
        return issues
    }
}
