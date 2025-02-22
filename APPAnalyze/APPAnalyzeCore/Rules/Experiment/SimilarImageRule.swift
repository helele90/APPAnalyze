////
////  SimilarImageRule.swift
////  APPAnalyze
////
////  Created by hexiao on 2022/3/18.
////
//
//import Foundation
//
//struct SimilarImageIssue: IIssue {
//    let name: String = "SimilarImage"
//
//    let module: String
//
//    let severity: Severity = .warning
//
//    let info: [DuplicateFileItem]
//
//    let message: String = "相似的图片"
//
//    let type: IssueType = .size
//}
//
///// 扫描相似图片
//enum SimilarImageRule: Rule {
//    static func check() async -> [any IIssue] {
//        let components = APP.shared.components
//        let maxResourceSize = APPAnalyze.shared.config.largeResourceRule.maxSize
//        var images: [String: [File]] = [:]
//        // 计算所有图片 hash 值
//        for component in components {
//            // 只计算超过 20KB 的图片，小图片忽略
//            for bundle in component.resource.bundles {
//                for file in bundle.files {
//                    if file.size < maxResourceSize {
//                        continue
//                    }
//                    // 图片
//                    if file.name.hasSuffix(".png") || file.name.hasSuffix(".jpg") || file.name.hasSuffix(".heic") {
//                        //
//                        let hash = ImageTool.imagehash(path: file.path, hashType: "dhash")
//                        log(hash)
//                        if var items = images[hash] {
//                            items.append(file)
//                            images[hash] = items
//                        } else {
//                            images[hash] = [file]
//                        }
//                    }
//                }
//            }
//        }
//        // 计算出所有 hash 值一样的图片
//        let issues = images.filter { $0.value.count > 1 }.map { image -> SimilarImageIssue in
//            let items = image.value.map { DuplicateFileItem(name: $0.name, module: "", bundle: "123") }
//            return SimilarImageIssue(module: APP.shared.mainModule, info: items)
//        }
//        return issues
//    }
//}
