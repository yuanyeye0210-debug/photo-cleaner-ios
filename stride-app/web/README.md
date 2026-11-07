# Stride Web · 步迹

同一套 App 的浏览器版本：不装任何东西、不需要 Mac、不需要签名。
在 iPhone 上「添加到主屏幕」之后，它是全屏运行、有图标、有独立进程的——用起来和原生 App 没区别。

---

## 一、最快用法（手机 + 电脑同一个 Wi-Fi）

电脑上已经起了一个本地服务器，地址形如 `http://192.168.x.x:8080`。

1. iPhone 连**同一个 Wi-Fi**；
2. Safari 打开这个地址；
3. 底部 **分享** → **添加到主屏幕** → 右上角「添加」；
4. 桌面出现 **Stride** 图标，点开就是全屏 App。

> 电脑关机 / 换网络之后地址就失效了。想长期用，走下面的「永久部署」。

---

## 二、永久部署（1 分钟，免费，不用 Mac）

把整个 `StrideWeb` 文件夹拖到任意静态托管：

| 服务 | 做法 |
|---|---|
| **Netlify Drop** | 打开 https://app.netlify.com/drop → 把文件夹拖进去 → 立刻给你一个 https 地址 |
| **Vercel** | `npx vercel --prod`，或网页导入 |
| **GitHub Pages** | 推到仓库 → Settings → Pages → 选 main / root |
| **Cloudflare Pages** | 直接拖文件夹上传 |

部署到 https 之后，浏览器会注册 Service Worker（需要额外加一个 `sw.js`，见下），
断网也能打开；本地 http 访问时缓存不生效，但功能全都正常。

### 想加离线缓存

在 `StrideWeb` 下新建 `sw.js`：

```js
const CACHE = 'stride-v1';
const ASSETS = ['./', './index.html', './styles.css', './app.js', './manifest.webmanifest',
  './icons/icon-180.png', './icons/icon-192.png', './icons/icon-512.png'];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))));
});
self.addEventListener('fetch', e => {
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
});
```

然后在 `index.html` 的 `</body>` 前加一行：

```html
<script>if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js');</script>
```

---

## 三、功能对照

| 功能 | Web 版 | 说明 |
|---|---|---|
| 今日概览 / 三环 / 连击 | ✅ | |
| 训练记录（组次重量 RPE） | ✅ | 数据存 localStorage |
| 四周计划 / 重排 | ✅ | 本地生成 |
| 进度图表 / 肌群分布 / 1RM | ✅ | Canvas 手绘 |
| 足迹画风（6 种）+ 分享出图 | ✅ | 原生分享面板 / 下载 PNG |
| GPS 跑步轨迹 | ✅ | 需要 https 或 localhost 才给定位权限 |
| AI 教练 | ✅ | 本地规则引擎；填 Key 可接真模型（注意 CORS） |
| 拍照记餐 | ⚠️ | 相机可用，视觉识别请手动确认食材 |
| 歌单导入 / 歌词同步 | ✅ | |
| 插件市场（1RM / 杠铃片 / 计时 / BPM） | ✅ | |
| 会员方案页 | ✅ | 与原生版同一套 UI，默认全解锁 |
| Apple 健康 / Apple Watch | ❌ | 浏览器没有这类系统权限，只有原生 App 能给 |
| 相机骨骼识别计次 | ❌ | Web 版换成手动计数 |

想补齐最后三项，只能走原生包：见 `../iOS/BUILD-WITHOUT-MAC.md`（GitHub 云端编译 → Sideloadly 安装）。

---

## 四、数据在哪

全部在浏览器 `localStorage` 的 `stride.state.v2` 里，不上传任何服务器。
「我的 → 清空所有数据」可以重置为演示数据。
注意：Safari 清理网站数据、或用无痕模式，会丢记录。要长期保存，用「添加到主屏幕」后的那个独立容器，别用无痕。
