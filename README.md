# 介绍
分享一款用于分析`iOS`ipa包的脚本工具，使用此工具可以`自动扫描发现`可修复的包体积问题，同时可以生成包体积数据用于查看。这块工具我们团队内部已经使用很长一段时间，希望可以帮助到更多的开发同学更加效率的优化包体积问题。

 [工具下载地址](https://github.com/helele90/APPAnalyze)

# 实现方式
我们选择了不依赖源码而是直接扫描二进制库的方式来实现这个能力，总体的执行流程一下：
![执行流程.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/f9d9a974291e4d76a6b9d7d528ab1377~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=2818&h=1702&s=262212&e=png&b=ffffff)
> 提示：基于组件化工程的扫描方式内部支持，只是暂时不对外开放。

# 使用指南

## 安装
无需安装。通过下载链接直接下载终端可执行命令文件`APPAnalyzeCommand`到本地即可使用。

[APPAnalyzeCommand 下载地址](https://github.com/helele90/APPAnalyze/releases)

## 使用
``` shell
$ APPAnalyzeCommand --help
OPTIONS:
  --version <version>     当前版本 1.0.0
  --output <output>       输出文件目录。必传参数
  --config <config>       配置JSON文件地址。非必传参数
  --ipa <ipa>             ipa.app文件地址。必传参数
  -h, --help              Show help information.
```
### 执行
打开终端程序直接执行以下`shell`指令，即可生成`ipa`的包体积数据以及包体积待修复问题。
``` shell
APPAnalyzeCommand --ipa ipas/JDAPP/JDAPP.app --output ipas/JDAPP
```
> 提示：如果提示`permission denied`没有权限，执行`sudo chmod -R 777 /Users/a/Desktop/ipas/APPAnalyzeCommand`即可。
### 生成产物
![截屏2023-09-02 16.15.12.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fa71a13c996747089246d7c871cd6130~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=980&h=304&s=55650&e=png&a=1&b=fefefe)
指令执行完成以后，会在`ouput`参数指定的文件夹生成`APPAnalyze`文件夹。具体文件介绍如下：
#### 包体积信息
- `app_size.html` - 展示`ipa`每个`framework`的包体积数据，可直接用浏览器打开。
> 提示：按照主程序和动态库进行粒度划分

![截屏2023-09-02 16.48.41.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/36db089d179345a8b39e6996b8903e0a~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=1588&h=862&s=129280&e=png&b=fdfdfd)

- `framework_size.html` - 展示单个`framework`所有的包体积数据，`二级页面不要直接打开`。

![截屏2023-09-02 16.48.52.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7faf9663980d4b1f95f982ca16082fce~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=3176&h=1640&s=411654&e=png&b=fdfdfd)

- `package_size.json` - `ipa`包体积 JSON 数据

#### 包体积待修复问题
- `app_issues.html` - 展示`ipa`每个`framework`的包体积待修复问题数量，可直接用浏览器打开。
> 提示：按照主程序和动态库进行粒度划分
![截屏2023-09-02 16.48.23.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9040c099b3fc43b5b3772c28b2cde32d~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=1632&h=526&s=94734&e=png&b=fcfcfc)

- `framework_issues.html` - 展示单个`framework`所有的待修复问题详细数据，`二级页面不要单独打开`。


![截屏2023-09-02 16.48.34.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fefa328328674920832f7f7080254ac1~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=3582&h=1522&s=633102&e=png&b=fdfdfd)
- `issues.json` - `ipa`待修复包体积问题 JSON 数据



> 提示：`json`数据可用于搭建自己的数据平台，扩展更多的能力。例如查看不同APP版本以及支持多个APP版本对比等。


## 规则介绍

### 包体积

#### 未使用的类
定义了类没有被使用到，包含`ObjC`类和`Swift`类。
##### 扫描规则
- 没有查到到对应的`ObjC`类被引用
- 没有被当做父类使用
- 没有使用的字符串和类名一致
- 没有被当做属性类型使用
- 没有被创建或调用方法
- 没有实现`+load`方法
##### 可选的修复方式
- 移除未使用的类
- `Swift`类如果只是用了`static`方法考虑修改成`Enum`类型
- 如果只是在类型转换时使用了也会检测出是未使用的类，例如`(ABCClass *)object;`。建议检查是否真的有没有到相关类后删除
- 对于`ObjC`，如果只是作为方法参数类型使用也会被检测出是未使用的类。建议删除相关方法即可。

> 提示：删除类相对是一种安全的行为，因为删除后如果有被使用到会产生编译时错误。虽然有做字符串调用的扫描过滤，不过还是建议检查是否可能被`Runtime`动态创建调用

#### 未使用的ObjC协议
定义了`ObjC`协议没有被类使用
##### 扫描规则
- 对应的协议没有被类引用
##### 可选的修复方式
- 移除未使用的协议

#### Bundle内多Scale图片
`Bundle`内同一张图片包含多个`Scale`会导致更大的包体积。
##### 扫描规则
- 同一个`Bundle`内存在同名但是`scale`不同的图片。例如`a@2x.png`/`a@3x.png`
##### 可选的修复方式
- 移除`Scale`更低的图片

#### 大资源
文件大小超过一定大小的即为大资源，默认为`20KB`。
##### 扫描规则
- 某个文件超过设置的大资源限额
##### 可选的修复方式
- 移除资源动态下发
- 使用更小的数据格式，例如使用更小的图片格式

#### 重复的资源文件
存在多个同样的重复文件。
#### 扫描规则
- 多个文件`MD5`一致即判定为重复文件。
##### 可选的修复方式
- 移除多余的文件

#### 未使用的类Property属性
`ObjC`类中定义的属性没有被使用到。
##### 扫描规则
- 对应的属性没有被调用 set/get 方法，同时也没有被`_`的方式使用。
- 不是来自实现协议的属性
- 不是来自`Category`的属性
##### 可选的修复方式
- 移除对应的属性。
- 如果是接口协议的属性，需要添加类实现此接口

> 提示：可能存在一定的误报，需要检查。

#### 未使用的ImageSet/DataSet
包含的`Imageset`/`DataSet`并没有被使用到。
##### 扫描规则
- 未检测到和`Imageset`同样名字的字符串使用
##### 可选的修复方式
- 移除ImageSet/DataSet

> 提示：可能会存在一定误报，需要检查。例如1.某些使用的 Swift 字符串不能被发现所以会被当做未使用。2.使用字符串拼接的字符串作为 imageset的名字。

#### 未使用的ObjC方法
定义的`ObjC`Category 方法并未被使用到。
##### 扫描规则
- 不存在和此方法一样的方法名使用
- 不存在使用的`字符串`和方法名一致
- 不是来自父类或`Category`的方法
- 不是来自实现接口的方法
- 不是属性 set/get 方法
##### 可选的修复方式
- 移除对应方法

#### 未使用的分类方法
定义的`ObjC`Category 方法并未被使用到。
##### 扫描规则
- 不存在和此方法一样的方法名使用
- 不存在和方法名一致的`字符串`使用
- 不是来自父类或`Category`的方法
- 不是来自实现接口的方法
##### 可选的修复方式
- 移除未使用的方法

#### 未使用的资源文件
包含的文件资源并没有被使用到。这里的资源不包含`Imageset`/`DataSet`。
##### 扫描规则
- 未检测到和文件名同样名字的字符串使用
##### 可选的修复方式
- 移除资源
> 提示：可能会存在一定误报，例如1.某些使用的 Swift 字符串不能被发现所以会被当做未使用。2.使用字符串拼接的字符串作为 imageset的名字。

### 安全
#### 动态反射调用ObjC类
存在类名和字符串一致，可能使用`NSClassFromString()`方法动态调用类。当`字符串`或类名变更时无法利用编译时检查发现问题，可能会导致功能异常。
##### 扫描规则
- 存在使用的`字符串`和`NSObject子类`类名相同
##### 可选的修复方式
- 使用`NSStringFromClass()`获取类名字符串
- 使用`Framework`外部的类应该使用方法封装
> 提示：包含继承`NSObject`的 swift 类。

#### ObjC属性内存申明错误
一些特殊的`NSObject`类型的属性内存类型申明错误，可能会导致功能异常或触发`Crash`。
##### 扫描规则
- `NSArray`/`NSSet`/`NSDictionary`类型的属性使用`strong`申明
- `NSMutableArray`/`NSMutableSet`/`NSMutableDictionary`类型的属性使用`copy`申明
##### 可选的修复方式
- 修改`strong`/`copy`申明

#### 冲突的分类方法
`ObjC`同一个类的多个`Category`分类中存在多个相同的方法，由于运行时最终会加载方法可能是不确定的，可能会导致功能异常等未知的行为。
##### 扫描规则
- `NSObject类`的多个`Category`分类中存在多个相同的方法
##### 修复方式
- 移除多余的分类方法

#### 重复的分类方法
`ObjC`原始类和类的`Category`分类中有相同的方法，分类中的方法会覆盖原始类的方法，可能会导致功能异常等未知的行为。
##### 扫描规则
- `NSObject`原始类和类的`Category`分类中有相同的方法
##### 修复方式
- 移除重复的分类方法

#### 未实现的ObjC协议方法
类实现了某个`ObjC`协议，但是没有实现协议的`非可选`方法。可能会导致功能异常或触发`Crash`。
##### 扫描规则
- `类`和`分类`未实现`NSObject`协议的`非可选`方法
##### 可选的修复方式
- 对应的类实现缺失的`非可选`协议方法
- 将对应的协议方法标识为`optional`可选方法

#### 重复的ObjC类
多个`动态库`和`静态库`之间存在同样的`类`。不会导致编译失败，但是运行时只会使用其中一个类，可能会导致功能异常或触发`Crash`。同时会增加`包体积`。
##### 扫描规则
- 多个`动态库`和`静态库`之间存在同样的`NSObject类`符号
##### 可能的修复方式
- 移除重复的类

### 性能
#### 使用动态库
使用动态库会增加`启动`耗时。
##### 扫描规则
- `Macho`为动态库
##### 可选的修复方式
- 使用`静态库`
- 使用`Mergeable Library`

#### 实现`+load`方法的类
APP`启动`后会执行所有`+load`方法，减少`+load`方法可以降低启动耗时。
##### 扫描规则
- 实现`+load`方法的`NSObject`类
##### 可选的修复方式
- 移除`+load`方法
- 使用`+initialize`替代

## 自定义配置

### 重要配置
#### systemFrameworkPaths
可以基于自身项目进行系统库目录的配置，解析工程时也会对系统库进行解析。配置系统库目录对于未使用方法的查找可以提供更多的信息避免误报。但是配置更多会导致执行的更慢，建议至少配置`Foundation`/`UIKit`。
#### unusedObjCProperty-enable
`unusedObjCProperty`规则默认不开启。
- 开启未使用属性检查以后，会扫描`macho`的`__TEXT`段，会增加分析的耗时。
#### unusedClass-swiftEnable
`unusedClass-swiftEnable`默认不开启。
- 开启`Swift`类检查以后，会扫描`macho`的`__TEXT`段，会增加分析的耗时。
- 未使用`Swift`类的项目建议不要开启，如果考虑执行性能的话`Swift`使用相对比较多的再开启。

> 提示：扫描`macho`的`__TEXT`段需要使用`XCode`Run编译出的包，不能直接使用用于上架`APP Store`构建出的包。主要是`Debug`会包含更多的信息用于扫描。

### 配置属性
``` shell
APPAnalyzeCommand -ipa /Users/Desktop/ipas/APPMobile/APPMobile.app -config /Users/Desktop/ipas/config.json --output /Users/Desktop/ipas/APPMobile
```

可基于自身项目需要，添加下列规则可配置参数。在使用`APPAnalyzeCommand`指令时添加`--config`配置文件地址。

``` json
{
    "systemFrameworkPaths": ["/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
        "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/Foundation.framework/Foundation"
    ], // 配置系统库。会极大增加未使用方法的误报
    "rules": {
        "dynamicCallObjCClass": { // 动态调`ObjC类
            "enable": false, // 是否启用
            "excludeClasslist": [ // 过滤类名
                "NSObject",
                "param"
            ]
        },
        "incorrectObjCPropertyDefine": { // 错误的 ObjC 属性定义
            "enable": false // 是否启动
        },
        "largeResource": { // 大资源
            "maxSize": 20480 // 配置大资源判定大小。默认 20480Byte=20KB
        },
        "unusedObjCProperty": { // 未使用的 ObjC 属性
          "enable": false, // 是否启用。默认不开启
          "excludeTypes": ["NSString", "NSArray", "NSDictionary", "NSNumber", "NSMutableArray", "NSMutableDictionary", "NSSet"] // 过滤掉部分类型的属性
        },
        "unusedClass": { // 未使用的类
            "swiftEnable": false, // 是否支持 Swift 类。默认不支持
            "excludeSuperClasslist": ["JDProtocolHandler", "JDProtocolScheme"],// 如果类继承了某些类就过滤
            "excludeProtocols": ["RCTBridgeModule"], // 如果类实现了某些协议就过滤
            "excludeClassRegex": ["^jd.*Module$", "^PodsDummy_", "^pg.*Module$", "^SF.*Module$"] // 过滤掉名字符合正则表达式的类
        },
        "unusedObjCMethod": { // 未使用的 ObjC 方法
            "excludeInstanceMethods": [""], // 过滤掉某些名字的对象方法
            "excludeClassMethods": [""], // 过滤掉某些名字的类方法
            "excludeInstanceMethodRegex": ["^jumpHandle_"], // 过滤掉名字符合正则表达式的对象方法
            "excludeClassMethodRegex": ["^routerHandle_"], // 过滤掉名字符合正则表达式的类方法
            "excludeProtocols": ["RCTBridgeModule"] // 如果类集成了某些协议就不再检查，例如 RN 方法
        },
        "loadObjCClass": { //  调用 ObjC + load 方法
            "excludeSuperClasslist": ["ProtocolHandler"], // 如果类继承了某些类就过滤
            "excludeProtocols": ["RCTBridgeModule"] // 如果类实现了某些协议就过滤，例如 RN 方法
        },
        "unusedImageset": { // 未使用 imageset
            "excludeNameRegex": [""] // 过滤掉名字符合正则表达式的imageset
        },
        "unusedResource": { // 未使用资源
            "excludeNameRegex": [""] // 过滤掉名字符合正则表达式的资源
        }
    }
}

```

# 其他

## 扫描质量如何
这套工具我们团队内部开发加逐步完善有一年的时间了。基于此工具修改了几十个组件的包体积问题，同时不断的修复误报问题。目前现有提供的这些规则检查误报率是很低的，只有极少数几个规则可能存在误报的可能性，总体扫描质量还是很高的。

## 和社区开源的工具有什么差异
我们在早期调研了社区的几个同类型的开源工具，主要存在以下几个问题：
- `扩展性不够` - 无法支持项目更好的扩展定制能力，例如添加扫描规则
- `功能不全` - 只提供部分能力，例如`未使用资源`/`未使用类`。
- `无法生成包体积数据` - 无法生成包体积完整的数据。
- `检查质量不高` - 扫描发现的错误数据多，或者有一些问题不能被发现。

## 开源计划
后续一定会开源。最近刚做完一定的代码重构，然后准备申请公司的开源流程。
### 开源带来的好处
开源带来的好处是，部分工程可以基于自身的业务需要，扩展定制自己的扫描工具。同时也可以将一些更好的想法实现添加进来。
- `扩展解析方式` - 目前只支持`ipa`模式扫描，很快会开放支持`project`组件化工程的扫描方式。基于`组件化工程`的扫描可以更加准确，但是不同的公司`组件化工程`的构建方式可能是不一样的，有需要可以在上层定制自身`组件化工程`的扫描解析。
- `扩展扫描规则` - 虽然现在已经添加了比较多的通用性的规则，同时提供了一定的灵活性配置能力。但是不同的项目可能需要定制一些其他的规则，这些规则没办法通过在现有规则上添加配置能力实现。
- `扩展数据生成` - 默认包里只包含两种数据生成，`包体积`数据还有`包体积待修复问题`数据。可以扩展更多的数据生成格式，例如我们自身的项目就有添加基于组件的依赖树格式。

## 后续规划

### 组件化工程扫描
近期打算优先支持基于组件化工程的扫描方式。计划提供一种通用的能力，可以通过配置包含所有组件信息（二进制/资源/依赖关系）的这样一个`json`文件来配置组件工程。 不过开源后也可以基于自身的需要来定制解析方式。

基于组件化扫描方式有以下优势：
- `细化数据粒度` - 可以细化每个模块的包体积和包体积问题，更容易进行包体积优化。 
- `更多的检查` - 例如检查不同组件同一个`Bundle`包含同名的文件，不同组件包含同一个`category`方法的的实现。
- `检查结果更准确` - 例如`ObjC`未使用方法的检查，只要存在一个和方法名同样的调用就表示方法有被使用到。但是整个`ipa`中可能存在很多一样的方法名但是只有一个方法有真正被调用到，如果细分到组件的粒度就可以发现更多问题。
> 提示：只有APP主工程无代码，全部通过子组件以`framework`的形式导入二进制库的方式的工程才适合这种模式。

###  对于 Swift 更好的支持
对于`Swift`语言只要开启`XCode`编译优化以后就能在生成产物的时候支持无用代码的移除，包括`未使用类型`和`未使用方法`的自动移除，但是依然有部分场景不会进行优化。所以这一块也是后续完善的重点：
- `未使用类` - 编译器不会对于未使用`class`进行移除，即使是继承`NSObject`的子类。
- `未使用属性` - 编译器不会对于未使用`属性`进行移除，包括`class`和`struct`的属性。
- `未使用方法` - 对于`class`的方法，编译器并不会进行移除，即使没有申明`@objc`进行消息派发。
