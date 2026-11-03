package com.yuanye.photocleaner.core

import org.junit.Assert.*
import org.junit.Test

/** 从 iOS 版 ImageMathTests 移植 */
class ImageMathTest {
    private fun checkerboard(w: Int, h: Int, cell: Int = 4) =
        GrayImage.of(w, h, IntArray(w * h) { i -> val x = i % w; val y = i / w; if ((x / cell + y / cell) % 2 == 0) 230 else 25 })

    private fun boxBlur(img: GrayImage, r: Int): GrayImage {
        val out = IntArray(img.width * img.height)
        for (y in 0 until img.height) for (x in 0 until img.width) {
            var s = 0; var n = 0
            for (dy in -r..r) for (dx in -r..r) {
                val xx = x + dx; val yy = y + dy
                if (xx >= 0 && yy >= 0 && xx < img.width && yy < img.height) { s += img.at(xx, yy); n++ }
            }
            out[y * img.width + x] = s / n
        }
        return GrayImage.of(img.width, img.height, out)
    }

    private fun gradient9x8(reversed: Boolean = false, offset: Int = 0) =
        GrayImage.of(9, 8, IntArray(72) { i -> val x = i % 9; val y = i / 9; minOf(255, (if (reversed) (8 - x) * 20 else x * 20) + y * 3 + offset) })

    @Test fun hamming() {
        assertEquals(0, ImageMath.hamming(0, 0))
        assertEquals(64, ImageMath.hamming(0, -1L))
        assertEquals(2, ImageMath.hamming(0b1011, 0b0001))
    }

    @Test fun dHashIdenticalAndBrightnessInvariant() {
        assertEquals(0, ImageMath.hamming(ImageMath.dHash(gradient9x8()), ImageMath.dHash(gradient9x8(offset = 30))))
    }

    @Test fun dHashDifferentImages() {
        assertTrue(ImageMath.hamming(ImageMath.dHash(gradient9x8()), ImageMath.dHash(gradient9x8(reversed = true))) > 40)
    }

    @Test fun laplacianSharpVsBlurry() {
        val sharp = checkerboard(64, 64)
        val vs = ImageMath.laplacianVariance(sharp)
        val vb = ImageMath.laplacianVariance(boxBlur(sharp, 3))
        assertTrue("sharp=$vs blurry=$vb", vs > vb * 10)
        assertEquals(0.0, ImageMath.laplacianVariance(GrayImage.of(32, 32, IntArray(1024) { 128 })), 1e-9)
    }

    @Test fun meanBrightnessAndContrast() {
        val img = GrayImage.of(2, 2, intArrayOf(0, 255, 0, 255))
        assertEquals(127.5, ImageMath.meanBrightness(img), 1e-9)
        assertEquals(127.5, ImageMath.contrast(img), 1e-9)
        assertEquals(0.0, ImageMath.contrast(GrayImage.of(2, 2, intArrayOf(9, 9, 9, 9))), 1e-9)
    }

    @Test fun fittedSize() {
        assertEquals(256 to 192, ImageMath.fittedSize(4032, 3024, 256))
        assertEquals(100 to 50, ImageMath.fittedSize(100, 50, 256))
    }

    @Test fun grouping() {
        val base = 0xF0F0F0F00F0F0F0FUL.toLong()
        val entries = listOf(
            HashEntry("a", base, 1000.0),
            HashEntry("b", base xor 0b111, 5_000_000.0),   // 距离 3：重复图
            HashEntry("c", base xor 0xFF, 1060.0),          // 距离 8，时间相近：连拍
            HashEntry("d", base xor 0xFF00, 9_000_000.0),   // 距离 8 但时间很远
            HashEntry("e", base.inv(), 1001.0),             // 完全不同
        )
        val g = SimilarityGrouper.groups(entries)
        assertEquals(1, g.size)
        assertEquals(setOf("a", "b", "c"), g[0].toSet())
    }

    @Test fun groupingChainsDuplicates() {
        val base = 0x123456789ABCDEF0L
        val entries = listOf(HashEntry("a", base, 0.0), HashEntry("c", base xor 0xFF, 30.0), HashEntry("d", base xor 0xFF, 99_999.0))
        assertEquals(setOf("a", "c", "d"), SimilarityGrouper.groups(entries).first().toSet())
    }

    @Test fun bestIndex() {
        assertEquals(1, SimilarityGrouper.bestIndex(listOf(10.0, 300.0, 120.0), listOf(1, 1, 1)))
        assertEquals(1, SimilarityGrouper.bestIndex(listOf(100.0, 102.0), listOf(100, 400)))
    }
}
