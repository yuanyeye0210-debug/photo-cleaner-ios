# StrideApp · 步迹

一个完整的健身 App，两套实现共享同一套设计：

```
stride-app/
├─ ios/     SwiftUI 原生工程（iOS 17+，零第三方依赖）
└─ web/     PWA 版（手机浏览器直接添加到主屏幕）
```

## ios/

| 项 | 说明 |
|---|---|
| 工程 | `Stride.xcodeproj`，34 个 Swift 文件，按 App / Core / AI / Health / Features / Components 分组 |
| 改品牌 | `Stride/App/Brand.swift` 一处；Bundle ID 改工程设置 |
| 全解锁 | `Stride/App/Brand.swift` → `LaunchFlags.everythingUnlocked` |
| 云编译 | 仓库根 `.github/workflows/stride-ios.yml` → Actions 手动或自动触发，产出未签名 IPA |
| 装机 | `ios/BUILD-WITHOUT-MAC.md`（Sideloadly + 免费 Apple ID 的完整步骤） |

**出包**：仓库 → Actions → `build-stride-ipa` → Run workflow → 跑完在 Artifacts 下载 `Stride-unsigned-ipa`，
解压得到 `Stride-unsigned.ipa`，拖进 Sideloadly 用 Apple ID 签名即可装到 iPhone（免费账号 7 天需重签）。

## web/

- 本机预览：`cd web && python -m http.server 8080`，手机同 Wi-Fi 打开 `http://<电脑IP>:8080`
- 部署：整个 `web/` 拖到 Netlify Drop / Vercel / GitHub Pages
- 装到桌面：Safari → 分享 → 添加到主屏幕

功能覆盖除「Apple 健康 / Watch / 相机骨骼识别」以外的全部；会员方案页与原生版同一套 UI，默认全解锁。
细节见 `web/README.md`。

## 关于授权

两套实现均为原创代码与素材，不含任何第三方 App 的二进制、资源或授权绕过逻辑。
会员页是本 App 自己的订阅界面，默认全解锁；接真订阅时替换 `ios/Stride/Core/Entitlements.swift` 里的 `PurchaseService`。
