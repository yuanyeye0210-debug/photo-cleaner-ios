# 生成宣传视频用的示例照片（风景/美食/宠物来自 picsum.photos = Unsplash 授权，其余由脚本自己画）
import io, os, random, sys, urllib.request, datetime
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont
import piexif, qrcode

out = sys.argv[1]; os.makedirs(out, exist_ok=True)
random.seed(7)
now = datetime.datetime.now()
n = 0

def font(sz):
    for p in ["/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/STHeiti Medium.ttc",
              "/System/Library/Fonts/Hiragino Sans GB.ttc", "/Library/Fonts/Arial Unicode.ttf"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, sz)
            except Exception: pass
    return ImageFont.load_default()

def save(img, days_ago=None, when=None, screenshot=False, ext="jpg"):
    global n
    n += 1
    d = when or (now - datetime.timedelta(days=days_ago if days_ago is not None else random.randint(1, 600),
                                           minutes=random.randint(0, 900)))
    ds = d.strftime("%Y:%m:%d %H:%M:%S").encode()
    exif = {"0th": {piexif.ImageIFD.DateTime: ds, piexif.ImageIFD.Make: b"Apple", piexif.ImageIFD.Model: b"iPhone 15 Pro"},
            "Exif": {piexif.ExifIFD.DateTimeOriginal: ds, piexif.ExifIFD.DateTimeDigitized: ds}}
    if screenshot:
        exif["Exif"][piexif.ExifIFD.UserComment] = b"ASCII\x00\x00\x00Screenshot"
    p = os.path.join(out, f"{n:03d}.jpg")
    img.convert("RGB").save(p, "JPEG", quality=92, exif=piexif.dump(exif))
    return p

def picsum(i, w=1200, h=1600):
    for _ in range(3):
        try:
            data = urllib.request.urlopen(f"https://picsum.photos/id/{i}/{w}/{h}", timeout=30).read()
            return Image.open(io.BytesIO(data)).convert("RGB")
        except Exception as e:
            print("retry", i, e)
    return None

# 风景 / 美食 / 宠物 / 日常（Unsplash 授权图）
ids = [1015, 1016, 1018, 1019, 1036, 1039, 1043, 1044, 1047, 1050, 1062, 1025, 237, 169, 200, 1080, 429, 292, 312, 225, 1060, 102, 1011, 1035]
base = {}
for i in ids:
    im = picsum(i)
    if im: base[i] = im; save(im)

# 那年今日：往年同一天
for k, i in enumerate([1015, 1036, 1043]):
    if i in base:
        save(base[i].transpose(Image.FLIP_LEFT_RIGHT), when=now.replace(year=now.year - 1 - k, hour=15))

# 相似照片：同一场景轻微变化（换角度/亮度）
for i in [1018, 1039, 1044, 237]:
    if i not in base: continue
    t0 = now - datetime.timedelta(days=random.randint(5, 200))
    for k in range(3):
        im = base[i]
        w, h = im.size
        c = im.crop((k * 30, k * 20, w - (2 - k) * 30, h - (2 - k) * 20)).resize((w, h))
        c = ImageEnhance.Brightness(c).enhance(1 + (k - 1) * 0.06)
        save(c, when=t0 + datetime.timedelta(seconds=k * 4))

# 完全重复：同一张存两次
for i in [1047, 169]:
    if i in base:
        save(base[i], days_ago=40); save(base[i], days_ago=40)

# 模糊
for i in [1050, 200, 1080]:
    if i in base: save(base[i].filter(ImageFilter.GaussianBlur(18)))
# 过暗 / 过曝
for i in [1062, 429]:
    if i in base: save(ImageEnhance.Brightness(base[i]).enhance(0.08))
for i in [292]:
    if i in base: save(ImageEnhance.Brightness(base[i]).enhance(3.2))

# 截图：聊天 + 验证码
def chat(code=None):
    im = Image.new("RGB", (1179, 2556), (242, 242, 247)); d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 1179, 260), fill=(250, 250, 250)); d.text((420, 150), "消息", fill=(0, 0, 0), font=font(56))
    y = 340
    for j in range(9):
        mine = j % 2 == 1
        w = random.randint(420, 760)
        x0 = 1179 - 60 - w if mine else 60
        d.rounded_rectangle((x0, y, x0 + w, y + 130), 40, fill=(52, 199, 89) if mine else (255, 255, 255))
        d.text((x0 + 40, y + 40), random.choice(["晚上一起吃饭吗", "好的，几点？", "收到", "明天见", "照片发我一下"]), fill=(0, 0, 0), font=font(46))
        y += 190
    if code:
        d.rounded_rectangle((60, y, 1000, y + 260), 40, fill=(255, 255, 255))
        d.text((100, y + 40), f"【银行】验证码 {code}，5 分钟内有效，", fill=(0, 0, 0), font=font(46))
        d.text((100, y + 130), "请勿泄露给他人。", fill=(0, 0, 0), font=font(46))
    return im
for k in range(4): save(chat(), screenshot=True)
save(chat("482913"), screenshot=True)
save(chat("736051"), screenshot=True)

# 票据 / 文档
def receipt():
    im = Image.new("RGB", (1200, 1600), (60, 52, 46)); d = ImageDraw.Draw(im)
    d.rectangle((260, 120, 940, 1480), fill=(250, 249, 244))
    f = font(42); y = 180
    d.text((440, y), "购物小票", fill=(0, 0, 0), font=font(56)); y += 110
    for item, p in [("拿铁咖啡", "28.00"), ("全麦面包", "16.50"), ("牛奶 1L", "12.80"), ("苹果 1kg", "19.90"), ("纸巾", "9.90")]:
        d.text((300, y), item, fill=(0, 0, 0), font=f); d.text((760, y), p, fill=(0, 0, 0), font=f); y += 80
    d.line((300, y + 20, 900, y + 20), fill=(0, 0, 0), width=3)
    d.text((300, y + 60), "合计", fill=(0, 0, 0), font=f); d.text((760, y + 60), "87.10", fill=(0, 0, 0), font=f)
    d.text((300, y + 160), "2026-10-21 18:42  收银台 03", fill=(0, 0, 0), font=font(34))
    return im
for k in range(3): save(receipt().rotate(random.uniform(-6, 6), fillcolor=(60, 52, 46)))

# 二维码
for k in range(3):
    q = qrcode.make(f"https://example.com/pay/{k}").convert("RGB").resize((900, 900))
    im = Image.new("RGB", (1200, 1600), (255, 255, 255)); im.paste(q, (150, 300))
    ImageDraw.Draw(im).text((330, 1300), "扫码付款", fill=(0, 0, 0), font=font(80))
    save(im)
print("generated", n)
