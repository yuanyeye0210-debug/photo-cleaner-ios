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

    /** 文档 / 票据：>= 0.6；文字很多时放宽到 0.5 */
    const val DOCUMENT_CONFIDENCE = 0.6f
    const val DOCUMENT_TEXT_CONFIDENCE = 0.5f
    /** 美食 / 宠物 / 风景：>= 0.7，并且必须是最主要的标签（跳过 genericLabels 这类大类后排第一） */
    const val FOOD_CONFIDENCE = 0.7f
    const val PET_CONFIDENCE = 0.7f
    const val SCENERY_CONFIDENCE = 0.7f
    const val SCREENSHOT_CONFIDENCE = 0.5f
    const val PEOPLE_CONFIDENCE = 0.5f
    /** 相似分组用的主体标签：前 5 个、置信度 >= 0.3 */
    const val SUBJECT_LABEL_COUNT = 5
    const val SUBJECT_LABEL_CONFIDENCE = 0.3f
    /** ML Kit 里很泛、几乎什么图都会有的标签，判断「主要标签」时跳过 */
    val genericLabels = setOf(
        "fun", "event", "cool", "pattern", "leisure", "vacation", "sitting", "standing", "room", "flora", "plant",
        "sky", "cloud", "water", "nail", "hand", "pet",
    )

    private fun sortedLabels(labels: List<Pair<String, Float>>) =
        labels.map { it.first.lowercase() to it.second }.sortedWith(compareByDescending<Pair<String, Float>> { it.second }.thenBy { it.first })

    /** 按置信度排序后，跳过大类，第一个具体标签（小写） */
    fun topSpecificLabel(labels: List<Pair<String, Float>>): String? =
        sortedLabels(labels).firstOrNull { it.first !in genericLabels }?.first

    /** 相似分组用：前 5 个置信度 >= 0.3 的标签（小写） */
    fun subjectLabels(labels: List<Pair<String, Float>>): List<String> =
        sortedLabels(labels).filter { it.second >= SUBJECT_LABEL_CONFIDENCE }.take(SUBJECT_LABEL_COUNT).map { it.first }

    /** 二维码只看真正读出内容的条码（hasQR），不看分类标签 */
    fun tags(labels: List<Pair<String, Float>>, hasQR: Boolean, textHeavy: Boolean = false): Set<ContentTag> {
        val conf = HashMap<String, Float>()
        for ((id, c) in labels) {
            val k = id.lowercase()
            conf[k] = max(conf[k] ?: 0f, c)
        }
        fun maxConf(set: Set<String>): Float = set.fold(0f) { acc, s -> max(acc, conf[s] ?: 0f) }
        val top = topSpecificLabel(labels)
        fun isTop(set: Set<String>) = top != null && top in set
        val out = mutableSetOf<ContentTag>()
        if (hasQR) out += ContentTag.QR_CODE
        if (maxConf(documentLabels) >= (if (textHeavy) DOCUMENT_TEXT_CONFIDENCE else DOCUMENT_CONFIDENCE)) out += ContentTag.DOCUMENT
        if (maxConf(foodLabels) >= FOOD_CONFIDENCE && isTop(foodLabels)) out += ContentTag.FOOD
        if (maxConf(petLabels) >= PET_CONFIDENCE && isTop(petLabels)) out += ContentTag.PET
        val hasPeople = maxConf(peopleLabels) >= PEOPLE_CONFIDENCE
        if (!hasPeople && maxConf(sceneryLabels) >= SCENERY_CONFIDENCE && isTop(sceneryLabels)) out += ContentTag.SCENERY
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

    /** 归一化向量量化成 int8（每维 1 字节，内存只要 float 的 1/4） */
    fun quantize(v: FloatArray): ByteArray =
        ByteArray(v.size) { (v[it] * 127f).roundToInt().coerceIn(-127, 127).toByte() }

    /** 量化向量的欧氏距离（约等于原始归一化向量的距离） */
    fun distance(a: ByteArray, b: ByteArray): Float {
        val n = min(a.size, b.size)
        if (n == 0) return Float.POSITIVE_INFINITY
        var s = 0L
        for (i in 0 until n) {
            val d = a[i] - b[i]
            s += d * d
        }
        return (sqrt(s.toDouble()) / 127.0).toFloat()
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

class HashEntry(
    val id: String, val hash: Long, val time: Double?, val feature: ByteArray? = null,
    /** 长边/短边（>= 1）；null = 不知道 */
    val aspect: Double? = null,
    /** 识别标签（前 5 个，置信度 >= 0.3）；null 或空 = 不知道 */
    val labels: List<String>? = null,
    /** 人脸数；null = 不知道 */
    val faces: Int? = null,
) {
    companion object {
        fun aspect(width: Int, height: Int): Double? =
            if (width <= 0 || height <= 0) null else max(width, height).toDouble() / min(width, height)
    }
}

/** 「不是相似」的照片对：两个 id 排序后用 | 连起来 */
object PairKey {
    fun make(a: String, b: String): String = if (a < b) "$a|$b" else "$b|$a"
    fun ids(key: String): Pair<String, String>? {
        val i = key.indexOf('|')
        return if (i <= 0 || i == key.length - 1) null else key.substring(0, i) to key.substring(i + 1)
    }
}

/**
 * 相似分组的阈值（和 iOS 版 GroupingParams 一致；特征距离按安卓的 MobileNetV3 特征单独标定）
 *  - strict：dHash ≤ 4 直接算重复
 *  - 同一次连拍：时间相差 ≤ 90 秒 且 特征距离 ≤ near，并且主体一致（dHash ≤ 16 或 标签 Jaccard ≥ 0.25）、
 *    人数相差 ≤ 1、长宽比相差 ≤ 1.4 倍
 *  - 重复图（裁剪/压缩/存了两次）：特征距离 ≤ dup，不看时间和比例
 */
data class GroupingParams(
    val strict: Int = 4,
    val loose: Int = 10,
    val timeWindow: Double = 90.0,
    val featureNear: Float = 0.35f,
    val featureDup: Float = 0.25f,
    val dupPrefilter: Int = 20,
    val subjectHash: Int = 16,
    val labelJaccard: Double = 0.25,
    val aspectRatioMax: Double = 1.4,
    val maxFaceDiff: Int = 1,
)

data class BestCandidate(
    val faceQuality: Float? = null,
    val quality: Float? = null,
    val sharpness: Double,
    val pixels: Int,
)

/**
 * 相似照片分组（完全连接：组里任意两张都相似），规则与 iOS 版一致。
 * 快速版：不再两两比较全部照片（n² 次），只比较
 *  1) 按拍摄时间排序后、时间窗口内的照片；
 *  2) dHash 分 8 段、任一段完全相同的照片（汉明距离 ≤ 7 一定会碰上）；
 *  3) AI 特征的随机投影桶（LSH）相同的照片（找时间相隔很久的重复图）。
 * 候选配对再用 [link] 判定、[merge] 合并，结果和暴力版 [groupsBruteForce] 相同。
 */
object SimilarityGrouper {
    private const val BANDS = 8
    private const val LSH_TABLES = 8
    private const val LSH_BITS = 10
    private const val LSH_NONZERO = 48
    /** 桶太大（比如大量纯黑图 dHash 都一样）时只和按时间相邻的若干张比较，避免退化成 n² */
    private const val BIG_BUCKET = 400
    private const val BIG_BUCKET_NEIGHBORS = 40

    fun jaccard(a: List<String>, b: List<String>): Double {
        val x = a.toSet(); val y = b.toSet()
        val u = (x + y).size
        return if (u == 0) 0.0 else (x intersect y).size.toDouble() / u
    }

    /** 两张照片能不能放进同一组；null = 不能，否则是「距离」（越小越像，决定合并顺序） */
    fun link(a: HashEntry, b: HashEntry, p: GroupingParams = GroupingParams()): Float? {
        val d = ImageMath.hamming(a.hash, b.hash)
        if (d <= p.strict) return d / 64f
        val ta = a.time; val tb = b.time
        val close = ta != null && tb != null && abs(ta - tb) <= p.timeWindow
        val xa = a.aspect; val xb = b.aspect
        val aspectOK = xa == null || xb == null || max(xa, xb) / max(min(xa, xb), 0.0001) <= p.aspectRatioMax
        val fa = a.feature; val fb = b.feature
        if (fa != null && fb != null) {
            if (!(close || d <= p.dupPrefilter)) return null
            val f = VisionRules.distance(fa, fb)
            if (f <= p.featureDup) return f                       // 重复图
            if (!close || !aspectOK || f > p.featureNear) return null
            val na = a.faces; val nb = b.faces
            if (na != null && nb != null && abs(na - nb) > p.maxFaceDiff) return null
            var subject = d <= p.subjectHash
            val la = a.labels; val lb = b.labels
            if (!subject && !la.isNullOrEmpty() && !lb.isNullOrEmpty()) subject = jaccard(la, lb) >= p.labelJaccard
            return if (subject) f else null
        }
        return if (close && aspectOK && d <= p.loose) d / 64f else null
    }

    fun groups(
        entries: List<HashEntry>,
        p: GroupingParams = GroupingParams(),
        excluded: Set<String> = emptySet(),
    ): List<List<String>> {
        val n = entries.size
        if (n < 2) return emptyList()
        val seen = HashSet<Long>()
        val edges = ArrayList<Edge>()
        fun check(i0: Int, j0: Int) {
            if (i0 == j0) return
            val i = min(i0, j0); val j = max(i0, j0)
            if (!seen.add(i.toLong() shl 32 or j.toLong())) return
            if (excluded.isNotEmpty() && PairKey.make(entries[i].id, entries[j].id) in excluded) return
            link(entries[i], entries[j], p)?.let { edges += Edge(it, i, j) }
        }
        val byTime = (0 until n).filter { entries[it].time != null }.sortedBy { entries[it].time!! }
        // 1) 时间窗口
        for (a in byTime.indices) {
            val ta = entries[byTime[a]].time!!
            var b = a + 1
            while (b < byTime.size && entries[byTime[b]].time!! - ta <= p.timeWindow) {
                check(byTime[a], byTime[b]); b++
            }
        }
        val timeRank = IntArray(n) { Int.MAX_VALUE }
        byTime.forEachIndexed { r, i -> timeRank[i] = r }
        fun compareBucket(members: List<Int>) {
            if (members.size < 2) return
            if (members.size <= BIG_BUCKET) {
                for (x in 0 until members.size - 1) for (y in x + 1 until members.size) check(members[x], members[y])
            } else {
                val sorted = members.sortedBy { timeRank[it] }
                for (x in sorted.indices) {
                    for (y in x + 1 until minOf(sorted.size, x + 1 + BIG_BUCKET_NEIGHBORS)) check(sorted[x], sorted[y])
                }
            }
        }
        // 2) dHash 分段
        for (band in 0 until BANDS) {
            val buckets = HashMap<Int, MutableList<Int>>()
            for (i in 0 until n) {
                val key = ((entries[i].hash ushr (band * 8)) and 0xFF).toInt()
                buckets.getOrPut(key) { ArrayList() }.add(i)
            }
            buckets.values.forEach { compareBucket(it) }
        }
        // 3) AI 特征随机投影桶
        val withFeature = (0 until n).filter { entries[it].feature != null }
        if (withFeature.size >= 2) {
            val dim = withFeature.maxOf { entries[it].feature!!.size }
            val planes = Planes.get(dim)
            for (t in 0 until LSH_TABLES) {
                val buckets = HashMap<Int, MutableList<Int>>()
                for (i in withFeature) {
                    buckets.getOrPut(planes.signature(entries[i].feature!!, t)) { ArrayList() }.add(i)
                }
                buckets.values.forEach { compareBucket(it) }
            }
        }
        return merge(entries, edges, p, excluded)
    }

    private class Edge(val w: Float, val i: Int, val j: Int)

    /**
     * 完全连接合并：按距离从小到大处理配对，两组只有在「所有跨组配对都相似」时才合并。
     * 所以每组里任意两张都彼此相似，不会 A 像 B、B 像 C 就把 A 和 C 串到一组。
     */
    private fun merge(entries: List<HashEntry>, edges: List<Edge>, p: GroupingParams, excluded: Set<String>): List<List<String>> {
        val sorted = edges.sortedWith(compareBy<Edge> { it.w }.thenBy { it.i }.thenBy { it.j })
        val cluster = IntArray(entries.size) { it }
        val members = HashMap<Int, MutableList<Int>>()
        fun ok(i: Int, j: Int): Boolean {
            if (excluded.isNotEmpty() && PairKey.make(entries[i].id, entries[j].id) in excluded) return false
            return link(entries[i], entries[j], p) != null
        }
        for (e in sorted) {
            val ci = cluster[e.i]; val cj = cluster[e.j]
            if (ci == cj) continue
            val a = members[ci] ?: listOf(ci)
            val b = members[cj] ?: listOf(cj)
            val all = a.all { x -> b.all { y -> ok(x, y) } }
            if (!all) continue
            val (keep, drop) = if (a.size >= b.size) ci to cj else cj to ci
            val moved = members.remove(drop) ?: mutableListOf(drop)
            for (m in moved) cluster[m] = keep
            members.getOrPut(keep) { mutableListOf(keep) }.addAll(moved)
        }
        return members.values.filter { it.size > 1 }
            .map { g -> g.map { entries[it].id }.sorted() }
            .sortedWith(compareByDescending<List<String>> { it.size }.thenBy { it[0] })
    }

    /** 稀疏随机超平面（固定种子，每次结果一样） */
    private class Planes(dim: Int) {
        private val idx = Array(LSH_TABLES * LSH_BITS) { IntArray(LSH_NONZERO) }
        private val sign = Array(LSH_TABLES * LSH_BITS) { BooleanArray(LSH_NONZERO) }

        init {
            val rnd = java.util.Random(0x5EEDL + dim)
            for (p in idx.indices) for (k in 0 until LSH_NONZERO) {
                idx[p][k] = rnd.nextInt(maxOf(1, dim))
                sign[p][k] = rnd.nextBoolean()
            }
        }

        fun signature(f: ByteArray, table: Int): Int {
            var sig = 0
            for (b in 0 until LSH_BITS) {
                val p = table * LSH_BITS + b
                var s = 0
                val ix = idx[p]
                val sg = sign[p]
                for (k in 0 until LSH_NONZERO) {
                    val j = ix[k]
                    if (j < f.size) { val v = f[j].toInt(); s += if (sg[k]) v else -v }
                }
                if (s >= 0) sig = sig or (1 shl b)
            }
            return sig
        }

        companion object {
            private val cache = HashMap<Int, Planes>()
            @Synchronized fun get(dim: Int): Planes = cache.getOrPut(dim) { Planes(dim) }
        }
    }

    /** 暴力版（两两比较），只用于单元测试对照 */
    fun groupsBruteForce(
        entries: List<HashEntry>,
        p: GroupingParams = GroupingParams(),
        excluded: Set<String> = emptySet(),
    ): List<List<String>> {
        val n = entries.size
        if (n < 2) return emptyList()
        val edges = ArrayList<Edge>()
        for (i in 0 until n - 1) for (j in i + 1 until n) {
            if (excluded.isNotEmpty() && PairKey.make(entries[i].id, entries[j].id) in excluded) continue
            link(entries[i], entries[j], p)?.let { edges += Edge(it, i, j) }
        }
        return merge(entries, edges, p, excluded)
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
