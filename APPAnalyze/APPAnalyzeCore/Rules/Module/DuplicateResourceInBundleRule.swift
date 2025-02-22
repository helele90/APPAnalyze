//
//  DuplicateImagesetRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/9.
//

import Foundation

struct DuplicateImagesetIssueItem: Encodable {
    let name: String
    let bundle: String
    let modules: [String]
}

struct DuplicateImagesetIssue: IIssue {
    let name: String = "DuplicateResourceInBundle"

    let module: String

    let severity: Severity = .warning

    let info: DuplicateImagesetIssueItem

    let message: String = "Bundle内名字相同的Imageset/Dataset/文件"

    let type: IssueType = .safe
}

private struct ImageSetKey: Hashable {
    let bundle: String
    let name: String
}

private struct FileKey: Hashable {
    let bundle: String
    let name: String
    let relativePath: String
}

/// 检查同一个`Bundle`内同名的 `Imageset`/`Dataset`和文件。
///
/// 同一个Bundle 内不允许存在 2 个同名的`Imageset`/`Dataset`和文件
/// - Warning: 不支持`IPA`模式
public enum DuplicateResourceInBundleRule: Rule {
    public static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        var issues: [DuplicateImagesetIssue] = []
        var bundleImagesetsMap: [ImageSetKey: [String]] = [:]
//        var bundleFilesMap: [FileKey: [String]] = [:]
        var bundlesMap: [String: [String]] = [:]
        // 遍历所有的Imageset
        for component in components {
            for bundle in component.resource.bundles {
                let bundleName = bundle.name
                // 扫描 imageSets
                for imageSet in bundle.imageSets {
                    let imageSetName = "\(imageSet.name).imageset"
                    //
                    let key = ImageSetKey(bundle: bundleName, name: imageSetName)
                    if var modules = bundleImagesetsMap[key] {
                        modules.append(component.name)
                        bundleImagesetsMap[key] = modules
                    } else {
                        bundleImagesetsMap[key] = [component.name]
                    }
                }
                // 扫描 dataSets
                for dataSet in bundle.datasets {
                    let dataSetName = "\(dataSet.name).dataset"
                    //
                    let key = ImageSetKey(bundle: bundleName, name: dataSetName)
                    if var modules = bundleImagesetsMap[key] {
                        modules.append(component.name)
                        bundleImagesetsMap[key] = modules
                    } else {
                        bundleImagesetsMap[key] = [component.name]
                    }
                }
                // Main Bundle
                if bundleName == MainBundleName {
//                    // 检查相同名字的文件
//                    for file in bundle.files {
//                        let fileName = file.name
//                        //
//                        print(file.path)
//                        let key = FileKey(bundle: bundleName, name: fileName, relativePath: "")
//                        if var files = bundleFilesMap[key] {
//                            files.append(component.name)
//                            bundleFilesMap[key] = files
//                        } else {
//                            bundleFilesMap[key] = [component.name]
//                        }
//                    }
                    #warning("Main Bundle 相同文件判断")
                } else { // 非 Main Bundle
                    // 检查重复 Bundle
                    if var modules = bundlesMap[bundleName] {
                        modules.append(component.name)
                        bundlesMap[bundleName] = modules
                    } else {
                        bundlesMap[bundleName] = [component.name]
                    }
                }
            }
        }
        // 重复的 Imageset 和 Dataset
        for (key, modules) in bundleImagesetsMap where modules.count > 1 {
            let info = DuplicateImagesetIssueItem(name: key.name, bundle: key.bundle, modules: modules)
            let issue = DuplicateImagesetIssue(module: APP.shared.mainModule, info: info)
            issues.append(issue)
        }
        // 重复的 Bundle
        for (key, modules) in bundlesMap where modules.count > 1 {
            let name = "\(key).bundle"
            let info = DuplicateImagesetIssueItem(name: name, bundle: MainBundleName, modules: modules)
            let issue = DuplicateImagesetIssue(module: APP.shared.mainModule, info: info)
            issues.append(issue)
        }
        
        //
        return issues
    }
}
