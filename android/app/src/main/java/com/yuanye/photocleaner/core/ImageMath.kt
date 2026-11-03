package com.yuanye.photocleaner.core

import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** 8 位灰度图（纯数据结构，不依赖 Android，便于单元测试） */
class GrayImage(val width: Int, val height: Int, val pixels: ByteArray) {
    init {
        require(pixels.size == width * height) { "像素数量与尺寸不匹配" }
    }

    fun at(x: Int, y: Int): Int = pixels[y * width + x].toInt() and 0xFF

    companion object {
        fun of(width: Int, height: Int, values: IntArray): GrayImage =
            GrayImage(width, height, ByteArray(values.size) { values[it].coerceIn(0, 255).toByte() })
    }
}

/**
 * 图像分析的纯算法部分（与 iOS 版 ImageMath 一致）。
 *  - dHash 思路来自 JohannesBuchner/imagehash
 *  - 模糊检测（拉普拉斯方差）思路来自 WillBrennan/BlurDetection2
 */
object ImageMath {
    /** 差值哈希 dHash：输入必须是 9x8 灰度图，比较每行相邻像素，得到 64 位哈希 */
    fun dHash(img: GrayImage): Long {
        require(img.width == 9 && img.height == 8) { "dHash 需要 9x8 灰度图" }
        var hash = 0L
        var bit = 0
        for (y in 0 until 8) {
            for (x in 0 until 8) {
                if (img.at(x, y) > img.at(x + 1, y)) hash = hash or (1L shl bit)
                bit++
            }
        }
        return hash
    }

    /** 两个哈希的汉明距离（不同的位数），越小越相似 */
    fun hamming(a: Long, b: Long): Int = java.lang.Long.bitCount(a xor b)

    /** 拉普拉斯方差：值越小越模糊。卷积核 [0 1 0; 1 -4 1; 0 1 0] */
    fun laplacianVariance(img: GrayImage): Double {
        val w = img.width
        val h = img.height
        if (w < 3 || h < 3) return 0.0
        val p = img.pixels
        var sum = 0.0
        var sumSq = 0.0
        var n = 0.0
        for (y in 1 until h - 1) {
            val row = y * w
            for (x in 1 until w - 1) {
                val c = p[row + x].toInt() and 0xFF
                val v = (p[row + x - 1].toInt() and 0xFF) + (p[row + x + 1].toInt() and 0xFF) +
                    (p[row - w + x].toInt() and 0xFF) + (p[row + w + x].toInt() and 0xFF) - 4 * c
                val d = v.toDouble()
                sum += d
                sumSq += d * d
                n += 1
            }
        }
        val mean = sum / n
        return max(0.0, sumSq / n - mean * mean)
    }

    /** 平均亮度 0..255 */
    fun meanBrightness(img: GrayImage): Double {
        if (img.pixels.isEmpty()) return 0.0
        var total = 0L
        for (b in img.pixels) total += (b.toInt() and 0xFF)
        return total.toDouble() / img.pixels.size
    }

    /** 亮度标准差（对比度）0..~128 */
    fun contrast(img: GrayImage): Double {
        if (img.pixels.isEmpty()) return 0.0
        val mean = meanBrightness(img)
        var s = 0.0
        for (b in img.pixels) {
            val d = (b.toInt() and 0xFF) - mean
            s += d * d
        }
        return sqrt(s / img.pixels.size)
    }

    /** 等比缩放到最长边不超过 maxSide 后的尺寸 */
    fun fittedSize(width: Int, height: Int, maxSide: Int): Pair<Int, Int> {
        if (width <= 0 || height <= 0) return 1 to 1
        val scale = min(1.0, maxSide.toDouble() / max(width, height))
        return max(3, (width * scale).roundToInt()) to max(3, (height * scale).roundToInt())
    }
}
