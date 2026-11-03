package com.yuanye.photocleaner.core

import kotlin.math.max
import kotlin.math.min

/** 单张图片的分析结果 */
data class AnalysisResult(
    val dHash: Long,
    val sharpness: Double,       // 拉普拉斯方差，越大越清晰
    val brightness: Double,      // 平均亮度 0..255
    val contrast: Double = 0.0,  // 亮度标准差
    // ---- AI（Google ML Kit + MediaPipe，本机运行）----
    val feature: FloatArray? = null,   // 特征向量（已归一化），AI 相似度
    val quality: Float? = null,        // 质量评分 -1~1（清晰度/曝光/对比度近似）
    val tags: Set<ContentTag> = emptySet(),
    val textChecked: Boolean = false,
    val textLines: Int = 0,
    val textChars: Int = 0,
    val verificationCode: String? = null,
    val faceQuality: Float? = null,    // 人脸质量 0~1（只对相似组里的照片计算）
    val faceChecked: Boolean = false,
) {
    val textHeavy: Boolean get() = VisionRules.isTextHeavy(textLines, textChars)

    /** 工具性照片：文档、二维码、看起来像截图（对应 iOS 18 的 isUtility） */
    val isUtility: Boolean
        get() = ContentTag.DOCUMENT in tags || ContentTag.QR_CODE in tags || ContentTag.SCREENSHOT_LIKE in tags
}

/** 相册里的一项（照片或视频） */
data class PhotoItem(
    val id: String,          // MediaStore _ID
    val uri: String,         // content:// 地址
    val fileSize: Long,
    val dateMillis: Long?,
    val isVideo: Boolean,
    val isScreenshot: Boolean,
    val isFavorite: Boolean,
    val width: Int,
    val height: Int,
    val dateModified: Long = 0,
    val analysis: AnalysisResult? = null,
) {
    val pixelCount: Int get() = width * height
    val aspect: Double get() = max(width, height).toDouble() / max(1, min(width, height)).toDouble()
}

enum class Decision { DELETE, KEEP }

enum class CleanCategory(val title: String, val subtitle: String, val needsAnalysis: Boolean = true) {
    // 顺序就是首页 / 分类页的显示顺序：先清理类，最后是「回顾」类
    SIMILAR("相似照片", "连拍和重复，留一张最好的"),
    SCREENSHOTS("截图", "聊天记录、验证码截图", false),
    TEXT_IMAGES("文字图片", "聊天记录、长图、验证码"),
    DOCUMENTS("文档/票据", "票据、文件、证件照片"),
    QR_CODES("二维码", "用过的付款码、海报二维码"),
    LOW_QUALITY("低质量照片", "质量评分很低的照片"),
    BLURRY("模糊照片", "手抖、失焦的照片"),
    POOR_LIGHT("过暗/过曝", "太黑或太亮，基本看不清"),
    LARGE("大文件", "占空间最多的照片", false),
    VIDEOS("视频", "按大小排序的视频", false),
    FOOD("美食", "吃过的美食，留几张就够"),
    PETS("宠物", "猫猫狗狗，挑出拍废的"),
    SCENERY("风景", "风景照，挑出重复的");

    /** 「回顾」类：不算进可清理空间 */
    val isBrowse: Boolean get() = this == FOOD || this == PETS || this == SCENERY
}

/** 分类规则（滑动卡片上的小标签也用这些） */
object CategoryRules {
    fun isBlurry(item: PhotoItem, threshold: Double): Boolean {
        val a = item.analysis ?: return false
        if (item.isScreenshot || ContentTag.QR_CODE in a.tags) return false
        return a.sharpness < threshold
    }

    fun isPoorLight(item: PhotoItem): Boolean {
        val a = item.analysis ?: return false
        return VisionRules.isPoorLight(a.brightness, item.isScreenshot, a.isUtility, a.textHeavy, a.tags, item.aspect)
    }

    fun isLowQuality(item: PhotoItem): Boolean {
        val a = item.analysis ?: return false
        return VisionRules.isLowQuality(a.quality, a.isUtility, item.isScreenshot)
    }

    fun isDocument(item: PhotoItem): Boolean {
        val a = item.analysis ?: return false
        if (item.isScreenshot) return false
        return ContentTag.DOCUMENT in a.tags
    }

    fun isTextImage(item: PhotoItem): Boolean {
        val a = item.analysis ?: return false
        if (a.verificationCode != null) return true
        return !item.isScreenshot && a.textHeavy && ContentTag.DOCUMENT !in a.tags
    }

    /** 按分类整理（收藏的永远不进任何分类） */
    fun build(
        items: List<PhotoItem>, similarGroups: List<List<String>>, blurThreshold: Double, largeFileMB: Double,
    ): Map<CleanCategory, List<String>> {
        val largeBytes = (largeFileMB * 1_000_000).toLong()
        val pool = items.filter { !it.isFavorite }
        val photos = pool.filter { !it.isVideo }
        fun tag(t: ContentTag) = photos.filter { !it.isScreenshot && it.analysis?.tags?.contains(t) == true }.map { it.id }
        val m = LinkedHashMap<CleanCategory, List<String>>()
        m[CleanCategory.SIMILAR] = similarGroups.flatten()
        m[CleanCategory.SCREENSHOTS] = pool.filter { it.isScreenshot }.map { it.id }
        m[CleanCategory.TEXT_IMAGES] = photos.filter { isTextImage(it) }.map { it.id }
        m[CleanCategory.DOCUMENTS] = photos.filter { isDocument(it) }.map { it.id }
        m[CleanCategory.QR_CODES] = photos.filter { it.analysis?.tags?.contains(ContentTag.QR_CODE) == true }.map { it.id }
        m[CleanCategory.LOW_QUALITY] = photos.filter { isLowQuality(it) }
            .sortedBy { it.analysis?.quality ?: 0f }.map { it.id }
        m[CleanCategory.BLURRY] = photos.filter { isBlurry(it, blurThreshold) }
            .sortedBy { it.analysis?.sharpness ?: 0.0 }.map { it.id }
        m[CleanCategory.POOR_LIGHT] = photos.filter { isPoorLight(it) }.map { it.id }
        m[CleanCategory.LARGE] = photos.filter { it.fileSize >= largeBytes }.sortedByDescending { it.fileSize }.map { it.id }
        m[CleanCategory.VIDEOS] = pool.filter { it.isVideo }.sortedByDescending { it.fileSize }.map { it.id }
        m[CleanCategory.FOOD] = tag(ContentTag.FOOD)
        m[CleanCategory.PETS] = tag(ContentTag.PET)
        m[CleanCategory.SCENERY] = tag(ContentTag.SCENERY)
        return m
    }

    /** 滑动卡片上的小标签（最多 4 个） */
    fun cardTags(item: PhotoItem, blurThreshold: Double): List<String> {
        val t = mutableListOf<String>()
        if (item.isScreenshot) t += "截图"
        if (item.isVideo) t += "视频"
        val a = item.analysis
        if (a != null) {
            a.verificationCode?.let { t += "验证码 $it" }
            if (ContentTag.QR_CODE in a.tags) t += "二维码"
            if (ContentTag.DOCUMENT in a.tags) t += "文档"
            if (a.textHeavy && !item.isScreenshot) t += "文字多"
            if (isBlurry(item, blurThreshold)) t += "模糊"
            if (isPoorLight(item)) t += if (a.brightness < 35) "过暗" else "过曝"
            if (isLowQuality(item)) t += "低质量"
        }
        return t.take(4)
    }
}

/** 判定一次拖动是否算「滑走」：水平为主（|dx| > 1.5|dy|）且超过阈值。左 = 删除，右 = 保留 */
fun swipeDecision(dx: Float, dy: Float, thresholdPx: Float): Decision? {
    if (kotlin.math.abs(dx) < thresholdPx || kotlin.math.abs(dx) <= 1.5f * kotlin.math.abs(dy)) return null
    return if (dx < 0) Decision.DELETE else Decision.KEEP
}
