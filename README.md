# 介绍
分享一款用于分析`iOS`ipa包的脚本工具，使用此工具可以`自动扫描发现`可修复的包体积问题，同时可以生成包体积数据用于查看。这块工具我们团队内部已经使用很长一段时间，希望可以帮助到更多的开发同学更加效率的优化包体积问题。

 [工具下载地址](https://github.com/helele90/APPAnalyze/releases)

## 背景
`APPAnalyze`工具最早诞生主要是为了解决以下包体积管理的问题：

对于定位下沉市场的`APP`来讲，包体积是一个非常重要的性能指标，包体积过大会影响用户下载`APP`的意愿。但是在早期我们缺少一些手段帮助我们更高效的去进行包体积管理。
#### 自动发现问题
- `提升效率` - 人工排查问题效率低，对于常见的问题尽可能自动扫描出来。并且对于`组件化`工程来讲，很多外部组件是通过`Framework`方式提供，没有仓库源码权限用于分析包体积问题。
- `流程化` - 形成自动化的质量流程，添加到`CI流水线`自动发现包体积问题。

#### 数据指标量化
- `包体积问题` - 提供数据化平台查看每个组件的包体积`待修复`问题
- `包体积大小` - 提供数据化平台查看每个组件的包体积占比，包括`总大小`，单个文件`二进制大小`和每个`资源大小`。可以针对不同的`APP`版本进行组件化粒度的包体积数据对比，更方便查看每个版本的组件大小增量。


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
$ /Users/Test/APPAnalyzeCommand --help
OPTIONS:
  --version <version>     当前版本 1.2.0
  --output <output>       输出文件目录。必传参数
  --config <config>       配置JSON文件地址。非必传参数
  --ipa <ipa>             ipa.app文件地址。必传参数
  -h, --help              Show help information.
```
### 执行
打开终端程序直接执行以下`shell`指令，即可生成`ipa`的包体积数据以及包体积待修复问题。
> 提示：不能直接使用`AppStore`的包，`AppStore`的包需要砸壳。建议尽量使用XCode`Debug`的包。
``` shell
/Users/Test/APPAnalyzeCommand --ipa ipas/JDAPP/JDAPP.app --output ipas/JDAPP
```
> 提示：如果提示`permission denied`没有权限，执行`sudo chmod -R 777 /Users/a/Desktop/ipas/APPAnalyzeCommand`即可。双击`APPAnalyzeCommand`是否可以直接唤起终端程序。
### 生成产物
![截屏2023-09-02 16.15.12.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fa71a13c996747089246d7c871cd6130~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=980&h=304&s=55650&e=png&a=1&b=fefefe)
指令执行完成以后，会在`ouput`参数指定的文件夹生成`APPAnalyze`文件夹。具体文件介绍如下：
#### 包体积信息
##### app_size.html
展示`ipa`每个`framework`的包体积数据，可直接用浏览器打开。
> 提示：按照主程序和动态库进行粒度划分

![截屏2023-09-02 16.48.41.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/36db089d179345a8b39e6996b8903e0a~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=1588&h=862&s=129280&e=png&b=fdfdfd)

##### framework_size.html
展示单个`framework`所有的包体积数据，`二级页面不要直接打开`。

![截屏2023-09-02 16.48.52.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/7faf9663980d4b1f95f982ca16082fce~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=3176&h=1640&s=411654&e=png&b=fdfdfd)
包体积数据有几个点需要注意：
- `PackedAssetImage` - `XCode`生成`Assets.car`时会将一些小图片拼接成一张`PackedAssetImage`的大图片。
- `imageset` - `imageset`的大小不一定等于原始图片的大小，这个大小是`XCode`编译时生成`Assets.car` 里这个 imageset 所占的体积。

##### package_size.json
`ipa`包体积 JSON 数据

#### 包体积待修复问题
##### app_issues.html
展示`ipa`每个`framework`的包体积待修复问题数量，可直接用浏览器打开。
> 提示：按照主程序和动态库进行粒度划分
![截屏2023-09-02 16.48.23.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9040c099b3fc43b5b3772c28b2cde32d~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=1632&h=526&s=94734&e=png&b=fcfcfc)

##### framework_issues.html
展示单个`framework`所有的待修复问题详细数据，`二级页面不要单独打开`。


![截屏2023-09-02 16.48.34.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/fefa328328674920832f7f7080254ac1~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=3582&h=1522&s=633102&e=png&b=fdfdfd)
##### issues.json
`ipa`待修复包体积问题 JSON 数据



> 提示：`json`数据可用于搭建自己的数据平台，扩展更多的能力。例如查看不同APP版本以及支持多个APP版本对比等。


## 规则介绍
[规则介绍](https://github.com/helele90/APPAnalyze/blob/main/Rule.md)

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
/Users/Test/APPAnalyzeCommand -ipa /Users/Desktop/ipas/APPMobile/APPMobile.app -config /Users/Desktop/ipas/config.json --output /Users/Desktop/ipas/APPMobile
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
可以通过`modules`配置支持组件化工程的扫描，可以基于自身项目的组件化工程生成对应的`json`组件化配置，之后进行扫描
## 模块化扫描配置
``` shell
/Users/Test/APPAnalyzeCommand -ipa /Users/Desktop/ipas/APPMobile/APPMobile.app --modules /Users/Desktop/ipas/modules.json --output /Users/Desktop/ipas/APPMobile
```

配置格式如下：
``` json
[{
	"frameworks": [], // framework文件路径
	"libraries": [], // library文件路径
	"resources": [], // 资源文件路径
	"name": "APPModule", // 模块名
	"dependencies": ["OrderModule", "CartModule"], // 模块子模块依赖
	"version": "1.1.0" // 模块版本
}, {
	"frameworks": ["/Users/test/AppModule/Example/Pods/OrderModule/OrderModule.framework"],
	"libraries": [],
	"resources": ["/Users/test/AppModule/Example/Pods/CartModule/Resources/Order.bundle"],
	"name": "OrderModule",
	"dependencies": ["JDUIKit"],
	"version": "1.0.4"
}, {
	"frameworks": [],
	"libraries": ["/Users/test/AppModule/Example/Pods/CartModule/CartModule.a"],
	"resources": ["/Users/test/AppModule/Example/Pods/CartModule/Resources/Cart.xcassets"],
	"name": "CartModule",
	"dependencies": ["JDUIKit"],
	"version": "1.0.5"
}, {
	"frameworks": ["/Users/test/AppModule/Example/Pods/JDUIKit/JDUIKit.framework"],
	"libraries": [],
	"resources": ["/Users/test/AppModule/Example/Pods/JDUIKit/Resources"],
	"name": "JDUIKit",
	"dependencies": [],
	"version": "1.0.0"
}]
```
基于组件化扫描方式有以下优势：
- `细化数据粒度` - 可以细化每个模块的包体积和包体积问题，更容易进行包体积优化。 
- `更多的检查` - 例如检查不同组件同一个`Bundle`包含同名的文件，不同组件包含同一个`category`方法的的实现。
- `检查结果更准确` - 例如`ObjC`未使用方法的检查，只要存在一个和方法名同样的调用就表示方法有被使用到。但是整个`ipa`中可能存在很多一样的方法名但是只有一个方法有真正被调用到，如果细分到组件的粒度就可以发现更多问题。
> 提示：只有APP主工程无代码，全部通过子组件以`framework`的形式导入二进制库的方式的工程才适合这种模式。
# 其他

## 扫描质量如何
这套工具我们团队内部开发加逐步完善有一年的时间了。基于此工具修改了几十个组件的包体积问题，同时不断的修复误报问题。目前现有提供的这些规则检查误报率是很低的，只有极少数几个规则可能存在误报的可能性，总体扫描质量还是很高的。

## 和社区开源的工具有什么差异
我们在早期调研了社区的几个同类型的开源工具，主要存在以下几个问题：
- `扩展性不够` - 无法支持项目更好的扩展定制能力，例如添加扫描规则。
- `功能不全` - 只提供部分能力，例如只提供`未使用资源`或者`未使用类`。
- `无法生成包体积数据` - 无法生成包体积完整的数据。
- `检查质量不高` - 扫描发现的错误数据多，或者有一些问题不能被发现。

## 开源计划
后续一定会开源。目前正在公司内开源中，顺便收集一些反馈和建议，然后申请公司对外开源流程。
### 开源带来的好处
开源带来的好处是，部分工程可以基于自身的业务需要，扩展定制自己的扫描工具。同时也可以将一些更好的想法实现添加进来。
- `扩展解析方式` - 目前只支持`ipa`模式扫描，很快会开放支持`project`组件化工程的扫描方式。基于`组件化工程`的扫描可以更加准确，但是不同的公司`组件化工程`的构建方式可能是不一样的，有需要可以在上层定制自身`组件化工程`的扫描解析。
- `扩展扫描规则` - 虽然现在已经添加了比较多的通用性的规则，同时提供了一定的灵活性配置能力。但是不同的项目可能需要定制一些其他的规则，这些规则没办法通过在现有规则上添加配置能力实现。
- `扩展数据生成` - 默认包里只包含两种数据生成，`包体积`数据还有`包体积待修复问题`数据。可以扩展更多的数据生成格式，例如我们自身的项目就有添加基于组件的依赖树格式。

## 后续规划

### 组件化工程扫描
添加一些组件化扫描相关的规则。

###  对于 Swift 更好的支持
对于`Swift`语言只要开启`XCode`编译优化以后就能在生成产物的时候支持无用代码的移除，包括`未使用类型`和`未使用方法`的自动移除，但是依然有部分场景不会进行优化。所以这一块也是后续完善的重点：
- `未使用属性` - 编译器不会对于未使用`属性`进行移除，包括`class`和`struct`的属性。
- `未使用方法` - 对于`class`的方法，编译器并不会进行移除，即使没有申明`@objc`进行消息派发。

# 相关链接
- [京东京喜 iOS 包体积分析工具](https://juejin.cn/spost/7273740834201600063)

# 反馈交流群

![11701136673_.pic.jpg](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/ac06e69903e54afc9a25206469c36cb2~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=930&h=1482&s=188171&e=jpg&b=fefefe)
