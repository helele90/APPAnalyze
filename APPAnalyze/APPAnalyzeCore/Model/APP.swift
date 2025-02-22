//
//  APP.swift
//  APPAnalyze
//
//  Created by hexiao on 2021/10/21.
//

import Foundation

public class APP {
    
    public static let shared = APP()
    
    /// 类名和类映射表
    public private(set) var classlist: [String: ObjcClass] = [:]
    
    
    /// 协议名和协议映射表
    public private(set) var protolist: [String: ObjcProtocol] = [:]
    
    
    /// 类和类`Category`映射表
    public private(set) var categorylist: [String: [ObjcCategory]] = [:]
    
    
    /// 模块列表
    public private(set) var modules: [Module] = []
    
    public private(set) var mainModule = ""
    
    private init() {
        
    }

    /// 计算所有类的父类列表和协议列表用于后续扫描
    func calculateAllSuperClassAndProtocol() {
        //
        if classlist["NSObject"] == nil {
            let objcobject = ObjcClass(name: "NSObject", superclassName: "", instanceMethods: ["init:", "dealloc", "copy", "mutableCopy", "methodForSelector:", "doesNotRecognizeSelector:", "forwardInvocation:", "observeValueForKeyPath:ofObject:change:context:", "copyWithZone:", "forwardingTargetForSelector:", "methodSignatureForSelector:", ".cxx_construct", ".cxx_destruct"], classMethods: ["load", "initialize", "new", "allocWithZone:", "alloc", "resolveInstanceMethod:", "hash", "class", "superclass", "description", "debugDescription"], ivars: [], instanceProperties: [], classProperties: [], protocols: ["NSObject"], swiftClass: false)
            classlist["NSObject"] = objcobject
        }
        //
        for (_, value) in classlist {
            value.calculateAllSuperClassAndProtocol()
        }
    }

    func insertComponent(component: Module) {
        if !component.systemLibrary {
            modules.append(component)
        }
        // 加入到全局列表
        for library in component.libraries {
            for objcClass in library.classlist2 {
                classlist[objcClass.name] = objcClass
            }
            //
            for objcProtocol in library.protolist2 {
                protolist[objcProtocol.name] = objcProtocol
            }
            //
            for objcCategory in library.catlist {
                let className = objcCategory.cls
                if var objcCategoryList = categorylist[className] {
                    objcCategoryList.append(objcCategory)
                    categorylist[className] = objcCategoryList
                } else {
                    categorylist[className] = [objcCategory]
                }
            }
        }
        //
        if component.mainModule {
            mainModule = component.name
        }
    }
}
