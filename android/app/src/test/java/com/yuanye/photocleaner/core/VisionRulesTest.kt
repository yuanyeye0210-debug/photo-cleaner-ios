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
            HashEntry("a", base, 1000.0, q(1f, 0.2f, 0f), labels = listOf("cat", "sofa", "room")),
            HashEntry("b", base xor 0xFFFFFFFFL, 1030.0, q(1f, 0.3f, 0f), labels = listOf("cat", "sofa", "pillow")),
            HashEntry("c", base xor 0xFF0000000000L, 1010.0, q(0f, 0f, 1f)),
            HashEntry("d", base xor 0x3FF, 9_000_000.0, q(1f, 0.21f, 0f)),
            HashEntry("e", base.inv(), 5_000_000.0, q(1f, 0.2f, 0f)),
        )
        // 去掉 d 时 a、b 一组（主体标签一致）
        assertEquals(listOf(listOf("a", "b")), SimilarityGrouper.groups(entries.filter { it.id != "d" }))
        // 有 d 时：a–d 是重复图（更像），b–d 不相似 → 只留 {a, d}，b 不会被链进来
        assertEquals(listOf(listOf("a", "d")), SimilarityGrouper.groups(entries))
    }

    // ---- 分组准确度（完全连接、主体、比例、人脸、「不是相似」）----

    private val far = 0xFFFFFFFF00000000UL.toLong()   // 和 0 差 32 位：dHash 不能当主体证据

    @Test fun completeLinkagePreventsChaining() {
        // A 像 B，B 像 C，但 A 和 C 差很远 → 只能有 {B, C}
        val l = listOf("dog", "grass")
        val a = HashEntry("A", 0L, 0.0, q(1f, 0f, 0f), labels = l)
        val b = HashEntry("B", far, 20.0, q(1f, 0.3f, 0f), labels = l)
        val c = HashEntry("C", 0x00FF00FF00FF00FFL, 40.0, q(1f, 0.62f, 0f), labels = l)
        assertNotNull(SimilarityGrouper.link(a, b))
        assertNotNull(SimilarityGrouper.link(b, c))
        assertNull(SimilarityGrouper.link(a, c))
        assertEquals(listOf(listOf("B", "C")), SimilarityGrouper.groups(listOf(a, b, c)))
        assertEquals(listOf(listOf("B", "C")), SimilarityGrouper.groupsBruteForce(listOf(a, b, c)))
    }

    @Test fun longChainSplitsIntoTightGroups() {
        val entries = (0 until 10).map { i ->
            HashEntry("p$i", i * 0x1111111111111111L, i * 5.0, q(1f, i * 0.2f, 0f), labels = listOf("beach"))
        }
        val groups = SimilarityGrouper.groups(entries)
        assertTrue(groups.size > 1)
        val byId = entries.associateBy { it.id }
        for (g in groups) for (x in g) for (y in g) if (x < y) {
            assertNotNull("$x–$y 不相似却在同一组", SimilarityGrouper.link(byId.getValue(x), byId.getValue(y)))
        }
    }

    @Test fun differentSubjectNotGrouped() {
        val a = HashEntry("a", 0L, 0.0, q(1f, 0f, 0f), labels = listOf("food", "plate"))
        val b = HashEntry("b", far, 10.0, q(1f, 0.3f, 0f), labels = listOf("cat", "sofa"))
        assertNull(SimilarityGrouper.link(a, b))
        // 标签不知道时，dHash ≤ 16 也能证明主体一致
        assertNotNull(SimilarityGrouper.link(HashEntry("a0", 0L, 0.0, q(1f, 0f, 0f)), HashEntry("c", 0xFFFFL, 10.0, q(1f, 0.3f, 0f))))
    }

    @Test fun timeWindowAndFeatureThreshold() {
        val a = HashEntry("a", 0L, 0.0, q(1f, 0f, 0f), labels = listOf("dog"))
        assertNotNull(SimilarityGrouper.link(a, HashEntry("b", far, 85.0, q(1f, 0.3f, 0f), labels = listOf("dog"))))
        assertNull(SimilarityGrouper.link(a, HashEntry("c", far, 100.0, q(1f, 0.3f, 0f), labels = listOf("dog"))))
        assertNull(SimilarityGrouper.link(a, HashEntry("d", far, 10.0, q(1f, 0.41f, 0f), labels = listOf("dog"))))
    }

    @Test fun aspectRatioMismatchNotGroupedUnlessDuplicate() {
        val shot = HashEntry("s", 0L, 0.0, q(1f, 0f, 0f), aspect = 2.17, labels = listOf("text"))
        val photo = HashEntry("p", far, 5.0, q(1f, 0.3f, 0f), aspect = 1.33, labels = listOf("text"))
        assertNull(SimilarityGrouper.link(shot, photo))
        assertNotNull(SimilarityGrouper.link(shot, HashEntry("d", far, 5.0, q(1f, 0.05f, 0f), aspect = 1.33)))
        assertEquals(2.164, HashEntry.aspect(1170, 2532)!!, 0.01)
    }

    @Test fun faceCountDifference() {
        val a = HashEntry("a", 0L, 0.0, q(1f, 0f, 0f), labels = listOf("person"), faces = 1)
        assertNotNull(SimilarityGrouper.link(a, HashEntry("b", far, 5.0, q(1f, 0.3f, 0f), labels = listOf("person"), faces = 2)))
        assertNull(SimilarityGrouper.link(a, HashEntry("c", far, 5.0, q(1f, 0.3f, 0f), labels = listOf("person"), faces = 3)))
    }

    @Test fun notSimilarExclusion() {
        val a = HashEntry("a", 0L, 0.0, q(1f, 0f, 0f))
        val b = HashEntry("b", 1L, 5.0, q(1f, 0f, 0f))
        val c = HashEntry("c", 3L, 8.0, q(1f, 0f, 0f))
        assertEquals(listOf(listOf("a", "b", "c")), SimilarityGrouper.groups(listOf(a, b, c)))
        val ex = setOf(PairKey.make("c", "a"), PairKey.make("c", "b"))
        assertEquals(listOf(listOf("a", "b")), SimilarityGrouper.groups(listOf(a, b, c), excluded = ex))
        assertEquals(listOf(listOf("a", "b")), SimilarityGrouper.groupsBruteForce(listOf(a, b, c), excluded = ex))
        assertEquals("a|b", PairKey.make("b", "a"))
        assertEquals("b", PairKey.ids("a|b")?.second)
    }

    @Test fun subjectLabelsAndJaccard() {
        val l = VisionRules.subjectLabels(listOf("Dog" to 0.9f, "Grass" to 0.5f, "x" to 0.2f, "a" to 0.31f, "b" to 0.4f, "c" to 0.35f, "d" to 0.33f))
        assertEquals(listOf("dog", "grass", "b", "c", "d"), l)
        assertEquals(1.0 / 3, SimilarityGrouper.jaccard(listOf("a", "b"), listOf("b", "c")), 0.001)
    }

    @Test fun stricterContentTags() {
        assertFalse(ContentTag.PET in VisionRules.tags(listOf("Dog" to 0.65f), false))
        assertFalse(ContentTag.PET in VisionRules.tags(listOf("Car" to 0.9f, "Dog" to 0.8f), false))
        assertTrue(ContentTag.PET in VisionRules.tags(listOf("Pet" to 0.95f, "Dog" to 0.9f), false))
        assertFalse(ContentTag.FOOD in VisionRules.tags(listOf("Food" to 0.69f), false))
        assertFalse(ContentTag.FOOD in VisionRules.tags(listOf("Person" to 0.95f, "Cake" to 0.8f), false))
        assertFalse(ContentTag.DOCUMENT in VisionRules.tags(listOf("Receipt" to 0.55f), false))
        assertTrue(ContentTag.DOCUMENT in VisionRules.tags(listOf("Receipt" to 0.55f), false, textHeavy = true))
        assertFalse(ContentTag.QR_CODE in VisionRules.tags(listOf("QR code" to 0.99f), false))
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
        val t = VisionRules.tags(listOf("Food" to 0.9f, "Dog" to 0.3f, "Receipt" to 0.7f, "unknown_xyz" to 0.5f), hasQR = true)
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
