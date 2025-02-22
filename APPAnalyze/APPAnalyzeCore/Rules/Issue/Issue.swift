//
//  Issue.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/21.
//

import Foundation

public enum IssueType: String, Encodable {
    case safe = "安全"
    case performance = "性能"
    case size = "包体积"
    case module = "组件化工程规范"
}

public protocol IIssue: Encodable {
    associatedtype Info: Encodable

    var name: String { get }
    var module: String { get }
    var severity: Severity { get }
    var info: Info { get }
    var message: String { get }
    var type: IssueType { get }
}

public struct Issue: Encodable {
    let name: String
    let module: String
    let severity: Severity
    let info: Any
    let message: String
    let type: IssueType

    enum CodingKeys: String, CodingKey {
        case name
        case info
        case module
        case severity
        case message
        case type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(module, forKey: .module)
        try container.encode(severity.rawValue, forKey: .severity)
        if let info = info as? Encodable {
            try container.encode(info, forKey: .info)
        }
        try container.encode(message, forKey: .message)
        try container.encode(type.rawValue, forKey: .type)
    }

    public init(issue: any IIssue) {
        name = issue.name
        module = issue.module
        severity = issue.severity
        info = issue.info
        message = issue.message
        type = issue.type
    }
}

struct DuplicateFileItem: Encodable {
    let name: String
    let module: String
    let bundle: String
}

struct DuplicateFile: Encodable {
    let size: Int
    let files: [DuplicateFileItem]
}

struct UnusedFile: Encodable {
    let name: String
    let size: Int
    let bundle: String
}

struct UnusedCategoryMethodItem: Encodable {
    let name: String
    let className: String
    let instanceMethods: [String]
    let classMethods: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case `class`
        case instanceMethods
        case classMethods
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(className, forKey: .class)
        if !instanceMethods.isEmpty {
            try container.encode(instanceMethods, forKey: .instanceMethods)
        }
        if !classMethods.isEmpty {
            try container.encode(classMethods, forKey: .classMethods)
        }
    }
}

public struct UnusedComponent: Encodable {
    let components: [String]
    let hasRouter: Bool
}

public enum Severity: String, Encodable {
    case warning = "Warning"
    case error = "Error"
}
