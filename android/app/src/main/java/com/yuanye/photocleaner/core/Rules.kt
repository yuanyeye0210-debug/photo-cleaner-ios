package com.yuanye.photocleaner.core

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** AI 识别结果 → 内容标签 */
enum class ContentTag { DOCUMENT, QR_CODE, FOOD, PET, SCENERY, SCREENSHOT_LIKE }

/**
 * Google ML Kit 识别结果 → 清理分类的纯规则部分（对应 iOS 版 VisionRules）。
 * ML Kit 默认模型的标签见 https://developers.google.com/ml-kit/vision/image-labeling/label-map
 * 这里统一用小写比较。
 */
object VisionRules {
    val documentLabels = setOf("receipt", "paper", "menu", "passport", "newspaper", "money", "whiteboard", "blackboard", "news")
    val foodLabels = setOf(
        "food", "cuisine", "fast food", "cheeseburger", "hot dog", "bento", "pizza", "sushi", "cake", "cookie",
        "bread", "pie", "gelato", "couscous", "pho", "pasteles", "meal", "lunch", "supper", "icing", "fruit", "vegetable",
    )
    val petLabels = setOf(
        "cat", "dog", "pet", "shetland sheepdog", "cairn terrier", "dalmatian", "ragdoll", "himalayan", "pixie-bob",
        "sphynx", "basset hound", "shikoku", "cavalier", "gerbil", "boxer",
    )
    val sceneryLabels = setOf(
        "mountain", "sunset", "beach", "lake", "waterfall", "desert", "forest", "glacier", "cliff", "canyon", "river",
        "volcano", "sky", "skyline", "aurora", "dune", "prairie", "field", "iceberg", "rainbow", "reef", "swamp", "fog",
    )
    val peopleLabels = setOf("person", "selfie", "smile", "dude", "baby", "bride", "groom", "crowd", "team", "laugh", "beard")
    val screenshotLabels = setOf("screenshot", "web page", "icon")
    /** 可能有大量文字的标签（决定要不要做文字识别） */
    val textLabels = setOf(
        "screenshot", "web page", "receipt", "paper", "menu", "newspaper", "news", "poster", "presentation",
        "whiteboard", "blackboard", "comics",
    )

    const val DOCUMENT_CONFIDENCE = 0.5f
    const val FOOD_CONFIDENCE = 0.6f
    const val PET_CONFIDENCE = 0.6f
    const val SCENERY_CONFIDENCE = 0.6f
    const val SCREENSHOT_CONFIDENCE = 0.5f
    const val PEOPLE_CONFIDENCE = 0.5f

    fun tags(labels: List<Pair<String, Float>>, hasQR: Boolean): Set<ContentTag> {
        val conf = HashMap<String, Float>()
        for ((id, c) in labels) {
            val k = id.lowercase()
            conf[k] = max(conf[k] ?: 0f, c)
        }
        fun maxConf(set: Set<String>): Float = set.fold(0f) { acc, s -> max(acc, conf[s] ?: 0f) }
        val out = mutableSetOf<ContentTag>()
        if (hasQR) out += ContentTag.QR_CODE
        if (maxConf(documentLabels) >= DOCUMENT_CONFIDENCE) out += ContentTag.DOCUMENT
        if (maxConf(foodLabels) >= FOOD_CONFIDENCE) out += ContentTag.FOOD
        if (maxConf(petLabels) >= PET_CONFIDENCE) out += ContentTag.PET
        val hasPeople = maxConf(peopleLabels) >= PEOPLE_CONFIDENCE
        if (!hasPeople && maxConf(sceneryLabels) >= SCENERY_CONFIDENCE) out += ContentTag.SCENERY
        if (maxConf(screenshotLabels) >= SCREENSHOT_CONFIDENCE) out += ContentTag.SCREENSHOT_LIKE
        return out
    }

    fun textLikelihood(labels: List<Pair<String, Float>>): Float =
        labels.fold(0f) { acc, (id, c) -> if (id.lowercase() in textLabels) max(acc, c) else acc }

    /** 只对「可能是文字图」的候选做文字识别（省电省时） */
    fun shouldRecognizeText(
        isScreenshot: Boolean, tags: Set<ContentTag>, textLikelihood: Float, brightness: Double, aspect: Double,
    ): Boolean =
        isScreenshot || ContentTag.DOCUMENT in tags || ContentTag.SCREENSHOT_LIKE in tags ||
            textLikelihood >= 0.3f || aspect >= 2.0 || brightness >= 200

    /** 文字识别用的尺寸：普通图最长边 1024；长图保证短边约 900，最长不超过 4096 */
    fun textTargetSize(width: Int, height: Int): Pair<Int, Int> {
        if (width <= 0 || height <= 0) return 1024 to 1024
        val long = max(width, height).toDouble()
        val short = min(width, height).toDouble()
        var scale = 1024.0 / long
        if (long / short >= 2.0) scale = 900.0 / short
        scale = minOf(scale, 4096.0 / long, 1.0)
        return max(1, (width * scale).roundToInt()) to max(1, (height * scale).roundToInt())
    }

    /** 文字很多：行数 ≥ 6 或字数 ≥ 80 */
    fun isTextHeavy(lines: Int, chars: Int): Boolean = lines >= 6 || chars >= 80

    val codeKeywords = listOf("验证码", "校验码", "动态码", "确认码", "激活码", "verification", "code", "otp", "passcode")
    private val codeRegex = Regex("(?<![0-9])[0-9]{4,8}(?![0-9])")

    /** 找验证码：有「验证码」等关键词，并且有一串独立的 4~8 位数字 */
    fun verificationCode(lines: List<String>): String? {
        val text = lines.joinToString("\n")
        val lower = text.lowercase()
        if (codeKeywords.none { lower.contains(it) }) return null
        return codeRegex.find(text)?.value
    }

    // ---- 分类规则 ----

    /** 低质量：质量分（-1~1）低于此值 */
    const val LOW_QUALITY_SCORE = -0.3f

    fun isLowQuality(quality: Float?, isUtility: Boolean, isScreenshot: Boolean): Boolean {
        if (quality == null || isScreenshot || isUtility) return false
        return quality < LOW_QUALITY_SCORE
    }

    /** 过暗 / 过曝：排除截图、文档、文字图、二维码、长图（白底聊天长图曾被误判为过曝） */
    fun isPoorLight(
        brightness: Double, isScreenshot: Boolean, isUtility: Boolean, textHeavy: Boolean,
        tags: Set<ContentTag>, aspect: Double,
    ): Boolean {
        if (!(brightness < 35 || brightness > 240)) return false
        if (isScreenshot || isUtility || textHeavy || aspect >= 2.0) return false
        if (ContentTag.DOCUMENT in tags || ContentTag.QR_CODE in tags || ContentTag.SCREENSHOT_LIKE in tags) return false
        return true
    }

    // ---- 特征向量 ----

    fun normalized(v: FloatArray): FloatArray? {
        var s = 0f
        for (x in v) s += x * x
        if (s <= 0f || !s.isFinite()) return null
        val inv = 1f / sqrt(s)
        return FloatArray(v.size) { v[it] * inv }
    }

    /** 欧氏距离（输入应已归一化）。0 = 一模一样，最大 2 */
    fun distance(a: FloatArray, b: FloatArray): Float {
        val n = min(a.size, b.size)
        if (n == 0) return Float.POSITIVE_INFINITY
        var s = 0f
        for (i in 0 until n) {
            val d = a[i] - b[i]
            s += d * d
        }
        return sqrt(s)
    }
}

/**
 * 照片质量评分（-1~1）。
 * iOS 用的是苹果的「美观评分」模型；安卓上没有同等的本机模型，这里用清晰度、曝光、对比度近似。
 */
object QualityScore {
    fun score(sharpness: Double, brightness: Double, contrast: Double): Float {
        // 清晰度：拉普拉斯方差 20 以下很糊，300 以上很清楚（对数刻度）
        val s = ((ln10(max(1.0, sharpness)) - ln10(20.0)) / (ln10(300.0) - ln10(20.0))).coerceIn(0.0, 1.0)
        // 曝光：离 128 越远越差，60~200 之间不扣分
        val e = when {
            brightness < 60 -> (brightness / 60.0)
            brightness > 200 -> ((255 - brightness) / 55.0)
            else -> 1.0
        }.coerceIn(0.0, 1.0)
        // 对比度：标准差 15 以下发灰，45 以上正常
        val c = ((contrast - 15) / 30.0).coerceIn(0.0, 1.0)
        val total = 0.55 * s + 0.3 * e + 0.15 * c // 0..1
        return (total * 2 - 1).toFloat()
    }

    /** 人脸质量 0~1：双眼睁开概率 + 微笑概率（ML Kit 人脸检测） */
    fun face(leftEyeOpen: Float?, rightEyeOpen: Float?, smiling: Float?): Float? {
        if (leftEyeOpen == null && rightEyeOpen == null && smiling == null) return null
        val eyes = listOfNotNull(leftEyeOpen, rightEyeOpen).let { if (it.isEmpty()) 0.5f else it.average().toFloat() }
        val smile = smiling ?: 0.5f
        return (eyes * 0.7f + smile * 0.3f).coerceIn(0f, 1f)
    }

    private fun ln10(x: Double) = kotlin.math.log10(x)
}

class HashEntry(val id: String, val hash: Long, val time: Double?, val feature: FloatArray? = null)

data class BestCandidate(
    val faceQuality: Float? = null,
    val quality: Float? = null,
    val sharpness: Double,
    val pixels: Int,
)

/** 相似照片分组（并查集），规则与 iOS 版一致 */
object SimilarityGrouper {
    fun groups(
        entries: List<HashEntry>,
        strictThreshold: Int = 4,
        looseThreshold: Int = 10,
        timeWindow: Double = 180.0,
        featureNear: Float = 0.45f,
        featureDup: Float = 0.25f,
        dupPrefilter: Int = 20,
    ): List<List<String>> {
        val n = entries.size
        if (n < 2) return emptyList()
        val parent = IntArray(n) { it }
        fun find(i: Int): Int {
            var r = i
            while (parent[r] != r) r = parent[r]
            var c = i
            while (parent[c] != r) { val next = parent[c]; parent[c] = r; c = next }
            return r
        }
        fun union(a: Int, b: Int) {
            val ra = find(a); val rb = find(b)
            if (ra != rb) parent[rb] = ra
        }
        for (i in 0 until n - 1) {
            val hi = entries[i].hash
            val ti = entries[i].time
            val fi = entries[i].feature
            for (j in i + 1 until n) {
                val d = ImageMath.hamming(hi, entries[j].hash)
                if (d <= strictThreshold) { union(i, j); continue }
                val tj = entries[j].time
                val close = ti != null && tj != null && abs(ti - tj) <= timeWindow
                val fj = entries[j].feature
                if (fi != null && fj != null) {
                    if (!(close || d <= dupPrefilter)) continue
                    val f = VisionRules.distance(fi, fj)
                    if ((close && f <= featureNear) || f <= featureDup) union(i, j)
                } else if (close && d <= looseThreshold) {
                    union(i, j)
                }
            }
        }
        val buckets = LinkedHashMap<Int, MutableList<String>>()
        for (i in 0 until n) buckets.getOrPut(find(i)) { mutableListOf() }.add(entries[i].id)
        return buckets.values.filter { it.size > 1 }
            .sortedWith(compareByDescending<List<String>> { it.size }.thenBy { it[0] })
    }

    fun bestIndex(sharpness: List<Double>, pixels: List<Int>): Int =
        bestIndex(sharpness.zip(pixels).map { BestCandidate(sharpness = it.first, pixels = it.second) })

    /** 推荐保留：人脸质量 → 质量分 → 清晰度 → 分辨率；每一级差距明显时才决定 */
    fun bestIndex(c: List<BestCandidate>): Int {
        if (c.isEmpty()) return 0
        var best = 0
        for (i in 1 until c.size) if (isBetter(c[i], c[best])) best = i
        return best
    }

    fun isBetter(a: BestCandidate, b: BestCandidate): Boolean {
        val fa = a.faceQuality
        val fb = b.faceQuality
        if (fa != null && fb != null && abs(fa - fb) > 0.05f) return fa > fb
        if (fa != null && fb == null) return true
        if (fa == null && fb != null) return false
        val qa = a.quality
        val qb = b.quality
        if (qa != null && qb != null && abs(qa - qb) > 0.1f) return qa > qb
        if (a.sharpness > b.sharpness * 1.05) return true
        if (b.sharpness > a.sharpness * 1.05) return false
        return a.pixels > b.pixels
    }
}

object Fmt {
    /** 和 iOS ByteCountFormatter(.file) 一样按 1000 进位 */
    fun bytes(n: Long): String {
        val v = n.toDouble()
        return when {
            v >= 1e9 -> String.format(java.util.Locale.US, "%.2f GB", v / 1e9)
            v >= 1e6 -> String.format(java.util.Locale.US, "%.1f MB", v / 1e6)
            v >= 1e3 -> String.format(java.util.Locale.US, "%.0f KB", v / 1e3)
            n <= 0L -> "0 KB"
            else -> "1 KB"
        }
    }
}
