# 介绍
一款用于分析`iOS`组件化工程的脚本工具，可支持`iBiu`和`MTool`组件化工程。使用此工具可以`自动扫描发现`可修复的包体积问题，生成包体积数据用于查看。这块工具我们团队内部已经使用很长一段时间，希望可以帮助到更多的开发同学更加效率的优化包体积问题。

 [工具Coding仓库](http://xingyun.jd.com/codingRoot/jingxiapp/APPAnalyze/)
 > 提示：基于`IPA`进行扫描可参考https://github.com/helele90/APPAnalyze

## 背景
`JDAPPAnalyze`工具最早诞生主要是为了解决以下包体积管理的问题：

对于定位下沉市场的`APP`来讲，包体积是一个非常重要的性能指标，包体积过大会影响用户下载`APP`的意愿。但是在早期我们缺少一些手段帮助我们更高效的去进行包体积管理。
#### 自动发现问题
- `提升效率` - 人工排查问题效率低，对于常见的问题尽可能自动扫描出来。并且对于`组件化`工程来讲，很多外部组件是通过`Framework`方式提供，没有仓库源码权限用于分析包体积问题。
- `流程化` - 形成自动化的质量流程，添加到`CI流水线`自动发现包体积问题。

#### 数据指标量化
- `包体积问题` - 提供数据化平台查看每个组件的包体积`待修复`问题
- `包体积大小` - 提供数据化平台查看每个组件的包体积占比，包括`总大小`，单个文件`二进制大小`和每个`资源大小`。可以针对不同的`APP`版本进行组件化粒度的包体积数据对比，更方便查看每个版本的组件大小增量。

### 模块化扫描配置
基于组件化扫描方式有以下优势：
- `细化数据粒度` - 可以细化每个模块的包体积和包体积问题，更容易进行包体积优化。 
- `更多的检查` - 例如检查不同组件同一个`Bundle`包含同名的文件，不同组件包含同一个`category`方法的的实现。
- `检查结果更准确` - 例如`ObjC`未使用方法的检查，只要存在一个和方法名同样的调用就表示方法有被使用到。但是整个`ipa`中可能存在很多一样的方法名但是只有一个方法有真正被调用到，如果细分到组件的粒度就可以发现更多问题。
> 提示：只有APP主工程无代码，全部通过子组件以`framework`的形式导入二进制库的方式的工程才适合这种模式。

# 实现方式
我们选择了不依赖源码而是直接扫描二进制库的方式来实现这个能力，总体的执行流程一下：
![执行流程.png](https://img20.360buyimg.com/img/jfs/t1/120446/27/39840/53545/64f692dbF1d10e35a/969226d5d77daae5.png)

# 使用指南

## 安装
无需安装。通过下载链接直接下载终端可执行命令文件`JDAPPAnalyzeCommand`到本地即可使用。

[JDAPPAnalyzeCommand 下载地址](http://xingyun.jd.com/codingRoot/jingxiapp/APPAnalyze/tree/master/Release)

## 使用
``` shell
$ JDAPPAnalyzeCommand --help
OPTIONS:
  --version <version>     当前版本 1.0.0
  --output <output>       输出文件目录。必传参数
  --config <config>       配置JSON文件地址。非必传参数
  --ipa <ipa>             ipa.app文件地址。必传参数
  -h, --help              Show help information.
```
### 执行
打开终端程序直接执行以下`shell`指令，即可生成`ipa`的包体积数据以及包体积待修复问题。
> 提示：不能直接使用`AppStore`的包，`AppStore`的包需要砸壳。建议尽量使用XCode`Debug`的包。
``` shell
/Users/hexiao/Desktop/ipas/1.0.0/JDAPPAnalyzeCommand --project /Users/hexiao/ibiu_project/JDLTAppModule --output /Users/hexiao/Desktop/ipas/JDLTAppModule
```
> 提示：如果提示`permission denied`没有权限，执行`sudo chmod -R 777 /Users/a/Desktop/ipas/APPAnalyzeCommand`即可。双击`JDAPPAnalyzeCommand`是否可以直接唤起终端程序。
### 生成产物
![截屏2023-09-02 16.15.12.png](https://img10.360buyimg.com/img/jfs/t1/222074/15/32619/15504/64f692b0Fa99b8e71/4cf805e87d181f58.png)
指令执行完成以后，会在`ouput`参数指定的文件夹生成`APPAnalyze`文件夹。具体文件介绍如下：
#### 包体积信息
##### app_size.html
展示每个`组件`的包体积数据，可直接用浏览器打开。
> 提示：按照主程序和动态库进行粒度划分

![app_size.html](https://img11.360buyimg.com/img/jfs/t1/122867/37/40361/33986/64f6932bF1f785adf/5c76d88f7694fa48.png)

##### module_size.html
展示单个`组件`所有的包体积数据，`二级页面不要直接打开`。

![module_size.html](https://img13.360buyimg.com/img/jfs/t1/189201/9/37490/105343/64f6932bF962b3ff7/c28b0a7bc3fc3420.png)
包体积数据有几个点需要注意：
- `PackedAssetImage` - `XCode`生成`Assets.car`时会将一些小图片拼接成一张`PackedAssetImage`的大图片。
- `imageset` - `imageset`的大小不一定等于原始图片的大小，这个大小是`XCode`编译时生成`Assets.car` 里这个 imageset 所占的体积。

##### package_size.json
`ipa`包体积 JSON 数据

#### 包体积待修复问题
##### app_issues.html
展示`ipa`每个`组件`的包体积待修复问题数量，可直接用浏览器打开。
> 提示：按照主程序和动态库进行粒度划分
![app_issues.png](https://img11.360buyimg.com/img/jfs/t1/101000/40/44455/24156/64f69332F01cf390b/5c88dd560225dab3.png)

##### module_issues.html
展示单个`组件`所有的待修复问题详细数据，`二级页面不要单独打开`。


![module_issues.png](https://img14.360buyimg.com/img/jfs/t1/200552/34/39521/189762/64f69336F2a551ff1/6c00f3a3a1366357.png)
##### issues.json
`ipa`待修复包体积问题 JSON 数据


> 提示：`json`数据可用于搭建自己的数据平台，扩展更多的能力。例如查看不同APP版本以及支持多个APP版本对比等。


## 规则介绍
[规则介绍](http://xingyun.jd.com/codingRoot/jingxiapp/APPAnalyze/blob/master/Rule.md)

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
/Users/hexiao/Desktop/ipas/1.0.0/JDAPPAnalyzeCommand --project /Users/hexiao/ibiu_project/JDLTAppModule --config /Users/hexiao/Desktop/ipas/config.json --output /Users/hexiao/Desktop/ipas/JDLTAppModule
```

可基于自身项目需要，添加下列规则可配置参数。在使用`JDAPPAnalyzeCommand`指令时添加`--config`配置文件地址。

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

# 其它

## 版本更新
- [版本更新说明](http://xingyun.jd.com/codingRoot/jingxiapp/APPAnalyze/blob/master/Release/README.md)

## 扫描质量如何
这套工具我们团队内部开发加逐步完善有一年的时间了。基于此工具修改了几十个组件的包体积问题，同时不断的修复误报问题。目前现有提供的这些规则检查误报率是很低的，只有极少数几个规则可能存在误报的可能性，总体扫描质量还是很高的。

## 和社区开源的工具有什么差异
我们在早期调研了社区的几个同类型的开源工具，主要存在以下几个问题：
- `扩展性不够` - 无法支持项目更好的扩展定制能力，例如添加扫描规则。
- `功能不全` - 只提供部分能力，例如只提供`未使用资源`或者`未使用类`。
- `无法生成包体积数据` - 无法生成包体积完整的数据。
- `检查质量不高` - 扫描发现的错误数据多，或者有一些问题不能被发现。

## 后续规划

### 组件化工程扫描
添加更多组件化工程扫描相关的规则。

### 对于 Swift 更好的支持
对于`Swift`语言只要开启`XCode`编译优化以后就能在生成产物的时候支持无用代码的移除，包括`未使用类型`和`未使用方法`的自动移除，但是依然有部分场景不会进行优化。后续希望可以完善以下两种检查：
- `未使用属性` - 编译器不会对于未使用`属性`进行移除，包括`class`和`struct`的属性。
- `未使用方法` - 对于`class`的方法，编译器并不会进行移除，即使没有申明`@objc`进行消息派发。

# 相关链接
- [iOS 包体积分析工具](https://juejin.cn/spost/7273740834201600063)
- [IPA 扫描](https://github.com/helele90/APPAnalyze)

# 开源共建
欢迎大家提供建议和问题反馈，同时源码已内部开源。可通过`ME群`或`神灯开源平台`进行反馈或加入开源计划。欢迎有兴趣的同学参与一起开发共建。
[神灯开源项目](http://jagile.jd.com/shendeng/openSource/detail/799)

`ME交流群`：10206115313