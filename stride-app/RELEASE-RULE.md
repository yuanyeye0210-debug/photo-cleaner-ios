# 版本与同步规则

两条铁律，都做成自动的了：

1. **改完代码就要同步到 GitHub，云端构建通过才算成品。**
2. **每次出新版本，备份上一版；更老的自动删除，只留 2 个。**

---

## 规则一：改完必须同步

| 场景 | 做法 |
|---|---|
| 我（助手）改代码 | 改完直接 push，Actions 自动编译，Releases 自动更新 —— 不用你操作 |
| 你自己改代码 | 双击 `tools\sync.ps1`（或 `pwsh -File tools\sync.ps1`），一条命令完成 commit + push |
| 只改文档 / Web / 工具 | 同样同步，但**不会**触发 iOS 编译，不产生新版本号 |

同步范围：

```
本地 StrideApp\iOS\      →  仓库 stride-app/ios/
本地 StrideApp\Web\      →  仓库 stride-app/web/
本地 StrideApp\*.md      →  仓库 stride-app/*.md
本地 tools\stride-ios.yml →  仓库 .github/workflows/stride-ios.yml
```

`sync.ps1` 用的是 `%TEMP%\stride-repo` 的临时副本，不污染你的文件夹。
它只做「本地 → 仓库」单向覆盖，不会碰仓库里 PhotoCleaner 的东西。

**判定标准**：Actions 那次运行是绿勾，Releases 里出现了新版本，才算成品。
红的就说明代码有问题，得修完重跑——不能拿旧包糊弄。

---

## 规则二：版本与备份

| 项 | 约定 |
|---|---|
| 版本号 | `1.0.<构建序号>`，每次构建 +1，同时写进 App「我的 → 版本」 |
| 产物 | `Stride-1.0.N.ipa` |
| 存放 | GitHub **Releases**，tag = `stride-v1.0.N` |
| **保留** | **2 个**：当前 + 上一版备份 |
| 自动删除 | 第 3 个及更早的 release **连同 tag** 一起删 |
| Actions Artifacts | 额外留一份，7 天过期 |

顺序按**版本号数字**排序，不是按时间（GitHub 返回的 `createdAt` 会重复，按时间排会误删最新版，已经踩过一次）。

```
Releases
├─ Stride 1.0.9    ← 当前
├─ Stride 1.0.8    ← 备份（新版闪退就装回这个）
└─ 更早的已被删除
```

---

## 日常三步

```powershell
# 1. 改完代码，同步到 GitHub（触发云端编译）
pwsh -File "F:\Masats破解版\StrideApp\tools\sync.ps1" -Message "feat: xxx"

# 2. 等 2 分钟，Actions 绿了之后，把新包拉到 dist\
pwsh -File "F:\Masats破解版\StrideApp\tools\fetch-latest.ps1"

# 3. 把打印出来的那个 .ipa（dist\ 里最新的）拖进 Sideloadly
```

`fetch-latest.ps1` 会自动把 `dist\` 里超过 2 个的旧包删掉，和 GitHub 上保持一致。

---

## 改保留数量

`tools\stride-ios.yml` 顶部：

```yaml
env:
  KEEP_RELEASES: 2
```

改 1 = 只留当前，改 3 = 当前 + 两个备份。改完跑一次 `sync.ps1` 生效。

---

## 在哪里看

- 构建历史和日志：`https://github.com/yuanyeye0210-debug/photo-cleaner-ios/actions/workflows/stride-ios.yml`
- 下载成品：`https://github.com/yuanyeye0210-debug/photo-cleaner-ios/releases`
