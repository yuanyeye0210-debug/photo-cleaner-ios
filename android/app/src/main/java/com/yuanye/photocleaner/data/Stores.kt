package com.yuanye.photocleaner.data

import android.content.Context
import com.yuanye.photocleaner.core.CleanStats
import java.io.File

/** 原子写文件：先写临时文件再改名，写一半崩溃也不会坏 */
internal fun atomicWrite(file: File, text: String) {
    runCatching {
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(text)
        if (!tmp.renameTo(file)) { file.delete(); tmp.renameTo(file) }
    }
}

/** 标记（待删除 / 保留 / 稍后再看 / 已整理的月份），存在 App 私有目录的文件里 */
class MarksStore(context: Context) {
    private val file = File(context.filesDir, "marks_v1.txt")
    private val prefs = context.getSharedPreferences("photocleaner", Context.MODE_PRIVATE)

    data class Marks(
        val toDelete: Set<String> = emptySet(),
        val kept: Set<String> = emptySet(),
        val later: Set<String> = emptySet(),
        val cleanedMonths: Set<String> = emptySet(),
    )

    fun load(): Marks {
        if (!file.exists()) {
            // 从旧版（SharedPreferences）迁移
            val m = Marks(
                toDelete = prefs.getStringSet("toDeleteIDs", emptySet())!!.toSet(),
                kept = prefs.getStringSet("keptIDs", emptySet())!!.toSet(),
            )
            save(m)
            prefs.edit().remove("toDeleteIDs").remove("keptIDs").apply()
            return m
        }
        return runCatching {
            val d = HashSet<String>(); val k = HashSet<String>(); val l = HashSet<String>(); val mo = HashSet<String>()
            file.forEachLine { line ->
                if (line.length < 3 || line[1] != ' ') return@forEachLine
                val v = line.substring(2)
                when (line[0]) { 'D' -> d += v; 'K' -> k += v; 'L' -> l += v; 'M' -> mo += v }
            }
            Marks(d, k, l, mo)
        }.getOrDefault(Marks())
    }

    fun save(m: Marks) {
        val sb = StringBuilder()
        m.toDelete.forEach { sb.append("D ").append(it).append('\n') }
        m.kept.forEach { sb.append("K ").append(it).append('\n') }
        m.later.forEach { sb.append("L ").append(it).append('\n') }
        m.cleanedMonths.forEach { sb.append("M ").append(it).append('\n') }
        atomicWrite(file, sb.toString())
    }
}

class StatsStore(context: Context) {
    private val file = File(context.filesDir, "stats_v1.txt")
    fun load(): CleanStats = runCatching { CleanStats.decode(file.readText()) }.getOrDefault(CleanStats())
    fun save(s: CleanStats) = atomicWrite(file, s.encode())
}

/** 完全重复用的内容哈希缓存：id → (修改时间, 大小, 哈希) */
class HashCache(context: Context) {
    private val file = File(context.filesDir, "hashes_v1.txt")
    data class Entry(val mod: Long, val size: Long, val hash: String)

    fun load(): MutableMap<String, Entry> = runCatching {
        val out = HashMap<String, Entry>()
        file.forEachLine { l ->
            val p = l.split(' ')
            if (p.size == 4) out[p[0]] = Entry(p[1].toLong(), p[2].toLong(), p[3])
        }
        out
    }.getOrDefault(HashMap())

    fun save(m: Map<String, Entry>) = atomicWrite(file, buildString {
        for ((id, e) in m) append(id).append(' ').append(e.mod).append(' ').append(e.size).append(' ').append(e.hash).append('\n')
    })

    fun clear() { file.delete() }
}

/** 桌面小组件要显示的数字（App 每次分析完更新） */
object WidgetData {
    private const val PREFS = "widget"
    data class Snapshot(val cleanable: Int, val cleanableBytes: Long, val pending: Int, val pendingBytes: Long, val updated: Long)

    fun write(context: Context, s: Snapshot) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("cleanable", s.cleanable).putLong("cleanableBytes", s.cleanableBytes)
            .putInt("pending", s.pending).putLong("pendingBytes", s.pendingBytes).putLong("updated", s.updated).apply()
    }

    fun read(context: Context): Snapshot? {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!p.contains("updated")) return null
        return Snapshot(p.getInt("cleanable", 0), p.getLong("cleanableBytes", 0), p.getInt("pending", 0),
            p.getLong("pendingBytes", 0), p.getLong("updated", 0))
    }
}
