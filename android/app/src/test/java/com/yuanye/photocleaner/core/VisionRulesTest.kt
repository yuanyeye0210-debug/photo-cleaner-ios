package com.yuanye.photocleaner.core

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.sqrt

/** 从 iOS 版 VisionRulesTests 移植（标签换成 ML Kit 的） */
class VisionRulesTest {
    private fun unit(vararg v: Float) = VisionRules.normalized(v)!!
    private fun q(vararg v: Float) = VisionRules.quantize(unit(*v))

    @Test fun normalizedAndDistance() {
        val a = unit(3f, 4f)
        assertEquals(0.6f, a[0], 1e-6f); assertEquals(0.8f, a[1], 1e-6f)
        assertNull(VisionRules.normalized(floatArrayOf(0f, 0f)))
        assertEquals(0f, VisionRules.distance(a, a), 1e-6f)
        assertEquals(sqrt(2f), VisionRules.distance(unit(1f, 0f), unit(0f, 1f)), 1e-5f)
        // 量化后距离误差很小
        assertEquals(sqrt(2f), VisionRules.distance(q(1f, 0f), q(0f, 1f)), 1e-3f)
        assertEquals(VisionRules.distance(unit(1f, 0.2f, 0f), unit(1f, 0.3f, 0f)),
            VisionRules.distance(q(1f, 0.2f, 0f), q(1f, 0.3f, 0f)), 0.01f)
    }

    @Test fun aiGroupingUsesFeaturesWithinTimeWindow() {
        val base = 0xF0F0F0F00F0F0F0FUL.toLong()
        val entries = listOf(
            HashEntry("a", base, 1000.0, q(1f, 0.2f, 0f)),
            HashEntry("b", base xor 0xFFFFFFFFL, 1030.0, q(1f, 0.3f, 0f)),
            HashEntry("c", base xor 0xFF0000000000L, 1010.0, q(0f, 0f, 1f)),
            HashEntry("d", base xor 0x3FF, 9_000_000.0, q(1f, 0.21f, 0f)),
            HashEntry("e", base.inv(), 5_000_000.0, q(1f, 0.2f, 0f)),
        )
        val g = SimilarityGrouper.groups(entries)
        assertEquals(1, g.size)
        assertEquals(setOf("a", "b", "d"), g[0].toSet())
    }

    @Test fun bestIndexPrefersFaceThenQuality() {
        val c = listOf(
            BestCandidate(0.3f, 0.5f, 500.0, 100),
            BestCandidate(0.8f, 0.1f, 100.0, 100),
            BestCandidate(0.82f, 0.4f, 100.0, 100),
        )
        assertEquals(2, SimilarityGrouper.bestIndex(c))
        assertEquals(1, SimilarityGrouper.bestIndex(listOf(BestCandidate(null, 0.1f, 300.0, 100), BestCandidate(null, 0.6f, 100.0, 100))))
    }

    @Test fun contentTags() {
        val t = VisionRules.tags(listOf("Food" to 0.9f, "Dog" to 0.3f, "Receipt" to 0.7f, "unknown_xyz" to 0.99f), hasQR = true)
        assertEquals(setOf(ContentTag.FOOD, ContentTag.DOCUMENT, ContentTag.QR_CODE), t)
        assertFalse(ContentTag.SCENERY in VisionRules.tags(listOf("Mountain" to 0.9f, "Selfie" to 0.8f), false))
        assertTrue(ContentTag.SCENERY in VisionRules.tags(listOf("Mountain" to 0.9f), false))
        assertTrue(ContentTag.PET in VisionRules.tags(listOf("Cat" to 0.8f), false))
    }

    @Test fun verificationCode() {
        assertEquals("482913", VisionRules.verificationCode(listOf("【某某】您的验证码是 482913，5分钟内有效")))
        assertEquals("7731", VisionRules.verificationCode(listOf("Your verification code: 7731")))
        assertNull(VisionRules.verificationCode(listOf("今天花了 1234 元")))
        assertNull(VisionRules.verificationCode(listOf("验证码 123")))
        assertNull(VisionRules.verificationCode(listOf("验证码 123456789")))
    }

    @Test fun poorLightExcludesTextAndLongImages() {
        assertFalse(VisionRules.isPoorLight(245.0, false, false, false, emptySet(), 1496.0 / 393.0))
        assertFalse(VisionRules.isPoorLight(245.0, false, false, true, emptySet(), 1.3))
        assertFalse(VisionRules.isPoorLight(245.0, true, false, false, emptySet(), 1.3))
        assertFalse(VisionRules.isPoorLight(245.0, false, false, false, setOf(ContentTag.DOCUMENT), 1.3))
        assertTrue(VisionRules.isPoorLight(245.0, false, false, false, emptySet(), 1.33))
        assertTrue(VisionRules.isPoorLight(20.0, false, false, false, emptySet(), 1.33))
        assertFalse(VisionRules.isPoorLight(128.0, false, false, false, emptySet(), 1.33))
    }

    @Test fun lowQualityAndTextHelpers() {
        assertTrue(VisionRules.isLowQuality(-0.6f, false, false))
        assertFalse(VisionRules.isLowQuality(-0.6f, true, false))
        assertFalse(VisionRules.isLowQuality(null, false, false))
        assertTrue(VisionRules.isTextHeavy(6, 10))
        assertFalse(VisionRules.isTextHeavy(2, 20))
        assertEquals(1024 to 768, VisionRules.textTargetSize(4032, 3024))
        val (lw, lh) = VisionRules.textTargetSize(1170, 6000)
        assertTrue(lh <= 4096); assertTrue(lw >= 700)
    }

    @Test fun textRecognitionCandidates() {
        assertTrue(VisionRules.shouldRecognizeText(true, emptySet(), 0f, 100.0, 1.3))
        assertTrue(VisionRules.shouldRecognizeText(false, emptySet(), 0f, 100.0, 3.0))
        assertFalse(VisionRules.shouldRecognizeText(false, setOf(ContentTag.FOOD), 0.1f, 120.0, 1.33))
    }
}
