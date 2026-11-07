# Stride · 步迹

> 这个目录是一个完整的健身 App，两套实现共享同一套设计：
>
> - **iOS 原生**：Stride.xcodeproj（SwiftUI，34 个文件）
>   - 云编译：仓库根目录 .github/workflows/stride-ios.yml → Actions 里跑完下载 Stride-unsigned.ipa
>   - 装机步骤见 BUILD-WITHOUT-MAC.md
> - **Web 版**：web/（PWA，手机浏览器直接打开即可添加到主屏幕）
>
> 权益默认全解锁；会员方案页可完整交互，接真订阅时替换 Core/Entitlements.swift 里的 PurchaseService。

---

一个**独立实现的 iOS 健身 App**：训练记录、渐进式负荷、AI 热量识别与教练、足迹画风、Watch/健康联动。
功能矩阵按 Msats 的会员页对齐（免费 / Pro / Max 三档），界面沿用同一套深色视觉语言；
**代码、素材、品牌全部原创**，不包含任何第三方 App 的二进制、资源或破解逻辑。

工程里的权益默认**全部解锁**（`LaunchFlags.everythingUnlocked = true`），会员页仍然完整可交互，用于展示和承接真实订阅。

---

## 打开与运行

| 环境 | 做法 |
|---|---|
| Xcode 16+ | 直接双击 `Stride.xcodeproj`，选模拟器 ⌘R |
| Xcode 15 | 先 `brew install xcodegen`，在本目录执行 `xcodegen generate`，再打开生成的工程 |

- 部署目标 iOS 17.0，Swift 5 语言模式，零第三方依赖。
- 首次运行会写入一份演示数据（3 周训练、6 条轨迹、今日三餐），之后全部走本地存储：
  `~/Library/Application Support/Stride/state.json`
- 模拟器没有相机 / 健康数据 / GPS，相关页面会自动降级并给出提示。

### 需要在真机验证的能力

| 能力 | 需要打开的 Capability | 备注 |
|---|---|---|
| Apple 健康双向同步 | Signing & Capabilities → **HealthKit** | 不开也能编译，授权会失败并提示 |
| Apple Watch 实时同步 | 加一个 watchOS App target | 手机侧桥接已写好，见下 |
| 视觉动作计数 | 无需 Capability | 需要真相机；模拟器提示"没有可用相机" |
| 足迹记录 | 无需 Capability | 首次进入会请求定位权限 |

---

## 功能地图

### 免费版（全部已包含）

| 功能 | 文件 |
|---|---|
| 完整训练与记录 | `Features/Workout/SessionView.swift`、`TrainingHomeView.swift` |
| 每天 10 次 AI 热量识别 | `Features/Food/FoodScanView.swift` + `AI/FoodRecognition.swift` |
| AI 教练对话 20 次体验 | `Features/Coach/CoachView.swift` + `AI/CoachEngine.swift` |
| Apple Watch 连接与实时同步 | `Health/WatchSession.swift` |
| 插件市场全部小工具 | `Features/Me/PluginsView.swift`（1RM / 杠铃片 / 休息计时 / 节奏换算） |
| 视觉动作计数 | `Features/Camera/RepCounterView.swift`（Vision 关节角 + 组数状态机） |
| Apple 健康双向同步 | `Health/HealthKitManager.swift` |
| 3 套足迹画风 · 1 套分享模板 | `Features/Progress/RouteArtView.swift` |
| 歌词同步不限次数 | `Features/Music/LyricsView.swift`（LRC 解析 + 逐行跟读） |

### Pro / Max

| 权益 | 实现 |
|---|---|
| 每天 40 次 / 不限次 AI 热量识别 | `Core/Entitlements.swift` 的 `Tier.foodLimitPerDay` + 每日额度记账 |
| 更充裕 / 不限 AI 教练额度 | `Tier.coachLimit` + `QuotaBook` |
| AI 生成训练计划 | `AI/PlanGenerator.swift`（本地周期化生成，可换模型重排） |
| 渐进式 AI 学习 | `Core/ProgressiveEngine.swift`（e1RM、双进阶、RPE 自调节、减载判定） |
| iCloud 数据同步 | 预留：`AppStore` 的 JSON 状态可直接换 `NSUbiquitousKeyValueStore` 或 CloudKit 私有库 |
| 歌单链接导入解析 | `Features/Music/PlaylistImportView.swift` |
| 全部足迹画风与分享模板 | `RouteArtStyle`（6 种）/ `ShareTemplate`（4 种）+ `ImageRenderer` 出图 |

会员页本体：`Features/Membership/MembershipView.swift` —— 年付/半年付/月付、绿色省钱标、当前方案态、Pro 展开列表、免费版已包含网格、本期用量、底部自动续订说明，全部按截图还原。

---

## 接一个真模型

「我的 → AI 服务」填三项即可，兼容任何 OpenAI 协议端点：

```
接口地址   https://api.openai.com/v1        （或自建网关 / 国内兼容服务）
API Key    sk-...
对话模型   gpt-4o-mini
视觉模型   gpt-4o-mini                      （必须支持图片输入，用于热量识别）
```

没填之前：教练走本地规则引擎（`CoachEngine.localReply`，会读你的真实训练记录、肌群组数、当日营养），
热量识别提示改手动记录（内置 40 种常见食物的营养库，`AI/FoodRecognition.swift`）。

---

## 改成你自己的产品

| 要改的 | 位置 |
|---|---|
| App 名 / 品牌名 / 会员名 | `App/Brand.swift` 一处 |
| Bundle ID | 工程 Build Settings 或 `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER` |
| 配色 | `App/Theme.swift` 的 `Palette` |
| 默认档位 / 额度 | `Core/Entitlements.swift` 的 `Tier` |
| 是否全解锁 | `App/Brand.swift` 的 `LaunchFlags.everythingUnlocked` |
| 真订阅 | 把 `PurchaseService` 换成 StoreKit 2 的 `Product.purchase()`，UI 不用动 |

---

## 关于 Watch 端

手机侧 `WatchSession` 已经能把"当前动作 / 第几组 / 休息剩余"推给手表，并对未连接状态用
`updateApplicationContext` 兜底。要真正在腕上显示，加一个 watchOS App target：

1. File → New → Target → watchOS App，名字随意；
2. 在手表 target 里 `WCSession.default` 激活并实现 `didReceiveApplicationContext`；
3. 把 `Health/WatchSession.swift` 顶部的字段名（`kind/title/elapsed/setIndex/totalSets`）复用成手表端的解码结构。

这一步必须在 Xcode 里做（需要单独 target 与签名），我这边只交付了手机侧桥接层。

---

## 边界说明

- 不包含、也不依赖任何第三方 App 的安装包、逆向产物或授权绕过逻辑。
- 会员页是**本 App 自己的**订阅界面：默认全解锁，接真订阅时用上面那行替换购买实现。
- 用户数据只写本机 `Application Support`，不上传；拍照识别的图片只在你配置了 AI 服务时发给你自己的端点。
