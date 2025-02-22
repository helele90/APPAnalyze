//
//  IncorrectObjCPropertyDefineRule.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/4/16.
//

import Foundation

struct IncorrectObjCPropertyDefineRuleIssueItem: Encodable {
    let className: String
    let instanceProperties: [String]
    let classProperties: [String]

    enum CodingKeys: String, CodingKey {
        case className
        case instanceProperties
        case classProperties
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(className, forKey: .className)
        if !instanceProperties.isEmpty {
            try container.encode(instanceProperties, forKey: .instanceProperties)
        }
        if !classProperties.isEmpty {
            try container.encode(classProperties, forKey: .classProperties)
        }
    }
}

struct IncorrectObjCPropertyDefineRuleIssue: IIssue {
    let name: String = "IncorrectObjCPropertyDefine"

    let module: String

    let severity: Severity = .error

    let info: [IncorrectObjCPropertyDefineRuleIssueItem]

    let message: String = "ObjC属性内存申明错误"

    let type: IssueType = .safe
}

struct IncorrectObjCPropertyDefineRuleConfig {
    let enable: Bool
}

extension Configuration {
    var incorrectObjCPropertyDefineRule: IncorrectObjCPropertyDefineRuleConfig {
        let enable = rules?["incorrectObjCPropertyDefine"]["enable"].bool ?? true
        return IncorrectObjCPropertyDefineRuleConfig(enable: enable)
    }
}

/// 扫描检查`NSArray`/`NSDictionary`/`NSSet`属性`strong`/`copy`申明错误
/// 可能会导致一些异常场景
enum IncorrectObjCPropertyDefineRule: Rule {
    static func check() async -> [any IIssue] {
        let config = APPAnalyze.shared.config.incorrectObjCPropertyDefineRule
        // 未开启检查
        guard config.enable else {
            return []
        }

        let components = APP.shared.modules
        var issues: [IncorrectObjCPropertyDefineRuleIssue] = []
        // 遍历扫描所有类的属性
        for component in components {
            var items: [IncorrectObjCPropertyDefineRuleIssueItem] = []
            for library in component.libraries {
                for className in library.classlist {
                    guard let objcclass = APP.shared.classlist[className] else {
                        log("类不存在\(className)")
                        continue
                    }

                    // 实例属性
                    var instanceProperty: [String] = []
                    for property in objcclass.instanceProperties {
                        let attributes = property.attributes
                        if isWrongProperty(attributes: attributes) {
                            instanceProperty.append(property.name)
                        }
                    }
                    // 类属性
                    var classProperty: [String] = []
                    for property in objcclass.classProperties {
                        let attributes = property.attributes
                        if isWrongProperty(attributes: attributes) {
                            classProperty.append(property.name)
                        }
                    }
                    //
                    if !instanceProperty.isEmpty || !classProperty.isEmpty {
                        let Property = IncorrectObjCPropertyDefineRuleIssueItem(className: objcclass.name, instanceProperties: instanceProperty, classProperties: classProperty)
                        items.append(Property)
                    }
                }
            }
            //
            if !items.isEmpty {
                let issue = IncorrectObjCPropertyDefineRuleIssue(module: component.name, info: items)
                issues.append(issue)
            }
        }
        return issues
    }

    /// 判定`NSArray`/`NSDictionary`/`NSSet`属性`strong`/`copy`申明是否正确
    /// - Parameter attributes: 属性
    /// - Returns: 是否正确
    private static func isWrongProperty(attributes: String) -> Bool {
        let copy = (attributes.hasPrefix("T@\"NSMutableArray") || attributes.hasPrefix("T@\"NSMutableDictionary") || attributes.hasPrefix("T@\"NSMutableSet")) && (attributes.contains("C,") || attributes.contains(",C"))
        let strong = (attributes.hasPrefix("T@\"NSArray") || attributes.hasPrefix("T@\"NSDictionary") || attributes.hasPrefix("T@\"NSSet")) && !(attributes.contains("C,") || attributes.contains(",C"))
        return copy || strong
    }
}
