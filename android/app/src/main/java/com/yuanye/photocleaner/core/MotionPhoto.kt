package com.yuanye.photocleaner.core

/**
 * 动态照片（三星「动态照片」、Google「动态照片」、小米「动态照片」）：一个 JPEG 文件后面接了一段 MP4。
 * 只解析字节，不依赖安卓，方便单元测试。
 *
 *  - Google / 小米 / 新版三星：XMP 里有 GCamera:MotionPhoto="1"（或旧版 MicroVideo="1"），
 *    视频长度写在 Item:Length（Semantic=MotionPhoto 那一项）或 GCamera:MicroVideoOffset（从文件末尾算）。
 *  - 老版三星：文件尾部是 SEF 块（以 "SEFT" 结尾），里面名为 "MotionPhoto_Data" 的数据就是视频。
 */
object MotionPhoto {
    interface Source {
        val size: Long
        fun read(pos: Long, len: Int): ByteArray
    }

    class Bytes(private val b: ByteArray) : Source {
        override val size: Long get() = b.size.toLong()
        override fun read(pos: Long, len: Int): ByteArray {
            val p = pos.coerceIn(0, size).toInt()
            val e = minOf(b.size, p + maxOf(0, len))
            return b.copyOfRange(p, e)
        }
    }

    enum class Kind { XMP, SAMSUNG }

    /** cut = 静态照片部分的长度（JPEG 到这里为止），videoBytes = 可以省掉的字节数 */
    data class Info(val kind: Kind, val cut: Long) {
        fun videoBytes(size: Long) = size - cut
    }

    const val HEAD = 256 * 1024
    private const val TAIL = 64 * 1024

    fun detect(src: Source): Info? {
        val size = src.size
        if (size < 1024) return null
        val head = src.read(0, minOf(HEAD.toLong(), size).toInt())
        if (head.size < 4 || head[0] != 0xFF.toByte() || head[1] != 0xD8.toByte()) return null
        val xmp = String(head, Charsets.ISO_8859_1)
        xmpVideoLength(xmp)?.let { len ->
            if (len in 1 until size) {
                val cut = validateCut(src, size - len)
                if (cut != null) return Info(Kind.XMP, cut)
            }
        }
        samsungCut(src)?.let { c -> validateCut(src, c)?.let { return Info(Kind.SAMSUNG, it) } }
        return null
    }

    /** XMP 里写的视频长度（字节）；不是动态照片返回 null */
    fun xmpVideoLength(xmp: String): Long? {
        val flagged = Regex("""(MotionPhoto|MicroVideo)\s*=\s*"1"""").containsMatchIn(xmp) ||
            Regex("""<GCamera:(MotionPhoto|MicroVideo)>1<""").containsMatchIn(xmp)
        if (!flagged) return null
        Regex("""MicroVideoOffset\s*=\s*"(\d+)"""").find(xmp)?.let { return it.groupValues[1].toLongOrNull() }
        // Container:Directory 里 Semantic="MotionPhoto" 的那一项
        val item = Regex("""Item:Semantic\s*=\s*"MotionPhoto"[^>]*?Item:Length\s*=\s*"(\d+)"""").find(xmp)
            ?: Regex("""Item:Length\s*=\s*"(\d+)"[^>]*?Item:Semantic\s*=\s*"MotionPhoto"""").find(xmp)
        return item?.groupValues?.get(1)?.toLongOrNull()
    }

    /** 老版三星 SEF：返回 MotionPhoto_Data 块的起点 */
    fun samsungCut(src: Source): Long? {
        val size = src.size
        val tailLen = minOf(TAIL.toLong(), size).toInt()
        val tail = src.read(size - tailLen, tailLen)
        if (tail.size < 8 || String(tail, tail.size - 4, 4, Charsets.ISO_8859_1) != "SEFT") return null
        val sefLen = le32(tail, tail.size - 8)
        val sefhPos = size - 8 - sefLen
        if (sefLen <= 12 || sefhPos < 0) return null
        val sef = src.read(sefhPos, sefLen.toInt())
        if (sef.size < 12 || String(sef, 0, 4, Charsets.ISO_8859_1) != "SEFH") return null
        val count = le32(sef, 8).toInt()
        var earliest: Long? = null
        for (k in 0 until count) {
            val e = 12 + k * 12
            if (e + 12 > sef.size) break
            val offset = le32(sef, e + 4)
            val start = sefhPos - offset
            if (start <= 0) continue
            val hdr = src.read(start, 8 + 64)
            if (hdr.size < 8) continue
            val nameLen = le32(hdr, 4).toInt()
            if (nameLen !in 1..64 || 8 + nameLen > hdr.size) continue
            val name = String(hdr, 8, nameLen, Charsets.ISO_8859_1)
            if (name == "MotionPhoto_Data") earliest = minOf(earliest ?: start, start)
        }
        return earliest
    }

    /** JPEG 必须在 cut 处结束（FF D9）；允许 cut 前面有少量填充 */
    private fun validateCut(src: Source, cut: Long): Long? {
        if (cut < 4) return null
        val back = minOf(64L, cut).toInt()
        val b = src.read(cut - back, back)
        for (i in b.size - 2 downTo 0) {
            if (b[i] == 0xFF.toByte() && b[i + 1] == 0xD9.toByte()) {
                val end = cut - back + i + 2
                // FF D9 后面只能是填充（0）
                for (j in i + 2 until b.size) if (b[j] != 0.toByte()) return null
                return end
            }
        }
        return null
    }

    /**
     * 生成静态照片：截掉视频部分，并把 XMP 里的动态标记改成 0（等长替换，不破坏 JPEG 结构）。
     * EXIF（拍摄时间、地点）原样保留。
     */
    fun toStill(file: ByteArray, info: Info): ByteArray {
        val out = file.copyOfRange(0, info.cut.toInt())
        val limit = minOf(out.size, HEAD)
        val text = String(out, 0, limit, Charsets.ISO_8859_1)
        for (re in listOf(Regex("""(MotionPhoto|MicroVideo)(\s*=\s*")1(")"""), Regex("""(<GCamera:(?:MotionPhoto|MicroVideo)>)1(<)"""))) {
            for (m in re.findAll(text)) {
                // 找到 "1" 的位置并改成 "0"
                val one = m.value.indexOf('1', m.value.indexOf('=').let { if (it < 0) 0 else it })
                val pos = m.range.first + one
                if (pos in 0 until limit && out[pos] == '1'.code.toByte()) out[pos] = '0'.code.toByte()
            }
        }
        return out
    }

    private fun le32(b: ByteArray, o: Int): Long =
        (b[o].toLong() and 0xFF) or ((b[o + 1].toLong() and 0xFF) shl 8) or
            ((b[o + 2].toLong() and 0xFF) shl 16) or ((b[o + 3].toLong() and 0xFF) shl 24)
}
