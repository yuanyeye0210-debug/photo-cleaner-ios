package com.yuanye.photocleaner.core

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar
import java.util.Random
import java.util.TimeZone

class NewFeaturesTest {
    private fun item(id: String, size: Long = 1000, date: Long? = 0, name: String = "", fav: Boolean = false,
                     video: Boolean = false, w: Int = 100, h: Int = 100) =
        PhotoItem(id, "content://x/$id", size, date, video, false, fav, w, h, 0, null, name = name)

    // ---------------- 快速分组 = 暴力分组 ----------------

    @Test fun fastGroupingMatchesBruteForce() {
        val rnd = Random(7)
        val dim = 64
        fun randUnit(): FloatArray = VisionRules.normalized(FloatArray(dim) { rnd.nextGaussian().toFloat() })!!
        fun jitter(v: FloatArray, amt: Float) = VisionRules.normalized(FloatArray(dim) { v[it] + amt * rnd.nextGaussian().toFloat() })!!
        val entries = ArrayList<HashEntry>()
        var id = 0
        repeat(60) { c ->
            val base = rnd.nextLong()
            val feat = randUnit()
            val t0 = rnd.nextInt(10_000_000).toDouble()
            val members = 1 + rnd.nextInt(4)
            repeat(members) {
                var h = base
                repeat(rnd.nextInt(6)) { h = h xor (1L shl rnd.nextInt(64)) }
                val time = if (c % 7 == 0) null else if (c % 3 == 0) t0 + rnd.nextInt(5_000_000) else t0 + rnd.nextInt(120)
                val f = if (c % 5 == 0) null else VisionRules.quantize(jitter(feat, 0.01f))
                entries += HashEntry("p${id++}", h, time, f)
            }
        }
        // 再加一些随机噪声照片
        repeat(200) { entries += HashEntry("n${id++}", rnd.nextLong(), rnd.nextInt(10_000_000).toDouble(), VisionRules.quantize(randUnit())) }
        val fast = SimilarityGrouper.groups(entries).map { it.toSet() }.toSet()
        val brute = SimilarityGrouper.groupsBruteForce(entries).map { it.toSet() }.toSet()
        assertTrue(brute.isNotEmpty())
        assertEquals(brute, fast)
    }

    @Test fun fastGroupingHandlesHugeIdenticalBucket() {
        // 1000 张纯黑图（dHash 都是 0），拍摄时间各不相同：不能卡死，且相邻的会被分到一起
        val entries = (0 until 1000).map { HashEntry("b$it", 0L, it * 10_000.0, null) }
        val t = System.currentTimeMillis()
        val g = SimilarityGrouper.groups(entries)
        assertTrue(System.currentTimeMillis() - t < 5000)
        assertEquals(1, g.size)
    }

    // ---------------- 完全重复 ----------------

    @Test fun exactDuplicates() {
        val items = listOf(
            item("i1", 500, date = 300), item("i2", 500, date = 100), item("i3", 500, date = 200),
            item("i4", 500, date = 50, w = 50),   // 尺寸不同：不是候选
            item("i5", 700), item("i6", 700, fav = true), item("i7", 900),
        )
        val hashes = mapOf("i1" to "A", "i2" to "A", "i3" to "B", "i5" to "C", "i6" to "C")
        val g = ExactDuplicates.groups(items) { hashes[it.id] }
        assertEquals(2, g.size)
        assertEquals(listOf("i2", "i1"), g.first { "i1" in it })       // 拍得早的保留（排第一）
        assertEquals(listOf("i6", "i5"), g.first { "i5" in it })       // 收藏的保留
        assertEquals(2, ExactDuplicates.candidates(items).size)
    }

    // ---------------- 连拍 ----------------

    @Test fun burstKeys() {
        assertEquals("P:IMG_20231010_123456", BurstGrouper.key("IMG_20231010_123456_BURST001.jpg"))
        assertEquals("P:IMG_20231010_123456", BurstGrouper.key("IMG_20231010_123456_BURST002_COVER.jpg"))
        assertEquals("B:20231010123456789", BurstGrouper.key("00001IMG_00001_BURST20231010123456789.jpg"))
        assertEquals("B:20231010123456789", BurstGrouper.key("00000IMG_00000_BURST20231010123456789_COVER.jpg"))
        assertEquals("S:20231010_123456", BurstGrouper.key("20231010_123456_001.jpg"))
        assertNull(BurstGrouper.key("IMG_20231010_123456.jpg"))
        assertNull(BurstGrouper.key("20231010_123456.jpg"))
    }

    @Test fun burstGroupsSplitByTime() {
        val items = listOf(
            item("a", date = 1000, name = "IMG_1_BURST001.jpg"),
            item("b", date = 1500, name = "IMG_1_BURST002_COVER.jpg"),
            item("c", date = 2000, name = "IMG_1_BURST003.jpg"),
            item("d", date = 10_000_000, name = "IMG_1_BURST004.jpg"),   // 同名前缀但隔了很久：单独一张，不成组
            item("e", date = 0, name = "20231010_123456_001.jpg"),
            item("f", date = 0, name = "20231010_123456_002.jpg"),
            item("g", date = 0, name = "other.jpg"),
        )
        val g = BurstGrouper.groups(items)
        assertEquals(listOf(listOf("a", "b", "c"), listOf("e", "f")), g)
        assertEquals(1, BurstGrouper.coverIndex(listOf("IMG_1_BURST001.jpg", "IMG_1_BURST002_COVER.jpg")))
    }

    // ---------------- 小批量 ----------------

    @Test fun onThisDay() {
        val tz = TimeZone.getTimeZone("UTC")
        fun at(y: Int, m: Int, d: Int) = Calendar.getInstance(tz).apply { clear(); set(y, m - 1, d, 12, 0) }.timeInMillis
        val now = at(2026, 11, 4)
        val items = listOf(
            item("a", date = at(2024, 11, 4)), item("b", date = at(2020, 11, 4)), item("c", date = at(2026, 11, 4)),
            item("d", date = at(2024, 11, 5)), item("e", date = at(2023, 11, 4), fav = true), item("f", date = null),
        )
        assertEquals(listOf("a", "b"), QuickBatches.onThisDay(items, now, tz))
        val ids = (1..50).map { "x$it" }
        val r = QuickBatches.random(ids, 10, 42)
        assertEquals(10, r.size)
        assertEquals(10, r.toSet().size)
        assertEquals(r, QuickBatches.random(ids, 10, 42))
    }

    // ---------------- 统计 ----------------

    @Test fun statsAggregateAndRoundTrip() {
        var s = CleanStats()
        s = s.record(100, 5_000, 2)
        s = s.record(100, 1_000, 1)
        s = s.record(105, 9_000, 3)
        s = s.record(105, 0, 0)   // 什么都没删：不算一次
        assertEquals(15_000, s.totalBytes)
        assertEquals(6, s.totalCount)
        assertEquals(3, s.sessions)
        val days = s.lastDays(105, 30)
        assertEquals(30, days.size)
        assertEquals(9_000, days.last())
        assertEquals(6_000, days[days.size - 6])
        assertEquals(s, CleanStats.decode(s.encode()))
        assertEquals(CleanStats(), CleanStats.decode("garbage"))
    }

    @Test fun partialDelete() {
        val (gone, left) = DeleteCheck.split(listOf("a", "b", "c")) { it == "b" }
        assertEquals(listOf("a", "c"), gone)
        assertEquals(listOf("b"), left)
    }

    // ---------------- 动态照片 ----------------

    private fun jpeg(xmp: String, body: Int = 4000): ByteArray {
        val x = xmp.toByteArray(Charsets.ISO_8859_1)
        val out = java.io.ByteArrayOutputStream()
        out.write(byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE1.toByte()))
        out.write(x)
        out.write(ByteArray(body) { 7 })
        out.write(byteArrayOf(0xFF.toByte(), 0xD9.toByte()))
        return out.toByteArray()
    }

    private val mp4 = ByteArray(3000) { 1 }.also { "\u0000\u0000\u0000\u0018ftypmp42".toByteArray(Charsets.ISO_8859_1).copyInto(it) }

    @Test fun googleMotionPhoto() {
        val xmp = """<x:xmpmeta><rdf:Description GCamera:MotionPhoto="1" GCamera:MotionPhotoVersion="1">
            <Container:Directory><rdf:Seq><rdf:li><Container:Item Item:Mime="image/jpeg" Item:Semantic="Primary"/></rdf:li>
            <rdf:li><Container:Item Item:Mime="video/mp4" Item:Semantic="MotionPhoto" Item:Length="${mp4.size}"/></rdf:li></rdf:Seq>
            </Container:Directory></rdf:Description></x:xmpmeta>"""
        val photo = jpeg(xmp)
        val file = photo + mp4
        val info = MotionPhoto.detect(MotionPhoto.Bytes(file))!!
        assertEquals(MotionPhoto.Kind.XMP, info.kind)
        assertEquals(photo.size.toLong(), info.cut)
        assertEquals(mp4.size.toLong(), info.videoBytes(file.size.toLong()))
        val still = MotionPhoto.toStill(file, info)
        assertEquals(photo.size, still.size)
        val s = String(still, Charsets.ISO_8859_1)
        assertTrue(s.contains("GCamera:MotionPhoto=\"0\""))
        assertTrue(s.contains("GCamera:MotionPhotoVersion=\"1\""))   // 版本号不动
        assertNull(MotionPhoto.detect(MotionPhoto.Bytes(still)))     // 转完不再是动态照片
    }

    @Test fun legacyMicroVideo() {
        val xmp = """<rdf:Description GCamera:MicroVideo="1" GCamera:MicroVideoVersion="1" GCamera:MicroVideoOffset="${mp4.size}"/>"""
        val file = jpeg(xmp) + mp4
        val info = MotionPhoto.detect(MotionPhoto.Bytes(file))!!
        assertEquals(mp4.size.toLong(), info.videoBytes(file.size.toLong()))
        assertTrue(String(MotionPhoto.toStill(file, info), Charsets.ISO_8859_1).contains("MicroVideo=\"0\""))
    }

    @Test fun samsungSef() {
        val photo = jpeg("<x:xmpmeta/>")
        val name = "MotionPhoto_Data".toByteArray(Charsets.ISO_8859_1)
        fun le(v: Int) = byteArrayOf(v.toByte(), (v shr 8).toByte(), (v shr 16).toByte(), (v shr 24).toByte())
        // 数据块：2 字节填充 + 2 字节类型 + 4 字节名字长度 + 名字 + 视频
        val block = byteArrayOf(0, 0, 0x30, 0x0A) + le(name.size) + name + mp4
        val blockStart = photo.size
        val sefhPos = blockStart + block.size
        val sef = "SEFH".toByteArray() + le(106) + le(1) + byteArrayOf(0, 0, 0x30, 0x0A) + le(sefhPos - blockStart) + le(block.size)
        val file = photo + block + sef + le(sef.size) + "SEFT".toByteArray()
        val info = MotionPhoto.detect(MotionPhoto.Bytes(file))!!
        assertEquals(MotionPhoto.Kind.SAMSUNG, info.kind)
        assertEquals(photo.size.toLong(), info.cut)
        assertArrayEquals(photo, MotionPhoto.toStill(file, info))
    }

    @Test fun notMotion() {
        assertNull(MotionPhoto.detect(MotionPhoto.Bytes(jpeg("<x:xmpmeta/>"))))
        // 标记了但长度对不上（截断点不是 JPEG 结尾）：不处理，避免弄坏照片
        val bad = jpeg("""GCamera:MicroVideo="1" GCamera:MicroVideoOffset="123"""") + mp4
        assertNull(MotionPhoto.detect(MotionPhoto.Bytes(bad)))
        assertNull(MotionPhoto.detect(MotionPhoto.Bytes(ByteArray(5000))))
    }
}
