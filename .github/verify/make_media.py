# UI 自检用的示例照片：普通照片、相似照片组、模糊/过暗、二维码，以及「本 App 界面的截图」（复现截图分类里的样子）
import io, os, random, sys, urllib.request, datetime
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont
import piexif, qrcode

out = sys.argv[1]; os.makedirs(out, exist_ok=True)
random.seed(11)
now = datetime.datetime.now()
n = 0

def font(sz):
    for p in ["/System/Library/Fonts/PingFang.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc",
              "/System/Library/Fonts/STHeiti Medium.ttc", "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
              "/Library/Fonts/Arial Unicode.ttf"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, sz)
            except Exception: pass
    return ImageFont.load_default()

def save(img, when, screenshot=False):
    global n
    n += 1
    ds = when.strftime("%Y:%m:%d %H:%M:%S").encode()
    exif = {"0th": {piexif.ImageIFD.DateTime: ds, piexif.ImageIFD.Make: b"Apple", piexif.ImageIFD.Model: b"iPhone 15 Pro"},
            "Exif": {piexif.ExifIFD.DateTimeOriginal: ds, piexif.ExifIFD.DateTimeDigitized: ds}}
    if screenshot:
        exif["Exif"][piexif.ExifIFD.UserComment] = b"ASCII\x00\x00\x00Screenshot"
    p = os.path.join(out, f"{n:03d}.jpg")
    img.convert("RGB").save(p, "JPEG", quality=90, exif=piexif.dump(exif))

def ago(days, minutes=0, seconds=0):
    return now - datetime.timedelta(days=days, minutes=minutes, seconds=seconds)

def picsum(i, w=1200, h=1600):
    for _ in range(3):
        try:
            data = urllib.request.urlopen(f"https://picsum.photos/id/{i}/{w}/{h}", timeout=30).read()
            return Image.open(io.BytesIO(data)).convert("RGB")
        except Exception as e:
            print("retry", i, e)
    return None

def synthetic(seed, w=1200, h=1600):
    r = random.Random(seed)
    im = Image.new("RGB", (w, h), tuple(r.randint(40, 200) for _ in range(3)))
    d = ImageDraw.Draw(im)
    for _ in range(14):
        x, y = r.randint(0, w), r.randint(0, h); s = r.randint(80, 500)
        d.ellipse((x - s, y - s, x + s, y + s), fill=tuple(r.randint(0, 255) for _ in range(3)))
    return im.filter(ImageFilter.GaussianBlur(3))

def photo(i):
    return picsum(i) or synthetic(i)

# 普通照片
for k, i in enumerate([1015, 1036, 1043, 1050, 237, 1080, 292, 1025, 429, 1062]):
    save(photo(i), ago(10 + k * 17, minutes=k * 7))

# 相似照片：同一场景连拍 3 张（几秒内、轻微裁切/亮度变化）
for g, i in enumerate([1018, 1039, 1044]):
    base = photo(i); w, h = base.size
    t0 = ago(30 + g * 40)
    for k in range(3):
        im = base.crop((k * 12, k * 9, w - (2 - k) * 12, h - (2 - k) * 9)).resize((w, h))
        im = ImageEnhance.Brightness(im).enhance(1 + (k - 1) * 0.04)
        save(im, t0 + datetime.timedelta(seconds=k * 2))

# 模糊 / 过暗
for k, i in enumerate([1016, 1019]):
    save(photo(i).filter(ImageFilter.GaussianBlur(18)), ago(200 + k))
for k, i in enumerate([1047, 1060]):
    save(ImageEnhance.Brightness(photo(i)).enhance(0.08), ago(220 + k))

# 二维码
qr = qrcode.make("https://github.com/yuanyeye0210-debug/photo-cleaner-ios").convert("RGB").resize((900, 900))
bg = Image.new("RGB", (1200, 1600), "white"); bg.paste(qr, (150, 300)); save(bg, ago(5))

# 本 App 界面的截图（1320×2868，深色）：里面也画着「滑动筛选 | 网格多选」和进度，
# 用来确认截图卡片能一眼看出是「一张图片」，不会像界面套界面
def app_screenshot(seed, title, count):
    W, H = 1320, 2868
    im = Image.new("RGB", (W, H), (0, 0, 0)); d = ImageDraw.Draw(im)
    f = font(48); fb = font(60); fs = font(40)
    d.text((110, 70), "00:15", fill="white", font=fb)
    d.text((W // 2 - 60, 230), title, fill="white", font=fb)
    d.rounded_rectangle((60, 380, W - 60, 620), 60, fill=(28, 28, 30))
    d.text((300, 440), f"5 / {count}", fill="white", font=font(90))
    d.rounded_rectangle((60, 680, W - 60, 820), 70, fill=(28, 28, 30))
    d.rounded_rectangle((72, 692, W // 2, 808), 60, fill=(58, 58, 60))
    d.text((300, 722), "滑动筛选", fill="white", font=f)
    d.text((W // 2 + 230, 722), "网格多选", fill=(150, 150, 150), font=f)
    d.text((70, 860), f"5 / {count}", fill=(160, 160, 160), font=fs)
    d.text((W - 560, 860), "左滑删除 · 右滑保留", fill=(120, 120, 120), font=fs)
    d.rounded_rectangle((60, 930, W - 60, 946), 8, fill=(44, 44, 46))
    d.rounded_rectangle((60, 930, 160, 946), 8, fill=(80, 200, 120))
    d.rounded_rectangle((100, 1000, W - 100, 2450), 60, fill=(40, 40, 42))
    r = random.Random(seed)
    for _ in range(6):
        x = r.randint(200, W - 300); y = r.randint(1100, 2200)
        d.ellipse((x, y, x + 160, y + 160), fill=tuple(r.randint(60, 230) for _ in range(3)))
    for k, x in enumerate([180, 470, 760, 1050]):
        d.ellipse((x, 2560, x + 170, 2730), fill=(44, 44, 46))
    return im

for k, (t, c) in enumerate([("截图", 72), ("二维码", 12), ("模糊照片", 31)]):
    save(app_screenshot(k, t, c), ago(1 + k, minutes=k * 50), screenshot=True)

print("made", n, "files")
