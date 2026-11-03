package com.yuanye.photocleaner.core

import com.yuanye.photocleaner.R

import kotlin.math.max
import kotlin.math.min

/** 单张图片的分析结果 */
data class AnalysisResult(
    val dHash: Long,
    val sharpness: Double,       // 拉普拉斯方差，越大越清晰
    val brightness: Double,      // 平均亮度 0..255
    val contrast: Double = 0.0,  // 亮度标准差
    // ---- AI（Google ML Kit + MediaPipe，本机运行）----
    val feature: ByteArray? = null,    // 特征向量（归一化后量化成 int8，省内存），AI 相似度
    val quality: Float? = null,        // 质量评分 -1~1（清晰度/曝光/对比度近似）
    val tags: Set<ContentTag> = emptySet(),
    val textChecked: Boolean = false,
    val textLines: Int = 0,
    val textChars: Int = 0,
    val verificationCode: String? = null,
    val faceQuality: Float? = null,    // 人脸质量 0~1（只对相似组里的照片计算）
    val faceChecked: Boolean = false,
    /** 动态照片（三星 / Google / 小米）里内嵌视频的字节数；0 = 不是动态照片 */
    val motionBytes: Long = 0,
    /** 主体标签：前 5 个、置信度 >= 0.3（相似分组看主体是否一致） */
    val labels: List<String>? = null,
    /** 人脸数（相似分组：人数相差超过 1 不算相似） */
    val faceCount: Int? = null,
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
    val name: String = "",          // 文件名（连拍识别用）
    val relativePath: String = "",  // 相册里的文件夹（压缩/转换后的新文件放回同一个文件夹）
    val mime: String = "",
) {
    val pixelCount: Int get() = width * height
    val aspect: Double get() = max(width, height).toDouble() / max(1, min(width, height)).toDouble()
}

enum class Decision { DELETE, KEEP }

enum class CleanCategory(val needsAnalysis: Boolean = true) {
    // 顺序就是首页 / 分类页的显示顺序（与 iOS 版一致）：先清理类，最后是「回顾」类
    SIMILAR,
    DUPLICATES(false),
    BURSTS(false),
    SCREENSHOTS(false),
    TEXT_IMAGES,
    DOCUMENTS,
    QR_CODES,
    LOW_QUALITY,
    BLURRY,
    POOR_LIGHT,
    MOTION,
    LARGE(false),
    VIDEOS(false),
    FOOD,
    PETS,
    SCENERY;

    /** 「回顾」类：不算进可清理空间 */
    val isBrowse: Boolean get() = this == FOOD || this == PETS || this == SCENERY

    /** 分组展示（每组留一张） */
    val isGrouped: Boolean get() = this == SIMILAR || this == DUPLICATES || this == BURSTS

    val titleRes: Int get() = when (this) {
        SIMILAR -> R.string.cat_similar
        DUPLICATES -> R.string.cat_duplicates
        BURSTS -> R.string.cat_bursts
        SCREENSHOTS -> R.string.cat_screenshots
        TEXT_IMAGES -> R.string.cat_text
        DOCUMENTS -> R.string.cat_documents
        QR_CODES -> R.string.cat_qr
        LOW_QUALITY -> R.string.cat_low_quality
        BLURRY -> R.string.cat_blurry
        POOR_LIGHT -> R.string.cat_poor_light
        MOTION -> R.string.cat_motion
        LARGE -> R.string.cat_large
        VIDEOS -> R.string.cat_videos
        FOOD -> R.string.cat_food
        PETS -> R.string.cat_pets
        SCENERY -> R.string.cat_scenery
    }

    val subtitleRes: Int get() = when (this) {
        SIMILAR -> R.string.cat_similar_sub
        DUPLICATES -> R.string.cat_duplicates_sub
        BURSTS -> R.string.cat_bursts_sub
        SCREENSHOTS -> R.string.cat_screenshots_sub
        TEXT_IMAGES -> R.string.cat_text_sub
        DOCUMENTS -> R.string.cat_documents_sub
        QR_CODES -> R.string.cat_qr_sub
        LOW_QUALITY -> R.string.cat_low_quality_sub
        BLURRY -> R.string.cat_blurry_sub
        POOR_LIGHT -> R.string.cat_poor_light_sub
        MOTION -> R.string.cat_motion_sub
        LARGE -> R.string.cat_large_sub
        VIDEOS -> R.string.cat_videos_sub
        FOOD -> R.string.cat_food_sub
        PETS -> R.string.cat_pets_sub
        SCENERY -> R.string.cat_scenery_sub
    }
}

/** 卡片上的小标签（界面再翻译成文字） */
enum class TagKind { SCREENSHOT, VIDEO, CODE, QR, DOCUMENT, TEXT, BLURRY, DARK, BRIGHT, LOW_QUALITY, MOTION }
data class CardTag(val kind: TagKind, val arg: String? = null)

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
        duplicateGroups: List<List<String>> = emptyList(), burstGroups: List<List<String>> = emptyList(),
    ): Map<CleanCategory, List<String>> {
        val largeBytes = (largeFileMB * 1_000_000).toLong()
        val pool = items.filter { !it.isFavorite }
        val photos = pool.filter { !it.isVideo }
        fun tag(t: ContentTag) = photos.filter { !it.isScreenshot && it.analysis?.tags?.contains(t) == true }.map { it.id }
        val m = LinkedHashMap<CleanCategory, List<String>>()
        m[CleanCategory.SIMILAR] = similarGroups.flatten()
        m[CleanCategory.DUPLICATES] = duplicateGroups.flatten()
        m[CleanCategory.BURSTS] = burstGroups.flatten()
        m[CleanCategory.SCREENSHOTS] = pool.filter { it.isScreenshot }.map { it.id }
        m[CleanCategory.TEXT_IMAGES] = photos.filter { isTextImage(it) }.map { it.id }
        m[CleanCategory.DOCUMENTS] = photos.filter { isDocument(it) }.map { it.id }
        m[CleanCategory.QR_CODES] = photos.filter { it.analysis?.tags?.contains(ContentTag.QR_CODE) == true }.map { it.id }
        m[CleanCategory.LOW_QUALITY] = photos.filter { isLowQuality(it) }
            .sortedBy { it.analysis?.quality ?: 0f }.map { it.id }
        m[CleanCategory.BLURRY] = photos.filter { isBlurry(it, blurThreshold) }
            .sortedBy { it.analysis?.sharpness ?: 0.0 }.map { it.id }
        m[CleanCategory.POOR_LIGHT] = photos.filter { isPoorLight(it) }.map { it.id }
        m[CleanCategory.MOTION] = photos.filter { (it.analysis?.motionBytes ?: 0) > 0 }
            .sortedByDescending { it.analysis?.motionBytes ?: 0 }.map { it.id }
        m[CleanCategory.LARGE] = photos.filter { it.fileSize >= largeBytes }.sortedByDescending { it.fileSize }.map { it.id }
        m[CleanCategory.VIDEOS] = pool.filter { it.isVideo }.sortedByDescending { it.fileSize }.map { it.id }
        m[CleanCategory.FOOD] = tag(ContentTag.FOOD)
        m[CleanCategory.PETS] = tag(ContentTag.PET)
        m[CleanCategory.SCENERY] = tag(ContentTag.SCENERY)
        // 按首页顺序排好
        return CleanCategory.entries.associateWithTo(LinkedHashMap()) { m[it] ?: emptyList() }
    }

    /** 滑动卡片上的小标签（最多 4 个） */
    fun cardTags(item: PhotoItem, blurThreshold: Double): List<CardTag> {
        val t = mutableListOf<CardTag>()
        if (item.isScreenshot) t += CardTag(TagKind.SCREENSHOT)
        if (item.isVideo) t += CardTag(TagKind.VIDEO)
        val a = item.analysis
        if (a != null) {
            a.verificationCode?.let { t += CardTag(TagKind.CODE, it) }
            if (ContentTag.QR_CODE in a.tags) t += CardTag(TagKind.QR)
            if (ContentTag.DOCUMENT in a.tags) t += CardTag(TagKind.DOCUMENT)
            if (a.textHeavy && !item.isScreenshot) t += CardTag(TagKind.TEXT)
            if (isBlurry(item, blurThreshold)) t += CardTag(TagKind.BLURRY)
            if (isPoorLight(item)) t += CardTag(if (a.brightness < 35) TagKind.DARK else TagKind.BRIGHT)
            if (isLowQuality(item)) t += CardTag(TagKind.LOW_QUALITY)
            if (a.motionBytes > 0) t += CardTag(TagKind.MOTION)
        }
        return t.take(4)
    }
}

enum class SwipeAction { DELETE, KEEP, LATER }

/**
 * 判定一次拖动算不算「滑走」：
 *  - 水平为主（|dx| > 1.5|dy|）且超过阈值：左 = 删除，右 = 保留
 *  - 向上为主（-dy > 1.5|dx|）且超过阈值：稍后再看
 *  - 快速甩：至少拖了 flickMinPx（默认阈值的 60/110），并且「当前位置 + 速度 × 0.2 秒」的预测落点越过阈值、
 *    方向同样明显且同向，也算数
 * vx / vy：松手时的速度（px/秒）
 */
fun swipeAction(
    dx: Float, dy: Float, thresholdPx: Float,
    vx: Float = 0f, vy: Float = 0f,
    flickMinPx: Float = thresholdPx * 60f / 110f,
): SwipeAction? {
    val ax = kotlin.math.abs(dx)
    val ay = kotlin.math.abs(dy)
    val px = dx + vx * FLING_PROJECT_SECONDS
    val py = dy + vy * FLING_PROJECT_SECONDS
    val apx = kotlin.math.abs(px)
    val apy = kotlin.math.abs(py)
    if (ax > 1.5f * ay) {
        val flick = ax >= flickMinPx && apx > 1.5f * apy && apx >= thresholdPx && (px < 0) == (dx < 0)
        if (ax >= thresholdPx || flick) return if (dx < 0) SwipeAction.DELETE else SwipeAction.KEEP
    } else if (dy < 0 && ay > 1.5f * ax) {
        val flick = ay >= flickMinPx && apy > 1.5f * apx && py <= -thresholdPx
        if (ay >= thresholdPx || flick) return SwipeAction.LATER
    }
    return null
}

/** 按速度预测落点时往前推的时间（秒），和 iOS 的 predictedEndTranslation 差不多 */
const val FLING_PROJECT_SECONDS = 0.2f
