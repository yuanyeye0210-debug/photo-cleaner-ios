# 没有 Mac，怎么把它装到 iPhone 上

结论先说：**IPA 必须由 macOS 工具链编译**，Sideloadly 负责「签名 + 安装」，不负责编译。
所以流程是三步：

```
云端 macOS 编译（GitHub 免费）  →  下载未签名 Stride-unsigned.ipa  →  Sideloadly 用你的 Apple ID 签名安装
```

全程只需要：一个 GitHub 账号（免费）、你的 iPhone、一根数据线、Windows 上的 Sideloadly。
我已经把编译脚本和 Scheme 都放进工程里了，你只需要点一下。

---

## 第一步：把工程推到 GitHub（约 3 分钟）

Windows 上已经装了 Git，在 PowerShell 里执行（把 `<你的用户名>` 换成你的 GitHub 用户名）：

```powershell
cd "F:\Masats破解版\Stride"
git init -b main
git add .
git commit -m "Stride iOS app"
```

先去 https://github.com/new 建一个空仓库，名字随意（比如 `stride`），**不要**勾选 README / .gitignore。
然后把仓库地址接上并推送：

```powershell
git remote add origin https://github.com/<你的用户名>/stride.git
git push -u origin main
```

> 第一次 push 会弹浏览器让你登录 GitHub 授权，按提示走即可。

不想用命令行也可以：在 GitHub 网页上 New repository → 进入仓库 → **Add file → Upload files**，
把 `F:\Masats破解版\Stride` 里的**所有内容**（包括隐藏的 `.github` 文件夹）一起拖进去。
注意：Windows 资源管理器里要打开「显示隐藏的项目」，否则 `.github` 传不上去，Actions 就不存在。

---

## 第二步：让 GitHub 帮你编译（约 5 分钟，不用管）

1. 打开你的仓库 → 顶部 **Actions** 标签；
2. 如果提示 "Workflows aren't being run on this repository"，点 **I understand my workflows, go ahead and enable them**；
3. 左侧选 **build-unsigned-ipa** → 右侧 **Run workflow** → 绿色 **Run workflow**；
4. 等 4–7 分钟，出现绿色对勾；
5. 点进这次运行 → 页面底部 **Artifacts** → 下载 **Stride-unsigned-ipa**。

下载得到的是一个 zip，解压出来就是 `Stride-unsigned.ipa`。

> 编译用的是 GitHub 免费的 macOS 15 运行器（自带 Xcode 16），不花你一分钱。
> 如果这一步报错，把日志最后 30 行发我，我改脚本。

---

## 第三步：Sideloadly 安装（约 2 分钟）

前提：Windows 上要装 **Apple 官方版 iTunes**（从 apple.com 下的那个，不是 Microsoft Store 版），
它提供 `Apple Mobile Device Support` 驱动。装完重启一次电脑。

1. iPhone 用数据线连电脑，手机上点「信任此电脑」；
2. 打开 Sideloadly，左上角会自动识别到你的设备（没识别就点刷新）；
3. 把 `Stride-unsigned.ipa` 拖进 Sideloadly 的 IPA 框；
4. **Apple ID** 填你的 Apple ID（免费账号就行）；
5. 点 **Start**，输入 Apple ID 密码；
   - 如果开了双重认证，会要你在手机上确认，然后填一个 **App 专用密码**（appleid.apple.com → 登录与安全 → App 专用密码 → 生成一个填进去）；
6. 进度条走完，手机上就出现 **Stride** 了。

**首次打开会被拦**：设置 → 通用 → VPN 与设备管理 → 找到你的 Apple ID → 点「信任」。
然后回桌面打开 Stride。

---

## 免费 Apple ID 的现实限制（提前知道，别到时候懵）

| 限制 | 说明 | 影响 |
|---|---|---|
| **7 天过期** | 免费证书 7 天失效，App 打不开 | 每周重连一次 Sideloadly 点 Start 重签，数据不丢 |
| **最多 3 个 App** | 免费账号同时只能装 3 个自签应用 | 装别的就得删 |
| **每周 10 个 App ID** | 改 Bundle ID 会消耗额度 | 尽量别频繁改 bundle id |
| **没有 HealthKit 权限** | 免费配置里带不了 HealthKit entitlement | 「Apple 健康」那一行会授权失败，这是正常的 |
| **没有 Watch App** | 手表 target 需要单独签名 | 手机侧的 Watch 桥接照常编译，但腕上没界面 |

想要 7 天不过期，只有两条路：付费开发者账号（$99/年，1 年有效期），或者用 AltStore 的自动续签（仍然需要一台常开的电脑）。

---

## 常见报错

| 现象 | 原因 / 处理 |
|---|---|
| Sideloadly 卡在 "Generating..." | 双重认证没填 App 专用密码，换专用密码重试 |
| 手机提示 "无法安装此 App" | Bundle ID 被别人占了；Sideloadly 里把 Bundle ID 改成 `com.<你的名字>.stride` |
| 打开就闪退 | 证书没被信任，去 VPN 与设备管理里点信任 |
| 装完图标是白的 | 正常，首次启动后会缓存图标 |
| 打不开、提示需要更新 | 满 7 天了，重新走一遍 Sideloadly |

---

## 另一个不用 GitHub 的选项

[Codemagic](https://codemagic.io) 也能在浏览器里编译 iOS 包（免费 500 分钟/月），
它的 `codemagic.yaml` 我也放在工程根目录了：注册 → 连同一个 GitHub 仓库 → 选 `ios-unsigned` 工作流 →
构建完成后在 Artifacts 里下 `Stride-unsigned.ipa`。缺点依然是**要先有 Git 仓库**。

---

## 如果连 GitHub 都不想弄

`F:\Masats破解版\StrideWeb\` 里是同一套 App 的 Web 版，我用本地服务器跑起来了：
手机连同一个 Wi-Fi，Safari 打开我给你的地址 → 分享 → 「添加到主屏幕」，桌面就有图标，
全屏运行，功能除了健康/Watch/相机骨骼识别以外全都在。见同目录 `README.md`。
