package com.yuanye.photocleaner.data

import android.content.Context
import com.yuanye.photocleaner.core.AnalysisResult
import com.yuanye.photocleaner.core.ContentTag
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File

/** 分析结果缓存：下次打开不用重新分析（照片修改过会重新分析） */
class AnalysisCache(context: Context) {
    private val file = File(context.filesDir, "analysis_v2.bin")

    data class Entry(val dateModified: Long, val result: AnalysisResult)

    fun load(): Map<String, Entry> = runCatching {
        if (!file.exists()) return emptyMap()
        DataInputStream(BufferedInputStream(file.inputStream())).use { s ->
            if (s.readInt() != MAGIC) return emptyMap()
            val n = s.readInt()
            val out = HashMap<String, Entry>(n * 2)
            repeat(n) {
                val id = s.readUTF()
                val mod = s.readLong()
                val dHash = s.readLong()
                val sharp = s.readDouble()
                val bright = s.readDouble()
                val contrast = s.readDouble()
                val fLen = s.readInt()
                val feature = if (fLen >= 0) ByteArray(fLen).also { s.readFully(it) } else null
                val q = s.readFloat()
                val tagBits = s.readInt()
                val tags = ContentTag.entries.filter { tagBits and (1 shl it.ordinal) != 0 }.toSet()
                val textChecked = s.readBoolean()
                val lines = s.readInt()
                val chars = s.readInt()
                val code = s.readUTF().ifEmpty { null }
                val fq = s.readFloat()
                val fc = s.readBoolean()
                val motion = s.readLong()
                out[id] = Entry(mod, AnalysisResult(
                    dHash, sharp, bright, contrast, feature, if (q.isNaN()) null else q, tags, textChecked, lines, chars,
                    code, if (fq.isNaN()) null else fq, fc, motion,
                ))
            }
            out
        }
    }.getOrDefault(emptyMap())

    fun save(entries: Map<String, Entry>) {
        runCatching {
            val tmp = File(file.parentFile, file.name + ".tmp")
            DataOutputStream(BufferedOutputStream(tmp.outputStream())).use { s ->
                s.writeInt(MAGIC)
                s.writeInt(entries.size)
                for ((id, e) in entries) {
                    val r = e.result
                    s.writeUTF(id)
                    s.writeLong(e.dateModified)
                    s.writeLong(r.dHash)
                    s.writeDouble(r.sharpness)
                    s.writeDouble(r.brightness)
                    s.writeDouble(r.contrast)
                    val f = r.feature
                    if (f == null) s.writeInt(-1) else { s.writeInt(f.size); s.write(f) }
                    s.writeFloat(r.quality ?: Float.NaN)
                    s.writeInt(r.tags.fold(0) { acc, t -> acc or (1 shl t.ordinal) })
                    s.writeBoolean(r.textChecked)
                    s.writeInt(r.textLines)
                    s.writeInt(r.textChars)
                    s.writeUTF(r.verificationCode ?: "")
                    s.writeFloat(r.faceQuality ?: Float.NaN)
                    s.writeBoolean(r.faceChecked)
                    s.writeLong(r.motionBytes)
                }
            }
            tmp.renameTo(file)
        }
    }

    fun clear() { file.delete(); File(file.parentFile, "analysis_v1.bin").delete() }

    private companion object { const val MAGIC = 0x50430003 }
}
