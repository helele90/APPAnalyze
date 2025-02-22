//
//  MachoTool.swift
//  APPAnalyze
//
//  Created by Xiao He on 2021/10/16.
//

import Foundation

enum CatStep {
    case instanceMethods
    case classMethods
    case protocols
    case instanceProperties
}

enum ProtoStep {
    case protocols
    case instanceMethods
    case classMethods
    case optionalInstanceMethods
    case optionalClassMethods
    case instanceProperties
}

enum ClassDataStep {
    case baseMethods
    case baseProtocols
    case ivars
    case baseProperties
}

enum ObjcSection: String {
    case classlist = "__objc_classlist"
    case classrefs = "__objc_classrefs"
    case superrefs = "__objc_superrefs"
    case catlist = "__objc_catlist"
    case protolist = "__objc_protolist"
    case selrefs = "__objc_selrefs"
}

enum MachoTool {
    /// 解析二进制库
    /// - Parameters:
    ///   - directory: 二进制库目录地址
    ///   - name: 二进制库名
    /// - Warning: 1.swift类class-ivar-type/class-baseProperties是空的 2.Swift类不会加入到classrefs
    /// - Returns: 二进制库信息
    static func getMachoInfo(path: String, dynamic: Bool, arch: ArchType) async -> MachO {
        let machoPath = path
        let machoName = URL(string: path)!.lastPathComponent
        // Swift使用类查找
        let swiftClassRefs = APPAnalyze.shared.config.unusedClassRule.swiftEnable
        let objcIvars = APPAnalyze.shared.config.unusedObjCPropertyRule.enable
        //
        print("\(machoName):解析 __DATA Objective-C Segment")
        async let getObjCData = await getObjCData(path: machoPath)
        //
        print("\(machoName):解析 __TEXT Section")
        async let getSectionText = await getSectionText(path: machoPath, arch: arch, swiftClassRefs: swiftClassRefs, objcIvars: objcIvars)
        //
        print("\(machoName):解析 __TEXT __cstring")
        async let getUsedStrings = await getUsedStrings(path: machoPath)
        //
        let data = await [getObjCData, getSectionText, getUsedStrings] as [Any]
        let sectionObjCData = data[0] as! MachoObjCData
        let sectionText = data[1] as! MachoText
        let usedStrings = data[2] as! Set<String>
        //
        let classrefs = sectionObjCData.classrefs.union(sectionText.classRefs)
        //
        let classlist = sectionObjCData.classlist.map { $0.name }
        let protolist = sectionObjCData.protolist.map { $0.name }
        //
        let macho = MachO(name: machoName, classlist: classlist, catlist: sectionObjCData.catlist, protolist: protolist, classrefs: classrefs, superrefs: sectionObjCData.superrefs, selrefs: sectionObjCData.selrefs, ivarTypeRefs: sectionObjCData.ivarTypeRefs, usedStrings: usedStrings, path: machoPath, objcIvarRefs: sectionText.objcIvarRefs, arch: arch, classlist2: sectionObjCData.classlist, protolist2: sectionObjCData.protolist, symbols: sectionText.symbols, usedSymbols: sectionText.usedSymbols)
        return macho
    }

    /// 获取所有二进制库中定义的字符串
    /// - Parameter path: 二进制库文件地址
    /// - Returns: 所有字符串
    static func getUsedStrings(path: String) async -> Set<String> {
        var output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: APPAnalyze.shared.config.otoolPath, arguments: ["-v", "-X", "-s", "__TEXT", "__cstring", path])
        // 部分 macho 会优化__cstring 的位置
        if output.isEmpty {
            output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: APPAnalyze.shared.config.otoolPath, arguments: ["-v", "-X", "-s", "__RODATA", "__cstring", path])
        }
        //
        let lines = output.split(separator: "\n")
        //
        var strings: Set<String> = []
        //
        for line in lines where !line.isEmpty {
            if line.hasPrefix("_TtC") {
                continue
            }
            strings.insert(String(line))
        }
        return strings
    }
    
    /// 是否是动态库
    /// - Parameter path: 二进制库文件地址
    /// - Returns: 是否是动态库
    static func isDynamicFramework(path: String) -> Bool {
        let output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: "/usr/bin/file", arguments: [path])
        return output.contains("dynamically linked shared library")
    }


    static func getFrameworkSize(path: String, arch: ArchType) -> LibrarySize {
//        #warning("mode")
        // IPA扫描直接计算二进制库文件尺寸
//        if APPAnalyze.shared.config.mode == .ipa {
//            let size = FileTool.getSize(path: path)
//            let name = URL(string: path)!.lastPathComponent
//            return LibrarySize(totalSize: size, files: [LibraryFileSize(name: name, size: size)])
//        }
        //
        let output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: APPAnalyze.shared.config.sizePath, arguments: ["-arch", arch.rawValue, path])
        var lines = output.split(separator: "\n")
        lines.removeFirst()
        // 部分库没有单个文件大小信息
        if lines.count == 1 {
            let line = lines[0]
            let substring = line.split(separator: "\t", omittingEmptySubsequences: true)
            let textSize = Int(substring[0])!
            let dataSize = Int(substring[1])!
            var totalSize = textSize + dataSize
            // LINKEDIT尺寸大小，取一个平均值
            totalSize = totalSize + Int(Double(totalSize) * 0.04)
            //
            return LibrarySize(totalSize: totalSize, files: [])
        }
        //
        var fileSizes: [LibraryFileSize] = []
        var totalSize = 0
        //
        for line in lines {
            let substring = line.split(separator: "\t", omittingEmptySubsequences: true)
            let textSize = Int(substring[0])!
            let dataSize = Int(substring[1])!
            var size = textSize + dataSize
            //
            size = Int(Double(size) * 0.9)
            if size == 0 {
                continue
            }
            //
            let bracketIndex = line.lastIndex(where: { $0 == "(" })!
            let startIndex = line.index(bracketIndex, offsetBy: 1)
            let endIndex = line.index(line.endIndex, offsetBy: -1)
            let name = String(line[startIndex ..< endIndex])
            //
            let fileSize = LibraryFileSize(name: name, size: size)
            fileSizes.append(fileSize)
            //
            totalSize += size
        }

        return LibrarySize(totalSize: totalSize, files: fileSizes)
    }

    private static func getSectionDataInfo(path: String) -> String {
        let output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: APPAnalyze.shared.config.otoolPath, arguments: ["-oV", path], encoding: .isoLatin1)
        return output
    }

    static func getObjCData(path: String) async -> MachoObjCData {
        var section: ObjcSection?
        //
        var selrefs: Set<String> = []
        //
        var classrefs: Set<String> = []
        //
        var superrefs: Set<String> = []
        //
        var classlist: [String: ObjcClass] = [:]
        var className = ""
        var swiftClass = false
        var classAddress = ""
        var superClassName = ""
        var superclassAddress = ""
        var metaClass = false
        var classDataStep: ClassDataStep = .baseMethods
        var instanceMethods: Set<String> = []
        var instanceProperties: [ObjcProperty] = []
        var propertyName = ""
        var classProperties: [ObjcProperty] = []
        var classMethods: Set<String> = []
        var classProtocols: Set<String> = []
        var classIvars: [String] = []
        var classAddressNameMap: [String: String] = [:]
        //
//        var protolist: [String] = []
        var protolist: [ObjcProtocol] = []
        var protoName = ""
        var protoInstanceMethods: [String] = []
        var protoOptionalInstanceMethods: [String] = []
        var protoInstanceProperties: [ObjcProperty] = []
        var protoClassMethods: [String] = []
        var protoOptionalClassMethods: [String] = []
        var protoProtocols: [String] = []
        var protoStep: ProtoStep = .protocols
        //
        var catlist: [ObjcCategory] = []
        var catStep: CatStep = .instanceMethods
        var catName = ""
        var catClass = ""
        var catInstanceMethods: Set<String> = []
        var catClassMethods: Set<String> = []
        var catProtocols: [String] = []
        var catInstanceProperties: [ObjcProperty] = []
        //
        var ivarTypeRefs: Set<String> = []
        //
        var waitingClassAddress: Set<String> = []
        var waitingSuperAddress2: [String: String] = [:]
        //
        var swiftClassCount = 0
        //
        let info = MachoTool.getSectionDataInfo(path: path)
        info.lines { line, indent in
            if indent == 0, line.hasPrefix("Con"), line.hasSuffix("section") {
                if line.hasSuffix("classlist) section") {
                    section = .classlist
                } else if line.hasSuffix("classrefs) section") {
                    section = .classrefs
                } else if line.hasSuffix("superrefs) section") {
                    section = .superrefs
                } else if line.hasSuffix("catlist) section") {
                    section = .catlist
                } else if line.hasSuffix("protolist) section") {
                    section = .protolist
                } else if line.hasSuffix("selrefs) section") {
                    section = .selrefs
                } else {
                    section = nil
                }

                return
            }

            switch section {
            case .classlist:
                if indent == 0 {
                    if line.hasPrefix("00") {
                        if !className.isEmpty {
                            //
                            let objcclass = ObjcClass(name: className, superclassName: superClassName, instanceMethods: Array(instanceMethods), classMethods: Array(classMethods), ivars: classIvars, instanceProperties: instanceProperties, classProperties: classProperties, protocols: Array(classProtocols), swiftClass: swiftClass)
                            classlist[objcclass.name] = objcclass
                            //
                            classAddressNameMap[classAddress] = className
                            //
                            className = ""
                            //
                            superClassName = ""
                            superclassAddress = ""
                            instanceMethods.removeAll()
                            classMethods.removeAll()
                            instanceProperties.removeAll()
                            classProperties.removeAll()
                            classProtocols.removeAll()
                            classIvars.removeAll()
                            swiftClass = false

                            metaClass = false
                        }

                        //
                        let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                        classAddress = String(substring[1])
                    } else if line.hasPrefix("Meta Class") {
                        metaClass = true
                        classDataStep = .baseMethods
                    }
                } else if indent == 1 {
                    if line.hasPrefix("superclass") {
                        if !metaClass {
                            if let range = line.range(of: " _OBJC_CLASS_$_") {
                                let startIndex = range.upperBound
                                superClassName = String(line[startIndex ..< line.endIndex]).swiftClassNameDemangled
                                superrefs.insert(superClassName)
                            } else if let range = line.range(of: " _$") {
                                let startIndex = range.upperBound
                                superClassName = String(line[startIndex ..< line.endIndex])
                                superClassName = superClassName.swiftClassNameDemangled
                                superrefs.insert(superClassName)
                            } else {
//                                log("找不到superclass-\(line)")
                                let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                                if substring.count == 2 {
                                    superclassAddress = String(substring[1])
//                                    superrefs.insert(superclassAddress)
                                }
                            }
                        }
                        return
                    }
                } else if indent == 2 {
                    if line.hasPrefix("name") {
                        let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                        className = String(substring[2])
                        //
                        let newClassName = className.swiftClassNameDemangled
                        swiftClass = className.count != newClassName.count
                        //
                        if swiftClass {
                            swiftClassCount += 1
                        }
                        className = newClassName
                        //
                        if superClassName.isEmpty {
                            waitingSuperAddress2[className] = superclassAddress
                        }
                        return
                    } else if line.hasPrefix("baseMethods") {
                        classDataStep = .baseMethods
                        return
                    } else if line.hasPrefix("baseProtocols") {
                        classDataStep = .baseProtocols
                        return
                    } else if line.hasPrefix("ivars") {
                        classDataStep = .ivars
                        return
                    } else if line.hasPrefix("baseProperties") {
                        classDataStep = .baseProperties
                        return
                    }
                } else if indent == 3 {
                    switch classDataStep {
                    case .baseMethods:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let methodname = String(substring[2])
                            //
                            if !methodname.hasPrefix("(0x") {
                                if metaClass {
                                    classMethods.insert(methodname)
                                } else {
                                    instanceMethods.insert(methodname)
                                }
                            }
                        } else if line.hasPrefix("imp") {
                            if line.hasSuffix(":]") {
                                let substring = line.split(separator: " ", omittingEmptySubsequences: true).last!
                                let endIndex = substring.index(substring.endIndex, offsetBy: -1)
                                let methodName = String(substring[substring.startIndex ..< endIndex])
                                if metaClass {
                                    classMethods.insert(methodName)
                                } else {
                                    instanceMethods.insert(methodName)
                                }
                            }
                        }
                    case .ivars:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let ivarName = String(substring.last!)
                            classIvars.append(ivarName)
                        } else if line.hasPrefix("type") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            if let ivarType = substring.last {
                                // 处理 ivar类型
                                if ivarType.hasPrefix("@\"") {
                                    let startIndex = ivarType.index(ivarType.startIndex, offsetBy: 2)
                                    let endIndex = ivarType.index(ivarType.endIndex, offsetBy: -1)
                                    let type = String(ivarType[startIndex ..< endIndex])
                                    //
                                    let ivarTypeRef = type.swiftClassNameDemangled
                                    ivarTypeRefs.insert(ivarTypeRef)
                                }
                            } else {
                                log("type为空-\(line)")
                            }
                        }
                    case .baseProperties:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            propertyName = String(substring[2])
                        } else if line.hasPrefix("attributes") {
                            let attributes = String(line.components(separatedBy: " ")[2])
                            // 处理 property 类型
                            var propertyType = ""
                            if attributes.hasPrefix("T@\""), let range = attributes.range(of: "\",") {
                                let startIndex = attributes.index(attributes.startIndex, offsetBy: 3)
                                let endIndex = range.lowerBound
                                propertyType = String(attributes[startIndex ..< endIndex])
                                //
                                let ivarTypeRef = propertyType.swiftClassNameDemangled
                                ivarTypeRefs.insert(ivarTypeRef)
                            }
                            //
                            let property = ObjcProperty(name: propertyName, type: propertyType, attributes: attributes)
                            if metaClass {
                                classProperties.append(property)
                            } else {
                                instanceProperties.append(property)
                            }
                            propertyName = ""
                        }
                    // 添加 ivartypes
                    default:
                        break
                    }
                } else if indent == 4 {
                    switch classDataStep {
                    case .baseProtocols:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let protoName = String(substring[2]).swiftProtocolName
                            classProtocols.insert(protoName)
                        }
                    default:
                        break
                    }
                }
            case .catlist:
                if indent == 0 {
                    if line.hasPrefix("00") {
                        if !catName.isEmpty {
                            let cat = ObjcCategory(name: catName, cls: catClass, instanceMethods: Array(catInstanceMethods), classMethods: Array(catClassMethods), protocols: catProtocols, instanceProperties: catInstanceProperties)
                            catlist.append(cat)
                            //
                            catName = ""
                            catClass = ""
                            catProtocols.removeAll()
                            catInstanceMethods.removeAll()
                            catClassMethods.removeAll()
                            catInstanceProperties.removeAll()
                        }
                        // 兼容 swiftcategory
                        if let (a, b) = parseProtoCls(line: line) {
                            catClass = a
                            catName = b
                        }
                    }
                } else if indent == 1 {
                    // 处理 IPA 场景扫描
                    if catName.isEmpty || catClass.isEmpty {
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            if substring.count == 3 {
                                catName = String(substring[2])
                            } else {
                                log("catName错误")
                            }
                        } else if line.hasPrefix("cls") {
                            let last = String(line.split(separator: " ", omittingEmptySubsequences: true).last!)
                            if last.hasPrefix("0x") {
                                if let name = classAddressNameMap[last] {
                                    catClass = name
                                } else {
                                    log(line)
                                }
                            } else if let range = last.range(of: "_OBJC_CLASS_$_") {
                                let startIndex = range.upperBound
                                catClass = String(last[startIndex ..< last.endIndex]).swiftClassNameDemangled
                            }
                        }
                    }

                    if line.hasPrefix("protocols") {
                        catStep = .protocols
                        return
                    } else if line.hasPrefix("instanceMethods") {
                        catStep = .instanceMethods
                        return
                    } else if line.hasPrefix("classMethods") {
                        catStep = .classMethods
                        return
                    } else if line.hasPrefix("instanceProperties") {
                        catStep = .instanceProperties
                        return
                    }
                } else if indent == 2 {
                    switch catStep {
                    case .instanceMethods, .classMethods:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let methodname = String(substring[2])
                            if !methodname.hasPrefix("(0x") {
                                if catStep == .instanceMethods {
                                    catInstanceMethods.insert(methodname)
                                } else {
                                    catClassMethods.insert(methodname)
                                }
                            }
                        } else if line.hasPrefix("imp") {
                            if line.hasSuffix(":]") {
                                let substring = line.split(separator: " ", omittingEmptySubsequences: true).last!
                                let endIndex = substring.index(substring.endIndex, offsetBy: -1)
                                let methodName = String(substring[substring.startIndex ..< endIndex])
                                if catStep == .instanceMethods {
                                    catInstanceMethods.insert(methodName)
                                } else {
                                    catClassMethods.insert(methodName)
                                }
                            }
                        }
                    case .instanceProperties:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            propertyName = String(substring[2])
                        } else if line.hasPrefix("attributes") {
                            let attributes = String(line.components(separatedBy: " ")[2])
                            let property = ObjcProperty(name: propertyName, type: "", attributes: attributes)
                            catInstanceProperties.append(property)
                            //
                            propertyName = ""
                        }
                    default:
                        return
                    }
                } else if indent == 3 {
                    switch catStep {
                    case .protocols:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let protoName = String(substring[2]).swiftProtocolName
                            catProtocols.append(protoName)
                        }
                    default:
                        return
                    }
                }
            case .protolist:
                if indent == 0 {
                    if line.hasPrefix("00") {
                        if !protoName.isEmpty {
                            let proto = ObjcProtocol(name: protoName, protocols: protoProtocols, instanceMethods: protoInstanceMethods, classMethods: protoClassMethods, optionalInstanceMethods: protoOptionalInstanceMethods, optionalClassMethods: protoOptionalClassMethods, instanceProperties: protoInstanceProperties)
                            //
                            protolist.append(proto)
                            //
                            protoName = ""
                            protoProtocols.removeAll()
                            protoInstanceMethods.removeAll()
                            protoClassMethods.removeAll()
                            protoOptionalInstanceMethods.removeAll()
                            protoOptionalClassMethods.removeAll()
                            protoInstanceProperties.removeAll()
                        }

                        return
                    }
                } else if indent == 1 {
                    if line.hasPrefix("name") {
                        let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                        if substring.count > 2 {
                            protoName = String(substring[2]).swiftProtocolName
                        } else {
                            log(line)
                            assertionFailure()
                        }
                        return
                    } else if line.hasPrefix("protocols") {
                        protoStep = .protocols
                        return
                    } else if line.hasPrefix("instanceMethods") {
                        protoStep = .instanceMethods
                        return
                    } else if line.hasPrefix("classMethods") {
                        protoStep = .classMethods
                        return
                    } else if line.hasPrefix("optionalInstanceMethods") {
                        protoStep = .optionalInstanceMethods
                        return
                    } else if line.hasPrefix("optionalClassMethods") {
                        protoStep = .optionalClassMethods
                        return
                    } else if line.hasPrefix("instanceProperties") {
                        protoStep = .instanceProperties
                        return
                    }
                } else if indent == 2 {
                    switch protoStep {
                    case .instanceMethods:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let methodname = String(substring[2])
                            protoInstanceMethods.append(methodname)
                        }
                    case .classMethods:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let methodname = String(substring[2])
                            protoClassMethods.append(methodname)
                        }
                    case .optionalInstanceMethods:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let methodname = String(substring[2])
                            protoOptionalInstanceMethods.append(methodname)
                        }
                    case .optionalClassMethods:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let methodname = String(substring[2])
                            protoOptionalClassMethods.append(methodname)
                        }
                    case .instanceProperties:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            propertyName = String(substring[2])
                        } else if line.hasPrefix("attributes") {
                            let attributes = String(line.components(separatedBy: " ")[2])
                            let property = ObjcProperty(name: propertyName, type: "", attributes: attributes)
                            protoInstanceProperties.append(property)
                            //
                            propertyName = ""
                        }
                    default:
                        break
                    }
                } else if indent == 3 {
                    switch protoStep {
                    case .protocols:
                        if line.hasPrefix("name") {
                            let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                            let protoName = String(substring[2]).swiftProtocolName
                            protoProtocols.append(protoName)
                        }
                    default:
                        break
                    }
                }
            case .selrefs:
                //
                let substring = line.split(separator: " ", omittingEmptySubsequences: true)
                let methodname = String(substring[1])
                selrefs.insert(methodname)
            case .classrefs:
                // 类名
                if let range = line.range(of: "_OBJC_CLASS_$_") {
                    let startIndex = range.upperBound
                    let classref = line[startIndex ..< line.endIndex]
                    classrefs.insert(String(classref).swiftClassNameDemangled)
                } else { // 类地址
                    let address = String(line.components(separatedBy: " ")[1])
                    waitingClassAddress.insert(address)
                }
            case .superrefs:
                // 不处理superrefs,部分类没有被继承也会被添加
                break
            case .none:
                break
            }
        }
        //
        if !className.isEmpty {
            //
            let objcclass = ObjcClass(name: className, superclassName: superClassName, instanceMethods: Array(instanceMethods), classMethods: Array(classMethods), ivars: classIvars, instanceProperties: instanceProperties, classProperties: classProperties, protocols: Array(classProtocols), swiftClass: swiftClass)
            //
            classlist[objcclass.name] = objcclass
        }
        if !protoName.isEmpty {
            let proto = ObjcProtocol(name: protoName, protocols: protoProtocols, instanceMethods: protoInstanceMethods, classMethods: protoClassMethods, optionalInstanceMethods: protoOptionalInstanceMethods, optionalClassMethods: protoOptionalClassMethods, instanceProperties: protoInstanceProperties)
            //
            protolist.append(proto)
        }
        //
        if !catName.isEmpty {
            let cat = ObjcCategory(name: catName, cls: catClass, instanceMethods: Array(catInstanceMethods), classMethods: Array(catClassMethods), protocols: catProtocols, instanceProperties: catInstanceProperties)
            //
            catlist.append(cat)
        }
        //
        for address in waitingClassAddress {
            if let className = classAddressNameMap[address] {
                classrefs.insert(className)
            } else {
                log(address)
            }
        }
        for (className, superClassAddress) in waitingSuperAddress2 {
            if let superClassName = classAddressNameMap[superClassAddress] {
                classlist[className]!.superClassName = superClassName
                //
                superrefs.insert(superClassName)
            } else {
                log("\(className)-\(superClassAddress)")
            }
        }
        //
        let classlist2 = Array(classlist.values)
        let macho = MachoObjCData(classlist: classlist2, catlist: Array(catlist), protolist: protolist, classrefs: classrefs, superrefs: superrefs, selrefs: selrefs, ivarTypeRefs: ivarTypeRefs)
        return macho
    }

    #warning("getSectionText需要支持动态库和IPA 模式")
    private static func getSectionText(path: String, arch: ArchType, swiftClassRefs: Bool, objcIvars: Bool) async -> MachoText {
        if !swiftClassRefs && !objcIvars {
            return MachoText(classRefs: [], objcIvarRefs: [], symbols: [:], usedSymbols: [])
        }

        //
        var classrefs: Set<String> = []
        var ivarRefs: Set<ObjCIvarRef> = []
        var symbols: [String: Symbol] = [:]
        var usedSymbols: Set<String> = []
        let sectionText = getSectionTextInfo(path: path, arch: arch)
        //
        var isDealloc = false
        var objcInstanceMethod: String?
        var symbolCount = 0
        var symbolName: String?
        
        func insertSymbol(line: String?) {
            if let symbolName2 = symbolName {
                //
                if symbolCount > 0 {
                    let size = symbolCount * 32 / 8
                    let symbol = Symbol(name: symbolName2, size: size)
                    symbols[symbolName2] = symbol
                    //
                    symbolCount = 0
                }
            }
            //
            if let line = line {
                let endIndex = line.index(line.endIndex, offsetBy: -1)
                symbolName = String(line[line.startIndex..<endIndex])
            } else {
                symbolName = nil
            }
        }
        
        sectionText.lines { line in
            //
            if line.hasPrefix("00") {
                symbolCount += 1
                
                // 添加 classrefs
                if swiftClassRefs, line.count > 25 {
                    #warning("支持b跳转")
                    let callCommandKey = arch == .arm64 ? "bl\t" : "callq\t"
                    let callCommandStartIndex = line.index(line.startIndex, offsetBy: 17)
                    let callCommandEndIndex = line.index(callCommandStartIndex, offsetBy: callCommandKey.count)
                    let callCommand = line[callCommandStartIndex ..< callCommandEndIndex]
                    if callCommand == callCommandKey {
                        let usedsymbol = String(line[callCommandEndIndex ..< line.endIndex])
                        if usedsymbol.hasPrefix("_$") {
                            //
                            let classNames = usedsymbol.swiftClassNamesDemangled
                            for className in classNames {
                                classrefs.insert(className)
                            }
                        }
                        //
                        usedSymbols.insert(usedsymbol)
                    }
                }
                // 解析ivarRefs
                if objcIvars, line.count > 45, !isDealloc { // 添加 ivar
                    let callCommandKey = arch == .arm64 ? "adrp\t" : "movq\t"
                    let callCommandStartIndex = line.index(line.startIndex, offsetBy: 17)
                    let callCommandEndIndex = line.index(callCommandStartIndex, offsetBy: callCommandKey.count)
                    let callCommand = line[callCommandStartIndex ..< callCommandEndIndex]
                    if callCommand == callCommandKey {
                        let searchObjcIvarEndIndex = line.index(callCommandStartIndex, offsetBy: 20)
                        let searchObjcIvarRange = callCommandStartIndex ..< searchObjcIvarEndIndex
                        if let objcIvarRange = line.range(of: "_OBJC_IVAR", range: searchObjcIvarRange) {
                            let objcIvarStartIndex = line.index(objcIvarRange.upperBound, offsetBy: 3)
                            let searchSeparateRange = objcIvarStartIndex ..< line.endIndex
                            if let separateRange = line.range(of: "._", range: searchSeparateRange) {
                                let className = String(line[objcIvarStartIndex ..< separateRange.lowerBound])
                                var ivarEndIndex = line.endIndex
                                if arch == .arm64 {
                                    if line.hasSuffix("@GOTPAGE") {
                                        ivarEndIndex = line.index(ivarEndIndex, offsetBy: -8)
                                    } else if line.hasSuffix("@PAGE") {
                                        ivarEndIndex = line.index(ivarEndIndex, offsetBy: -5)
                                    }
                                } else {
                                    let searchObjcIvarEndIndex2 = line.index(line.endIndex, offsetBy: -15)
                                    let searchObjcIvarRange2 = searchObjcIvarEndIndex2 ..< line.endIndex
                                    if let objcIvarRange2 = line.range(of: "(%", range: searchObjcIvarRange2) {
                                        ivarEndIndex = objcIvarRange2.lowerBound
                                    }
                                }
                                let ivar = String(line[separateRange.upperBound ..< ivarEndIndex])
                                // 过滤 setter/getter 方法里的调用
                                let setterMethod = " \(mapSetterMethod(name: ivar))]:"
                                let getterMethod = " \(ivar)]:"
                                if let objcInstanceMethod = objcInstanceMethod, !objcInstanceMethod.hasSuffix(setterMethod) && !objcInstanceMethod.hasSuffix(getterMethod) {
                                    let ivarRef = ObjCIvarRef(class: className, name: ivar)
                                    ivarRefs.insert(ivarRef)
                                }                        }
                        }
                    }
                }
            } else if line.hasSuffix(":") {
                insertSymbol(line: line)
                
                if line.hasPrefix("-[") {
                    objcInstanceMethod = line
                    //
                    isDealloc = line.hasSuffix("dealloc]:") || line.hasSuffix(".cxx_destruct]:")
                }
            }
        }

        //
        insertSymbol(line: nil)
        //
        return MachoText(classRefs: classrefs, objcIvarRefs: ivarRefs, symbols: symbols, usedSymbols: usedSymbols)
    }

    private static func getSectionTextInfo(path: String, arch: ArchType) -> String {
        let output = Command.shell(in: APPAnalyze.shared.config.currentDirectoryPath, launchPath: APPAnalyze.shared.config.otoolPath, arguments: ["-x", "-V", "-arch", arch.rawValue, path], encoding: .isoLatin1)
        return output
    }

    private static func parseProtoCls(line: String) -> (String, String)? {
        guard let last = line.components(separatedBy: " ").last else {
            assertionFailure()
            return nil
        }

        //
        guard let startRange = last.range(of: "_OBJC_$_CATEGORY_") ?? last.range(of: "_CATEGORY_"), let endRange = last.range(of: "_$_", options: [.backwards], range: nil, locale: nil) else {
            return nil
        }

        let catClass = String(last[startRange.upperBound ..< endRange.lowerBound]).swiftClassNameDemangled
        let catName = String(last[endRange.upperBound ..< last.endIndex])
        return (catClass, catName)
    }
    
    static func mapSetterMethod(name: String) -> String {
        let firstChar = name[name.startIndex ... name.startIndex]
        let startIndex = name.index(name.startIndex, offsetBy: 1)
        let name = name[startIndex ..< name.endIndex]
        return "set\(firstChar.capitalized)\(name):"
    }
    
}

struct MachoObjCData {
    let classlist: [ObjcClass]
    let catlist: [ObjcCategory]
    let protolist: [ObjcProtocol]
    let classrefs: Set<String>
    let superrefs: Set<String>
    let selrefs: Set<String>
    let ivarTypeRefs: Set<String>
}

public struct Symbol {
    let name: String
    let size: Int
}

struct MachoText {
    let classRefs: Set<String>
    let objcIvarRefs: Set<ObjCIvarRef>
    let symbols: [String: Symbol]
    let usedSymbols: Set<String>
}

public struct LibraryFileSize: Encodable {
    let name: String
    let size: Int
}

public struct LibrarySize {
    public let totalSize: Int
    public let files: [LibraryFileSize]
}
