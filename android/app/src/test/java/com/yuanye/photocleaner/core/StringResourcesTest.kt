package com.yuanye.photocleaner.core

import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/** 文字资源检查：带参数的文字按 Android getString(id, args) 的方式格式化不能出错 */
class StringResourcesTest {
    private val entry = Regex("""<string name="([^"]+)"([^>]*)>(.*?)</string>""", RegexOption.DOT_MATCHES_ALL)
    private val spec = Regex("""%(\d+\$)?([sd])""")

    private fun files(): List<File> = listOf("values", "values-en").map { File("src/main/res/$it/strings.xml") }

    @Test fun formatArgsMatchAndNeverThrow() {
        for (f in files()) {
            assertTrue("missing $f", f.exists())
            for (m in entry.findAll(f.readText())) {
                val (name, attrs, raw) = m.destructured
                val v = raw.replace("\\'", "'").replace("\\n", "\n")
                val specs = spec.findAll(v).toList()
                if (specs.isEmpty()) {
                    // 纯文字：字面上的 % 必须标 formatted="false"，并且代码里只能不带参数读取（ui.s 已处理）
                    if (v.contains('%')) assertTrue("$name 含 % 但没标 formatted=false", attrs.contains("formatted=\"false\""))
                    continue
                }
                val args = specs.map { if (it.groupValues[2] == "d") 1 else "x" }.toTypedArray()
                try { String.format(v, *args) } catch (e: Exception) { fail("${f.parentFile.name}/$name: $e") }
            }
        }
    }

    @Test fun formattingPlainPercentWouldCrash() {
        // 回归：上一版对「扫描 %」做了 String.format，启动即闪退
        var threw = false
        try { String.format("扫描 %") } catch (e: java.util.UnknownFormatConversionException) { threw = true }
        assertTrue(threw)
    }
}
