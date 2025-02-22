//
//  DuplicateResourceRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/11/8.
//

import Foundation

struct DuplicateResourceIssue: IIssue {
    let name: String = "DuplicateResource"

    let module: String

    let severity: Severity = .warning

    let info: [DuplicateFile]

    let message: String = "重复的资源"

    let type: IssueType = .size
}

private struct DuplicateResource: Encodable {
    let name: String
    let size: Int
    let bundle: String
    let module: String
    let path: String

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case bundle
        case module
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(bundle, forKey: .bundle)
        try container.encode(module, forKey: .module)
        try container.encode(size, forKey: .size)
    }
}

/// 检查重复文件。根据 MD5 进行重复判定
enum DuplicateResourceRule: Rule {
    static func check() async -> [any IIssue] {
        let components = APP.shared.modules
        let maxResourceSize = APPAnalyze.shared.config.largeResourceRule.maxSize
        // 判断重复MD5 的文件
        var sizeFileMap: [Int: [DuplicateResource]] = [:]
        // 计算所有文件的MD5值
        for component in components {
            for bundle in component.resource.bundles {
                var files = bundle.files
                //
                for imageSet in bundle.imageSets {
                    for image in imageSet.images {
                        if let path = image.path {
                            let file = File(name: image.filename, path: path, size: image.size)
                            files.append(file)
                        }
                    }
                }
                //
                for dataset in bundle.datasets {
                    for data in dataset.data {
                        if let path = data.path {
                            let file = File(name: data.filename, path: path, size: data.size)
                            files.append(file)
                        }
                    }
                }
                for file in files {
                    // 大于大资源要求才处理。提高性能小资源不进行处理
                    if file.size < maxResourceSize {
                        continue
                    }
                    // 过滤AppIcon
                    if bundle.name == MainBundleName && file.name.hasPrefix("AppIcon") {
                        continue
                    }
                    //
                    let file2 = DuplicateResource(name: file.name, size: file.size, bundle: bundle.name, module: component.name, path: file.path)
                    //
                    if var files = sizeFileMap[file.size] {
                        files.append(file2)
                        sizeFileMap[file.size] = files
                    } else {
                        sizeFileMap[file.size] = [file2]
                    }
                }
            }
        }
        // 计算出 MD5 一样的图片
        var md5FileMap: [String: [DuplicateResource]] = [:]
        sizeFileMap.filter { $0.value.count > 1 }.forEach { _, files in
            for file in files {
                if let key = FileTool.getMD5(path: file.path) {
                    if var files = md5FileMap[key] {
                        files.append(file)
                        md5FileMap[key] = files
                    } else {
                        md5FileMap[key] = [file]
                    }
                }
            }
        }
        //
        let duplicateFiles = md5FileMap.filter { $0.value.count > 1 }.map { _, files in
            let size = files[0].size
            let files = files.map { DuplicateFileItem(name: $0.name, module: $0.module, bundle: $0.bundle) }
            return DuplicateFile(size: size, files: files)
        }.sorted(by: { $0.size > $1.size })
        //
        if !duplicateFiles.isEmpty {
            return [DuplicateResourceIssue(module: APP.shared.mainModule, info: duplicateFiles)]
        }

        return []
    }
}
