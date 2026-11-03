package com.yuanye.photocleaner.core

import org.junit.Assert.*
import org.junit.Test

class CategoryRulesTest {
    private fun photo(id: String, a: AnalysisResult? = null, size: Long = 1_000_000, shot: Boolean = false, fav: Boolean = false,
                      video: Boolean = false, w: Int = 4000, h: Int = 3000) =
        PhotoItem(id, "content://x/$id", size, 0, video, shot, fav, w, h, 0, a)

    private fun an(sharp: Double = 200.0, bright: Double = 120.0, q: Float? = 0.5f, tags: Set<ContentTag> = emptySet(),
                   lines: Int = 0, code: String? = null) =
        AnalysisResult(0, sharp, bright, 40.0, null, q, tags, true, lines, 0, code)

    @Test fun buildCategories() {
        val items = listOf(
            photo("blur", an(sharp = 10.0)),
            photo("dark", an(bright = 10.0)),
            photo("white_long", an(bright = 250.0), w = 1170, h = 6000),     // 白底长图：不算过曝
            photo("fav_blur", an(sharp = 5.0), fav = true),                   // 收藏：不进任何分类
            photo("shot", an(sharp = 5.0), shot = true),                      // 截图：不算模糊
            photo("code", an(code = "123456")),
            photo("doc", an(tags = setOf(ContentTag.DOCUMENT), q = -0.9f)),   // 文档：不算低质量
            photo("ugly", an(q = -0.8f)),
            photo("big", an(), size = 20_000_000),
            photo("food", an(tags = setOf(ContentTag.FOOD))),
            photo("vid", null, size = 50_000_000, video = true),
        )
        val m = CategoryRules.build(items, listOf(listOf("blur", "dark")), 60.0, 8.0)
        assertEquals(listOf("blur"), m[CleanCategory.BLURRY])
        assertEquals(listOf("dark"), m[CleanCategory.POOR_LIGHT])
        assertEquals(listOf("shot"), m[CleanCategory.SCREENSHOTS])
        assertEquals(listOf("code"), m[CleanCategory.TEXT_IMAGES])
        assertEquals(listOf("doc"), m[CleanCategory.DOCUMENTS])
        assertEquals(listOf("ugly"), m[CleanCategory.LOW_QUALITY])
        assertEquals(listOf("big"), m[CleanCategory.LARGE])
        assertEquals(listOf("vid"), m[CleanCategory.VIDEOS])
        assertEquals(listOf("food"), m[CleanCategory.FOOD])
        assertEquals(listOf("blur", "dark"), m[CleanCategory.SIMILAR])
        assertTrue(m.values.none { "fav_blur" in it })
        assertTrue(CleanCategory.FOOD.isBrowse && !CleanCategory.BLURRY.isBrowse)
    }

    @Test fun cardTags() {
        val t = CategoryRules.cardTags(photo("x", an(sharp = 10.0, bright = 10.0, code = "4821")), 60.0)
        assertEquals(listOf("验证码 4821", "模糊", "过暗"), t)
        assertTrue(CategoryRules.cardTags(photo("y", an(), shot = true), 60.0).contains("截图"))
    }

    @Test fun qualityScore() {
        val good = QualityScore.score(400.0, 128.0, 60.0)
        val bad = QualityScore.score(5.0, 15.0, 5.0)
        assertTrue(good > 0.9f)
        assertTrue(bad < VisionRules.LOW_QUALITY_SCORE)
        assertEquals(1f, QualityScore.face(1f, 1f, 1f)!!, 1e-6f)
        assertNull(QualityScore.face(null, null, null))
        assertTrue(QualityScore.face(0.1f, 0.1f, 0.9f)!! < QualityScore.face(0.9f, 0.9f, 0.1f)!!)
    }

    @Test fun swipeDirection() {
        assertEquals(Decision.DELETE, swipeDecision(-200f, 20f, 110f))   // 左滑 = 删除
        assertEquals(Decision.KEEP, swipeDecision(200f, -20f, 110f))     // 右滑 = 保留
        assertNull(swipeDecision(-100f, 0f, 110f))                       // 没过阈值
        assertNull(swipeDecision(-200f, 150f, 110f))                     // 斜着拖（竖直分量太大）
    }

    @Test fun bytesFormat() {
        assertEquals("1.50 GB", Fmt.bytes(1_500_000_000))
        assertEquals("12.3 MB", Fmt.bytes(12_300_000))
        assertEquals("900 KB", Fmt.bytes(900_000))
    }
}
