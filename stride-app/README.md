# StrideApp · 步迹

一个健身 App 的全部东西，放在这一个文件夹里。三个子目录对应三块交付物，互不干扰。

```
StrideApp\
├─ iOS\          SwiftUI 原生工程（34 个 Swift 文件 + AppIcon + 云编译配置）
├─ Web\          PWA 版（手机浏览器打开即可添加到主屏幕）
└─ DSH-Plugin\   dsh-craft-anything 插件（逆向研究用的 DSH 接入层）
```

---

## iOS\ —— 原生 App

| 项 | 说明 |
|---|---|
| 工程 | `Stride.xcodeproj`（iOS 17+，Swift 5，零第三方依赖） |
| 源码 | `Stride\` 下 34 个文件，按 App / Core / AI / Health / Features / Components 分组 |
| 图标 | `Stride\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon.png`（1024×1024） |
| 改品牌 | `Stride\App\Brand.swift` 一处；Bundle ID 改工程设置 |
| 全解锁开关 | `Stride\App\Brand.swift` 的 `LaunchFlags.everythingUnlocked` |
| 装机说明 | **`BUILD-WITHOUT-MAC.md`**（没有 Mac 也能出 IPA 的完整步骤） |

**已经编好的包**在 GitHub Actions 里：
仓库 `photo-cleaner-ios` → Actions → `build-stride-ipa` → Artifacts → `Stride-unsigned-ipa`。
下载后丢进 Sideloadly 用 Apple ID 签名即可装到 iPhone（免费账号 7 天需重签）。

改了代码要出新包：在 `iOS\` 目录 `git add / commit / push`，`stride/**` 一变 Actions 自动跑。

---

## Web\ —— 浏览器版

同一个 App 的 Web 实现，功能覆盖到除「Apple 健康 / Watch / 相机骨骼识别」以外的全部。

- **本机预览**：`cd Web` 后 `python -m http.server 8080`，手机同 Wi-Fi 打开 `http://<电脑IP>:8080`
- **永久部署**：整个 `Web` 文件夹拖到 Netlify Drop / Vercel / GitHub Pages，拿到 https 地址
- **装到桌面**：Safari 打开 → 分享 → 添加到主屏幕，全屏运行、有图标

细节见 `Web\README.md`。

---

## DSH-Plugin\ —— craft-anything 插件

把 [Craft Anything](https://github.com/storytold/craft-anything) 接进 DeepSeek Harness 的桥接层，
提供 `mcp__craft__*` 工具、净室/深度模式开关和状态页。和健身 App 无关，是另一件事留下的。

```powershell
dsh plugin --profile desktop add link:"F:\Masats破解版\StrideApp\DSH-Plugin"
```

---

## 一句话版本

要**装到 iPhone** → 走 `iOS\BUILD-WITHOUT-MAC.md`；
要**马上能用** → 走 `Web\`，30 秒添加到主屏幕。
