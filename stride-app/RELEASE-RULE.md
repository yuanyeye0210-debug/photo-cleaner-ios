# 版本与备份规则

App 的包只在 GitHub Actions 里构建，所以版本规则也放在那里执行，不需要你手动删东西。

## 规则

| 项 | 约定 |
|---|---|
| 版本号 | `1.0.<构建序号>`，每次跑一次构建序号 +1，同时写进 App 的「我的 → 版本」 |
| 产物命名 | `Stride-1.0.N.ipa` |
| 存放位置 | GitHub **Releases**，tag 固定为 `stride-v1.0.N` |
| **保留数量** | **2 个**：最新的（当前）+ 前一个（备份） |
| 自动删除 | 第 3 个及更早的 release **连同 tag 一起删除**，不留残渣 |
| 工作流产物 | 额外存一份 Artifacts，只留 **7 天**，过期自动清 |

## 为什么保留 2 个

新版装上去发现闪退/功能坏了，直接回退到上一版，不用等重新构建。第 3 个版本没有任何用处——免费 Apple ID 本来也只能同时装 3 个自签 App。

## 在哪里看

```
仓库 → Releases
├─ Stride 1.0.12   ← 当前，直接下 .ipa（不用解压）
├─ Stride 1.0.11   ← 备份
└─ （更早的已被自动删除）
```

下载地址形如：

```
https://github.com/yuanyeye0210-debug/photo-cleaner-ios/releases
```

## 手动出一版

仓库 → Actions → `build-stride-ipa` → **Run workflow**。
跑完 Releases 里就多一个版本，同时最老的那个消失。

## 本机怎么存

建议在 `StrideApp\` 下建一个 `dist\`，只放两个文件：

```
StrideApp\dist\
├─ Stride-1.0.12.ipa     当前
└─ Stride-1.0.11.ipa     备份
```

下载新版本时，把旧的当前版改名成上一版，再删掉更早的——和 GitHub 上保持一致。
（这个目录不进 git，`.gitignore` 里已经排除了 `*.ipa`。）

## 改保留数量

`.github/workflows/stride-ios.yml` 顶部的：

```yaml
env:
  KEEP_RELEASES: 2
```

改成 1 就只留当前版，改成 3 就留当前 + 两个备份。
