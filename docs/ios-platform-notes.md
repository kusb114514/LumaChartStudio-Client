# iOS 平台笔记

> 状态：2026-08-16。原题是「黑屏」，实际是**三个独立缺陷叠加**，其中两个共用同一个根因。
> 三个都已定位并修复，下面的结论都有真机证据，**不要重新验证**。
> 待办见文末「未完成」。

| # | 缺陷 | 症状 | 状态 |
|---|---|---|---|
| 1 | iOS 26 拦截非主线程修改 layer 属性 | 黑屏，无异常无日志 | 已修复，受控 A/B 验证 |
| 2 | runtimeconfig 开关被 ILLink 覆盖 | 每帧异常被吞 / 写不出任何文件 / 启动即 FailFast | 已修复，`IsDynamicCodeSupported` 与 `UseSystemResourceKeys` 已验证翻转 |
| 3 | 诊断代码自身触发 FailFast | Avalonia 初始化中途进程消失 | 已修复 |
| 4 | 选择器返回的安全作用域路径不持久 | 选完文件几秒后「已不存在」 | 已修复，待真机复验 |
| 5 | 软键盘盖住模态对话框 | 验证码与确认按钮看不见 | 已修复，待真机复验 |

## 真机已验证（iPad16,3 / iPadOS 26.6，2026-08-16）

| 项 | 证据 |
|---|---|
| 渲染 | 截图：登录浮层、曲库背景页、中文字体、验证码位图全部正常 |
| 文件写入 | `Documents/launch-log.txt` 存在并可经 AFC 取回 |
| 谱面创建与保存 | `Documents/Library/New Chart_.../1786873717.mc`，JSON 结构完整 |
| 反射式 System.Text.Json | 同上——那个 `.mc` 就是它序列化出来的 |
| 设置持久化 | `Library/Application Support/settings/editor-view-settings.json` |
| 编辑状态恢复 | 重启后标签栏恢复出上次的谱面页签 |
| Avalonia 运行期 | 日志桥（Warning+）全程零条 |

**未验证，需要人手点屏**：音频播放、导入、导出、编辑操作。
pymobiledevice3 没有注入触摸的通道，`developer accessibility list-items` 在
Avalonia 视图上枚举超时（Avalonia.iOS 不发布可驱动的无障碍树），
WebDriverAgent 需要自己的 bundle id，而手上的描述文件不是通配的。

---

## 问题 1（已修复）：iOS 26 拦截非主线程修改 layer 属性

iPadOS 26 把「非主线程修改 view 的 layer 属性」从警告升级为拦截。
Avalonia.iOS 的渲染循环跑在 `DisplayLinkTimer` 自建的后台线程上，并在那里改渲染 layer：

- OpenGL：`EaglLayerSurface` → `LayerFbo.TryCreate` → `renderbufferStorage:fromDrawable:`
  （内部给 layer 设 `contents`）
- Metal：`MetalPlatformSurface` 的 `_layer.Device`、`MetalRenderTarget` 的 `_layer.DrawableSize`

**两个后端都中招，所以换后端无效。** 拦截对 GL 侧不可见——framebuffer 仍报 complete、
不抛异常——于是每帧都画到一个 `contents` 从未被附着的 layer 上。

真机 syslog（iPad16,3 / iPadOS 26.6 / build 23G71）：

```
LumaChart.iOS{UIKitCore} <ERROR>: Modifying properties of a view's layer off the
main thread is not allowed: view <Avalonia_iOS_AvaloniaView> ...
   2-5  QuartzCore      ← CAEAGLLayer 属性写入
   6    OpenGLES        ← renderbufferStorage:fromDrawable:
   22-24 QuartzCore     ← CADisplayLink 回调
   25-29 CoreFoundation ← NSRunLoop.Run()
```

### 修复

`src/iOS/Avalonia.iOS/DisplayLinkTimer.cs`（补丁见下节）：把 CADisplayLink 挂到
**主 runloop**，`TimerThread` 指向主线程，`RunsInBackground` 如实改为 `false`。
`EaglLayerSurface.CheckThread()` 是拿 `TimerThread` 比对而非假定工作线程，所以该检查依然满足。
`AVALONIA_IOS_RENDER_THREAD=worker` 可切回原行为。

**同时必须把 `CADisplayLink` 存为字段**。原代码靠线程闭包捕获它而恰好存活；
主线程分支没有强引用，托管包装被 GC 回收后回调静默停止——表现为
「NSTimer 正常、GPU 全零、无任何错误」。这个坑第一版踩过，别再踩。

### 受控验证（同一个包，只切环境变量）

| 模式 | UIKit layer 错误 | 浮层 |
|---|---|---|
| `AVALONIA_IOS_RENDER_THREAD=worker` | **1** | 不出现（主线程被饿死） |
| 主线程（默认） | **0** | 正常，`link=2613 loop=2613` 满速 |

---

## 问题 2（已修复）：runtimeconfig 的功能开关被 ILLink 的默认值覆盖

**本次调查最重要的一条。** 三个看起来毫无关系的故障是同一个原因。

`Microsoft.NET.ILLink.targets` 和 `Xamarin.Shared.Sdk.targets` 都用
`Condition="'$(X)' == ''"` 给同一批功能开关兜底，也就是「没人设过我才设」——
于是谁先求值谁赢，**这个包里赢的一直是 ILLink**。把出包的 `runtimeconfig.bin`
解出来逐条比对才看得见：

| 开关 | iOS SDK 想要 | 实际出包 | 后果 |
|---|---|---|---|
| `DynamicCodeSupport` | `false` | `true` | 见下 |
| `UseSystemResourceKeys` | `true`（release） | `false` | 见下 |
| `JsonSerializerIsReflectionEnabledByDefault` | 不表态 | `false` | 设置/工作区/Online 全部反序列化失败 |
| `VerifyDependencyInjectionOpenGenericServiceTrimmability` | `false`（release） | `true` | 启动期多余校验，失败时抛而非警告 |

第三条在此之前就被显式设成 `true` 了，当时的注释写的是「以防万一 SDK 默认值变化」——
那不是假设，ILLink 本来就把它设成 `false`，那一行一直是承重的。

### `DynamicCodeSupport=true` 的后果

.NET 8 起，`ConstructorInvoker`/`MethodInvoker` 会在
`RuntimeFeature.IsDynamicCodeCompiled` 为真时给每个调用点 emit 一个 `DynamicMethod`
桩（名字形如 `InvokeStub_<Type>..ctor(object,object,intptr*)`），为假时才走不 emit 的
慢路径。iOS 不能 JIT，于是**进程里每一处反射构造都是地雷**：

```
System.ExecutionEngineException: Attempting to JIT compile method
'(wrapper dynamic-method) object object:InvokeStub_SKPaint..ctor
(object,object,intptr*)' while running in aot-only mode
```

这一条在 Avalonia 渲染循环里，`DefaultRenderLoop.TimerTick` 会 catch 住并丢给
Avalonia 自己的 logger；默认没有任何 `ILogSink`，所以**完全静默**——进程活着、
不画东西、GPU 全零。

```
InvokeStub_SafeFileHandle..ctor
```

这一条让**沙盒里建得出目录、建不出任何文件**。谱面保存、设置持久化、编辑状态恢复、
会话令牌全都会失败；`launch-log.txt` 从 1.2.0.8 起一次都没落过盘，也是这个原因。

`System.Text.Json` 的反射解析器同样按这个开关选 `ReflectionEmitCachingMemberAccessor`，
所以它在真机上也早就是坏的，只是还没跑到。

### `UseSystemResourceKeys=false` 的后果

这个配置下资源字符串查找本身是坏的：查一条会抛 file-not-found，而那个异常的消息
又要查同一条资源，`System.Private.CoreLib` 的重入保护用**不可捕获的 FailFast** 回应：

```
Process terminated.
Encountered infinite recursion while looking up resource
'IO_FileName_Name' in System.Private.CoreLib.
```

**这条 abort 就是当初两次解释器实验的死因**——它们不是启动失败，是格式化不出失败原因。
当时把它归给「解释器配置值本身有问题」是错的。

### 修法

四个开关全部在 `LumaChart.iOS.csproj` 里显式写死。csproj 正文早于两个 targets 文件求值，
所以能同时压过两者。每条旁边都有注释说明为什么不能删。

代价：`UseSystemResourceKeys=true` 让异常消息变成资源键而不是英文句子，
凡是把 `Exception.Message` 显示给用户的地方都会变难看。这个取舍只能接受，
因为另一边不是「消息可读」，是「进程死掉」。类型名和调用栈不受影响。

### 后续

`Avalonia.Skia` 的 `SKCacheBase` 补丁（见下）是在只知道 `SKPaint` 那条症状时做的，
它消掉了一个反射调用点；`DynamicCodeSupport=false` 消掉的是所有反射调用点失败的原因。
**这个补丁多半已经不需要了**，但必须真机验证过才能撤。

---

## 问题 3（已修复）：诊断代码自己把进程打死

`IOSLaunchLog.WriteException` 里 `exception.ToString()` 在此之前**从来没有执行到过**——
`logPath` 一直是 null，函数在那之前就 return 了。问题 2 修好、文件能写之后，
它第一次真的去格式化异常消息，正好撞上上面那个 FailFast，
于是「修好 I/O」的直接表现是「Avalonia 初始化中途进程消失」。

底下那个被 Avalonia 吞掉的 `FileNotFoundException` 本身是良性的。

现在 `WriteException` 按风险递增顺序写并逐条 flush：类型名 → 调用栈 → 完整
`ToString()`。前两者不需要资源查找，所以即使最后一步再次 abort，日志里也已经点名了元凶。

**诊断代码不能有能力杀掉被诊断的进程。**

---

## 打补丁的 Avalonia：怎么构建、怎么接线

### 为什么必须在 Avalonia 仓库内构建

Avalonia 的平台接口带 `NotClientImplementable` 守卫——`ITopLevelImpl`、`IRenderTimer`、
`IDispatcherImpl`、`IMetalDevice`、`IPlatformRenderSurface` 都有一个只有 internals
权限才能实现的成员。**脱离仓库单独编译会有 103 个错误**，形如：

```
error CS0535: does not implement interface member
'ITopLevelImpl.(This interface or abstract class is -not- implementable by user code !)'
```

即使程序集命名为 `Avalonia.iOS`、并用仓库公开的 `build/avalonia.snk` 签名也不行——
发布的 Avalonia.Base 里没有对应的 `InternalsVisibleTo` 授权。**这条捷径已验证堵死。**

### 构建步骤

补丁本身在仓库里：`tools/avalonia/0001-ios26-display-link-on-main-thread.patch`。
构建机上跑一条命令即可（克隆、打补丁、收窄 TFM、构建、暂存产物，约 50 秒）：

```bash
. ~/lumachart-env.sh
bash "$LUMACHART_SRC/tools/avalonia/build-patched-avalonia-ios.sh"
```

脚本每次都先 `git checkout -- .` 重置到 12.1.1 标签再打补丁，所以可重复执行，也不会
积累历史遗留改动。克隆目录和暂存目录都在 `~/Developer/` 下，**必须在仓库外**——
`Sync-MacSource.ps1 -Delete` 会 `rm -rf` 远端仓库目录，连源码树带产物一起带走。

**这个补丁只有 `DisplayLinkTimer.cs` 一个文件。** 曾经还有一份 `Avalonia.Skia` 的
`SKCacheBase` 补丁，已证实多余（真正的原因是 `DynamicCodeSupport`），接线和暂存文件都已删除，
不要再加回来。脚本里的 TFM 收窄是构建机环境适配，不属于修复本身，提上游时不要带上。

### 接线（`LumaChart.iOS.csproj`）

用 `Exists()` 守卫决定是否替换包里的程序集，因此在没有该文件的机器上自动失效：

```xml
<LumaChartPatchedAvaloniaIOS>$(HOME)/Developer/avalonia-patched-out/Avalonia.iOS.dll</...>
<PackageReference Update="Avalonia.iOS" ExcludeAssets="compile;runtime" />
<Reference Include="Avalonia.iOS"><HintPath>$(LumaChartPatchedAvaloniaIOS)</HintPath></Reference>
```

构建时会打印 `LumaChart: using patched Avalonia.iOS from ...`，**每次出包都要确认这行在**。

源码树的 `SharedVersion.props` 打的是 `Version=12.1.1` 且用 `avalonia.snk` 签名，
与发布包标识完全一致，所以补丁 DLL 能直接顶替包里那份。

### Windows/Android 不受影响

`LumaChart.Avalonia.SharedSource.props` 里 Avalonia 版本**本来就按 iOS TFM 条件化**：

```xml
<LumaChartAvaloniaVersion>12.1.0</LumaChartAvaloniaVersion>
<LumaChartAvaloniaVersion Condition="'$(TargetFramework)' == 'net10.0-ios26.2'">12.1.1</LumaChartAvaloniaVersion>
```

---

## 真机回路（构建→签名→安装→启动→取日志，全自动）

构建机没有 Apple 账号/证书，出的是未签名 ipa；签名在 Windows 侧用 zsign 做，
证书材料只放在 scratchpad，**不进仓库、不上构建机**（构建机按项目约定是不持凭据的隔离环境）。

```bash
# 签名 + 安装（scratchpad/deploy.sh 把这两步串起来了）
zsign.exe -k <p12> -p <口令> -m <mobileprovision> -b <bundleid> -z 1 -o signed.ipa unsigned.ipa
"$PMD3" apps install signed.ipa
```

`.p12` 用 `cryptography.pkcs12` 在本地重新导出成 ASCII 口令再喂给 zsign——
原始口令标签文件是中文行，中文字节过 Windows argv 会被改写，直接用会
`PKCS12_parse: mac verify failure`。bundle id 必须与描述文件的 `application-identifier` 一致。

```bash
PY=<scratchpad>/pmd3/Scripts/pymobiledevice3.exe
"$PY" developer dvt launch --userspace --stream <bundle>   # ★ 应用 stdout + Mono 崩溃栈
"$PY" developer dvt screenshot --userspace out.png
"$PY" developer dvt graphics --userspace                   # GPU 利用率 / FPS
"$PY" crash flush && "$PY" crash ls
MSYS_NO_PATHCONV=1 "$PY" crash parse /<name>.ips           # ★ Git Bash 会篡改开头的 /
MSYS_NO_PATHCONV=1 "$PY" apps pull <bundle> /Library/Caches/launch-log.txt <local>   # 启动日志已从 Documents 迁到 Library/Caches，需开发签名
```

### 隧道

`pymobiledevice3 lockdown start-tunnel` **无条件要求管理员**（`@sudo_required`，
加 `--userspace` 也不放行）。改成给每条命令挂 `--userspace`，逐条建用户态隧道，
不需要管理员。

### 设备必须解锁

锁屏状态下启动会被系统拒绝，且报错完全不像锁屏：

```
DTXNsError: Request to launch <bundle> failed.        ← dvt launch 只说这么多
FBSOpenApplicationErrorDomain code 7:                 ← core-device launch-application 才说清楚
  Unable to launch <bundle> because the device was not, or could not be, unlocked.
  BSErrorCodeDescription: 'Locked'
```

**遇到 `Request to launch ... failed` 先截图看屏幕**，别急着怀疑构建。
`core-device get-lockstate` 在这台设备上是 `not implemented`，用
`core-device launch-application <bundle> ""` 拿真实原因。

### 观测上的坑

- **Avalonia 的渲染异常默认完全静默**。遇到「Avalonia 不画东西但不崩溃」，
  第一件事就是装 `Logger.Sink`（现在是 `Platform/AvaloniaLogBridge.cs`，常驻）。
- **`DisplayLinkDiagnostics.Ticks` 和 `LoopTicks` 含义不同**。CADisplayLink 从不被暂停，
  而 `DefaultRenderLoop` 休眠时是把 `Tick` 置 null。`link` 高而 `loop` 停住 =
  Avalonia 在休眠，不是定时器坏了。只记 `link` 得出的「定时器正常」没有依据。
- **日志截断会把答案切掉**。avalog 曾按 200 字符截断，正好切掉了已经包含答案的托管栈，
  整个解释器弯路就是这么来的。
- **scratchpad 会被自动清理**。pymobiledevice3 的 venv、zsign、证书都可能凭空消失，
  重建一遍即可，别当成设备故障。

---

## 关键文件

- `LumaChart.iOS/LumaChart.iOS.csproj` — 四个功能开关（问题 2）、补丁 DLL 接线、trim 配置。
- `LumaChart.iOS/AppDelegate.cs` — host 入口、seam 注册、`AvaloniaLogBridge` 安装、
  OpenGL 固定为渲染后端。
- `LumaChart.iOS/Platform/AvaloniaLogBridge.cs` — Avalonia Warning+ 日志转 `IOSLaunchLog`，
  合并连续重复，`Fill()` 做位置替换以保住异常的 `ToString()` 和栈。
- `LumaChart.iOS/Platform/IOSLaunchLog.cs` — 启动面包屑 + 崩溃轨迹，落 `Documents/`
  同时无条件 `Console.WriteLine`（`dvt launch --stream` 可读）。
- `LumaChart.iOS/Info.plist` — 不写 `CFBundleIdentifier`，见文件内注释。
- `LumaChart.Avalonia.Mobile/IOSApp.cs` — 单视图生命周期挂载 `MainWindow`。
- 构建机上的 `~/Developer/avalonia-src`（补丁源码）与 `~/Developer/avalonia-patched-out`（产物）。

## 已排除的假设（别再查）

| 假设 | 结论 |
|---|---|
| 同时设 `MainViewFactory` + `MainView` 双重挂载 | 排除。12.1.1 的 `SingleViewLifetime` 没有 `MainViewFactory` |
| 设 `MainView` 时 AvaloniaView 尚未创建 | 排除。`View` setter 有 `_view?.Content = _mainView` 补挂 |
| 缺 `UIApplicationSceneManifest` | 排除。官方 `ControlCatalog.iOS` 同样没声明 |
| 裁剪掉渲染类型 | 排除。`TrimMode=partial` |
| 构造期抛异常 | 排除。启动日志走完了全部 seam |
| Metal vs OpenGL 后端差异 | 排除。两者都受问题 1 影响 |
| 置空 `layer.Delegate` 可绕过问题 1 | **未验证**。置空后没有任何重绘请求，`Sync()` 从未再跑，既非成立也非证伪。已被真修复取代 |
| 解释器（`MtouchInterpreter` / `UseInterpreter`）能绕过 AOT 反射限制 | 排除。两次都死于问题 2 的 FailFast，且 `DynamicCodeSupport=false` 之后根本不需要 |
| `TrimMode=partial` 导致 BCL 反射桩缺失 | 排除。根因是 `DynamicCodeSupport`，与 trim 模式无关 |

## 构建/部署链路

- `tools\Sync-MacSource.ps1 -Delete` → `tools\Build-iOSApp.ps1` → 远端
  `tools/build-ios-remote.sh` → 未签名 ipa → `artifacts\ios\LumaChartStudio-unsigned.ipa`。
- VM 启停：`D:\Docker-OSX\Start-macOS.ps1` / `Stop-macOS.ps1` / `Status-macOS.ps1`。
  引导约 45 秒即可 SSH。
- `Build-iOSApp.ps1` **要前台跑**。后台并发跑过会拿到陈旧/空日志（重复构建 + 孤儿 pwsh）。
- 版本号 1.3.0.0 / 13000。

## 问题 4（已修复）：Avalonia 的 iOS 选择器返回的路径不持久

真机走查报出来的：选完音频文件，命名对话框正常显示文件名，输入名字点确认就变成
「音频文件已不存在，请重新选择。」

`IOSStorageProvider.cs:75` 用的是 `new UIDocumentPickerViewController(allowedTypes, false)`
——**`asCopy: false`**，返回的是指向文件原处（iCloud、别的 App 容器）的**安全作用域 URL**。
`IStorageFile.TryGetLocalPath()` 给出的路径只在 Avalonia 打开作用域期间可读。

共享代码 `PlatformPickedFiles.ResolveLocalPathAsync` 里有条捷径：`LocalPath` 非空且
`File.Exists` 为真就直接返回、不复制字节。于是 `File.Exists` 在选完的瞬间为真、
几秒后为假，调用方拿着一个永远打不开的路径。

修法：iOS 上跳过这条捷径，一律走 `OpenReadAsync()` 复制到
`Library/Caches/_resources/_picked`（Avalonia 会在 `OpenReadAsync` 内部自己开作用域）。
Windows 不受影响——桌面选择器本来就返回持久路径。

**同一根因的其它调用点**：`OnlineCommunityDialog` 的两个头像选择器直接用了
`TryGetLocalPath()`，已一并改走统一暂存。`MainWindow` 里的另存/导出/工作目录
调用点都在 `PlatformFileExportServices` / `SupportsWorkspaceDirectorySelection`
守卫之后，iOS 走不到。

**教训：iOS 上任何来自选择器的 `IStorageItem` 路径都不可留存，只能立刻复制。**

## 问题 5（已修复）：软键盘盖住模态对话框

iPad 上居中的模态对话框，确认按钮正好落在键盘位置。登录卡片更糟——键盘盖住的是
用户必须看清才能输入的验证码图。

`PlatformWindow`（mobile 分支）在弹模态时订阅 `TopLevel.InputPane.StateChanged`，
把遮挡高度加进底部边距。对话框是垂直居中的，压缩可用区间即等于抬起它；
`ClampToOverlay` 从同一个边距推导 `MaxHeight`，所以过高的对话框会缩而不是顶出屏幕。

用 `#if LUMACHART_IOS` 限定：**Android 编译同一个文件**，但它的窗口管理器本来就会为
软键盘调整界面，两边都做会缩两次。

另外把登录卡片启动时的 `loginUsername.Focus()` 也用 `#if !LUMACHART_IOS` 关掉了——
那个浮层是自己出现的，不该未经请求就把键盘顶起来。

## iOS 音频 sink 的坑（`Platform/IOSAudioOutput.cs`）

共享引擎会**频繁重建输出**：切换变速不变调走 `RecreateOutputAt`，Key 音服务每次 mixer
干涸也销毁重建。所以这个 sink 的创建和拆卸开销直接决定编辑体验。

- **拆卸调用会阻塞。** `AudioQueueStop(immediate)` / `AudioQueueReset` /
  `AudioQueueDispose` 都要等队列自己的线程 settle。引擎是在 **UI 线程**上销毁旧输出的，
  于是这些阻塞调用砸在画编辑器的线程上——表现是「切换变调后没声音一段时间、
  操作全乱、过一会自己恢复」。**先 `Pause()`（很轻，立刻静音），阻塞的那半扔线程池。**
- **不要在缓冲完成回调里调 `Stop(immediate)`。** 那是在队列自己的线程上等自己，死锁写法。
- **`AVAudioSession.SetPreferredIOBufferDuration` 不能放在每个输出的构造函数里。**
  它是进程级会话重配置，会把音频单元停掉重启；配合上面的频繁重建，M4 iPad 从 120 掉到 80 帧。
  缓冲深度才是决定这个 sink 延迟的东西。真要设就在工厂里设一次。
- **AudioQueue 的返回状态必须检查。** `AudioQueueStart` 失败时播放器照样报
  `PlaybackState.Playing`，然后一片静音——不崩、不报错。所有 `AudioQueueStatus` 现在
  都会在失败时进 `IOSLaunchLog`。
- **空读不等于流结束。** 时间拉伸链（SoundTouch）头几次 `Read` 返回 0 是在攒输入。
  有限次数（`MaxEmptyReadsBeforeEndOfStream`）内用静音填过去；上界是必须的，
  无限静音会把设备一直占着，Key 音服务会以为一个已结束的输出还活着。
- **`PlaybackStopped` 不要同步抛。** Android 那份在自己的渲染线程上抛，天然异步；
  处理器是会销毁并重建输出的共享代码，同步回调等于在建立过程中重入自己。

诊断开关：`dvt launch --env LUMACHART_IOS_AUDIO_TRACE=1` 打开逐输出的
创建/启动/停止序列，默认关闭（Key 音会把日志刷爆）。

## 补齐的平台 seam（iOS 之前比 Android 少三个）

| Seam | iOS 实现 |
|---|---|
| `PlatformAudioOutputs` | `Platform/IOSAudioOutput.cs`，AudioToolbox `OutputAudioQueue` |
| `PlatformFileImportServices` | `Platform/IOSFileTransferServices.cs`，`UIDocumentPickerViewController` |
| `PlatformFileExportServices` | 同上；iOS 没有"先建空文档"模式，选择器在 `CommitAsync` 里出 |

音频用 AudioQueue 而不是 RemoteIO：后者的渲染回调跑在硬实时线程，GC 停顿就是爆音。
`AVAudioSession` 必须显式设 Playback 并激活，否则静音键会把声音掐掉。
解码侧不用动，`AudioDecoder` 本来就在非 Windows 上走全托管的 NLayer / Vorbis。

## 构建机没有模拟器运行时——影响两个工具

`ibtool` 和 `actool` 都要求存在 iOS 模拟器运行时，这台 QEMU 机器上没有：

```
actool error : No available simulator runtimes for platform iphonesimulator.
               SimServiceContext supportedRuntimes=[]
```

两处都已绕开，都不需要那个运行时：

- **启动屏**：`UILaunchScreen` 用空字典而不是 storyboard。
- **应用图标**：不用 `Assets.xcassets`，预先切好 13 个尺寸当普通 `BundleResource`
  打包，按 `CFBundleIconFiles` 的前缀规则声明（`AppIcon60x60` 自动匹配 `@2x`/`@3x`，
  `~ipad` 选平板变体）。**不要写 `CFBundleIconName`**——那个键指向资源目录条目，
  会让系统去找不存在的 `Assets.car`。

图标源图 `LumaChart.App\Assets\app-icon.png` 是透明背景上的标志（不透明像素约占四分之一）。
iOS 图标必须满幅不透明（系统自己做圆角遮罩，alpha 渲染成黑），所以合成到 `#11171D`
上、占画布 68%。改图后从一张 1024 母图重新生成全部尺寸。

验证方式：`developer core-device fetch-app-icon <bundle> out.png` 能把设备上实际生效的
图标取回来，不用人眼看主屏幕。

## 未完成

- 真机验证：撤掉 `Avalonia.Skia` 补丁后是否仍正常渲染（问题 2 修复后多半不需要它了）。
- 需要人手点屏的走查：音频播放、导入、导出、编辑操作。
- 两个 Avalonia 补丁的终态：继续维护本地构建，还是提上游 PR
  （`DisplayLinkTimer` 是 iOS 26 通用问题，`SKCacheBase` 是 AOT 友好性，都值得提）。
- Android Release 回归未跑：这台机器 `dotnet workload list` 是空的（只有 SDK 9.0.308），
  是既有环境事实，不是本次改动引入的。

## 纪律

- LumaChart.Specs 保持 86/86；改共享代码后 Windows Avalonia + Android Release
  严格零警告零错误。不要动 Windows/Android 的行为、版本、体积。
- 不把任何测试密码 / OAuth / 服务器凭据 / token 写进包、日志或文档；
  `PRIVATE-OPERATIONS.local.md` 不打印不打包。签名证书与口令只留在 scratchpad。
