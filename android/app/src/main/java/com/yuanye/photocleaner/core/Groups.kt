package com.yuanye.photocleaner.core

import java.util.Calendar
import java.util.TimeZone

/** 完全重复：大小相同的文件才去算内容哈希；哈希相同 = 一模一样 */
object ExactDuplicates {
    /** 可能重复的候选（同类型、同大小、大小 > 0），每组至少 2 个 */
    fun candidates(items: List<PhotoItem>): List<List<PhotoItem>> =
        items.filter { it.fileSize > 0 }
            .groupBy { Triple(it.isVideo, it.fileSize, it.width.toLong() * 100_000 + it.height) }
            .values.filter { it.size > 1 }

    /**
     * 按内容哈希分组；每组第一个是要保留的那张（收藏优先，其次拍得最早、id 最小）。
     * hashOf 返回 null 表示读不了，跳过。
     */
    fun groups(items: List<PhotoItem>, hashOf: (PhotoItem) -> String?): List<List<String>> {
        val out = ArrayList<List<String>>()
        for (cand in candidates(items)) {
            val byHash = LinkedHashMap<String, MutableList<PhotoItem>>()
            for (it in cand) {
                val h = hashOf(it) ?: continue
                byHash.getOrPut(h) { mutableListOf() }.add(it)
            }
            for (g in byHash.values) if (g.size > 1) out += keeperFirst(g).map { it.id }
        }
        return out.sortedWith(compareByDescending<List<String>> { it.size }.thenBy { it[0] })
    }

    fun keeperFirst(g: List<PhotoItem>): List<PhotoItem> =
        g.sortedWith(compareByDescending<PhotoItem> { it.isFavorite }
            .thenBy { it.dateMillis ?: Long.MAX_VALUE }
            .thenBy { it.id.drop(1).toLongOrNull() ?: Long.MAX_VALUE })
}

/** 连拍：按文件名里的连拍标记 + 拍摄时间分组 */
object BurstGrouper {
    // 小米 / 华为 / OPPO 等：IMG_20231010_123456_BURST001(_COVER).jpg  → 键 = BURST 前面的部分
    // Google 相机：00001IMG_00001_BURST20231010123456789(_COVER).jpg → 键 = BURST 后面的长数字
    private val longIdRe = Regex("""(?i)BURST(\d{10,})""")
    // 三星：20231010_123456_001.jpg（同一秒连拍的序号）
    private val samsungRe = Regex("""^(\d{8}_\d{6})_\d{3}\.(?i:jpe?g|heic|heif)$""")
    private const val MAX_GAP_MS = 60_000L

    /** 文件名对应的连拍键；不是连拍返回 null */
    fun key(name: String): String? {
        samsungRe.matchEntire(name)?.let { return "S:" + it.groupValues[1] }
        val at = name.indexOf("BURST", ignoreCase = true)
        if (at < 0) return null
        longIdRe.find(name)?.let { return "B:" + it.groupValues[1] }
        val prefix = name.substring(0, at).trimEnd('_', '-', ' ').replace(Regex("""^\d{5}(?=\D)"""), "")
        return if (prefix.isEmpty()) null else "P:" + prefix.uppercase()
    }

    /** 每组按拍摄时间排序；同一个键下时间相隔超过 1 分钟的拆开 */
    fun groups(items: List<PhotoItem>): List<List<String>> {
        val byKey = LinkedHashMap<String, MutableList<PhotoItem>>()
        for (it in items) {
            if (it.isVideo) continue
            val k = key(it.name) ?: continue
            byKey.getOrPut(k) { mutableListOf() }.add(it)
        }
        val out = ArrayList<List<String>>()
        for (list in byKey.values) {
            if (list.size < 2) continue
            val sorted = list.sortedWith(compareBy<PhotoItem> { it.dateMillis ?: 0L }.thenBy { it.name })
            var cur = mutableListOf(sorted[0])
            for (i in 1 until sorted.size) {
                val prev = sorted[i - 1].dateMillis
                val t = sorted[i].dateMillis
                if (prev != null && t != null && t - prev > MAX_GAP_MS) {
                    if (cur.size > 1) out += cur.map { it.id }
                    cur = mutableListOf()
                }
                cur += sorted[i]
            }
            if (cur.size > 1) out += cur.map { it.id }
        }
        return out.sortedWith(compareByDescending<List<String>> { it.size }.thenBy { it[0] })
    }

    /** 连拍里推荐保留的：文件名带 COVER（相机挑的封面）优先 */
    fun coverIndex(names: List<String>): Int? = names.indexOfFirst { it.contains("COVER", ignoreCase = true) }.takeIf { it >= 0 }
}

/** 小批量整理 */
object QuickBatches {
    /** 那年今日：往年同月同日拍的（今年的不算） */
    fun onThisDay(items: List<PhotoItem>, nowMillis: Long, tz: TimeZone = TimeZone.getDefault()): List<String> {
        val cal = Calendar.getInstance(tz)
        cal.timeInMillis = nowMillis
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH)
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return items.filter { !it.isFavorite }.mapNotNull { it ->
            val t = it.dateMillis ?: return@mapNotNull null
            cal.timeInMillis = t
            if (cal.get(Calendar.YEAR) < y && cal.get(Calendar.MONTH) == m && cal.get(Calendar.DAY_OF_MONTH) == d) it else null
        }.sortedByDescending { it.dateMillis }.map { it.id }
    }

    /** 随机挑 n 张（同一个种子结果一样） */
    fun random(ids: List<String>, n: Int, seed: Long): List<String> = ids.shuffled(java.util.Random(seed)).take(n)
}

/** 累计清理统计：总共释放、删除多少、清理了几次、每天释放多少 */
data class CleanStats(
    val totalBytes: Long = 0,
    val totalCount: Int = 0,
    val sessions: Int = 0,
    /** 天（epochDay）→ 当天释放的字节数 / 删除数 */
    val daily: Map<Long, Pair<Long, Int>> = emptyMap(),
) {
    fun record(epochDay: Long, bytes: Long, count: Int): CleanStats {
        if (count <= 0) return this
        val old = daily[epochDay] ?: (0L to 0)
        val d = daily.toMutableMap()
        d[epochDay] = (old.first + bytes) to (old.second + count)
        // 只留最近一年
        val pruned = d.filterKeys { it > epochDay - 400 }
        return CleanStats(totalBytes + bytes, totalCount + count, sessions + 1, pruned)
    }

    /** 最近 days 天（含今天）每天释放的字节数，最早的在前 */
    fun lastDays(todayEpochDay: Long, days: Int = 30): List<Long> =
        (days - 1 downTo 0).map { daily[todayEpochDay - it]?.first ?: 0L }

    fun encode(): String = buildString {
        append("v1 ").append(totalBytes).append(' ').append(totalCount).append(' ').append(sessions).append('\n')
        for ((k, v) in daily.toSortedMap()) append(k).append(' ').append(v.first).append(' ').append(v.second).append('\n')
    }

    companion object {
        fun decode(s: String): CleanStats = runCatching {
            val lines = s.lines().filter { it.isNotBlank() }
            val head = lines.first().split(' ')
            require(head[0] == "v1")
            val daily = lines.drop(1).associate { l ->
                val p = l.split(' ')
                p[0].toLong() to (p[1].toLong() to p[2].toInt())
            }
            CleanStats(head[1].toLong(), head[2].toInt(), head[3].toInt(), daily)
        }.getOrDefault(CleanStats())
    }
}

/** 删除后核对：哪些真的没了，哪些还在（部分失败） */
object DeleteCheck {
    fun split(ids: List<String>, stillExists: (String) -> Boolean): Pair<List<String>, List<String>> {
        val gone = ArrayList<String>()
        val left = ArrayList<String>()
        for (id in ids) if (stillExists(id)) left += id else gone += id
        return gone to left
    }
}
