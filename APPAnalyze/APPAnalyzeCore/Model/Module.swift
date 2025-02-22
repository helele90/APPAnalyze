//
//  Framework.swift
//  APPAnalyze
//
//  Created by hexiao on 2023/6/29.
//

import Foundation

public class Module {
    public internal(set) var name: String = ""
    public internal(set) var version: String?
    
    /// 子模块依赖
    public internal(set) var dependencies: Set<String> = []
    
    /// 资源
    public internal(set) var resource: ComponentResource!
    public var allDependenciesCount: Int {
        return allDependencies.count
    }
    
    /// 所有子模块依赖
    ///
    /// 包括子模块自身的依赖
    public internal(set) var allDependencies: Set<String> = []
    
    /// library 列表
    public internal(set) var libraries: [MachO] = []
//    var basic: Bool = false
    var systemLibrary = false
    
    /// 父模块依赖
    public internal(set) var parentDependencies: Set<String> = []
    
    public internal(set) var mainModule: Bool = false

}
