package com.yuanye.photocleaner.ui

import android.os.Build
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.yuanye.photocleaner.BuildConfig
import com.yuanye.photocleaner.CleanupViewModel
import kotlin.math.roundToInt

@Composable
fun SettingsScreen(vm: CleanupViewModel, onBack: () -> Unit) {
    val view = LocalView.current
    var name by remember { mutableStateOf(vm.userName) }
    var confirmClear by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()) {
        TopBar("设置", { vm.updateName(name.trim()); onBack() })
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = T.pagePadding),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Group("称呼") {
                OutlinedTextField(
                    name, { name = it; vm.updateName(it.trim()) }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = T.accent, unfocusedBorderColor = T.fillHigh,
                        focusedTextColor = T.text, unfocusedTextColor = T.text, cursorColor = T.accent),
                )
                Text("首页显示「${T.greeting()}，${name.ifBlank { "你好" }}」", color = T.text2, fontSize = T.caption)
            }
            Group("识别") {
                SliderRow("模糊阈值", vm.blurThreshold.toFloat(), 20f..200f, "${vm.blurThreshold.roundToInt()}") { vm.updateBlur(it.roundToInt().toDouble()) }
                SliderRow("大文件", vm.largeFileMB.toFloat(), 2f..100f, "${vm.largeFileMB.roundToInt()} MB 以上") { vm.updateLarge(it.roundToInt().toDouble()) }
                SliderRow("分析张数", vm.analyzeLimit.toFloat(), 500f..20000f, "最近 ${vm.analyzeLimit} 张") { vm.updateLimit((it / 500).roundToInt() * 500) }
                Text("模糊阈值越大，越多照片被判为模糊（默认 60）。相似、模糊、过暗/过曝需要逐张分析，改了分析张数后回首页点刷新。",
                    color = T.text2, fontSize = T.caption)
            }
            Group("删除") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("先移到回收站", color = T.text, fontSize = T.body)
                        Text(if (vm.trashSupported) "关掉后直接永久删除" else "Android 10 及以下不支持回收站", color = T.text2, fontSize = T.caption)
                    }
                    Switch(vm.useTrash && vm.trashSupported, { vm.updateTrash(it) }, enabled = vm.trashSupported,
                        colors = SwitchDefaults.colors(checkedTrackColor = T.accent))
                }
                HorizontalDivider(color = T.hairline)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("已标记保留", color = T.text2, fontSize = T.callout, modifier = Modifier.weight(1f))
                    Text("${vm.kept.size} 项", color = T.text, fontSize = T.callout, fontWeight = FontWeight.SemiBold)
                }
                SecondaryButton("重置「保留」标记", tint = T.text2) { Haptics.light(view); vm.resetKept() }
                SecondaryButton("清除分析缓存并重新扫描", tint = T.text2) { confirmClear = true }
            }
            Group("关于") {
                Text("相册清理 ${BuildConfig.VERSION_NAME}（${BuildConfig.VERSION_CODE}）· Android ${Build.VERSION.RELEASE}", color = T.text, fontSize = T.callout)
                Text("所有分析都在本机完成，不联网、不上传。删除使用系统媒体库接口，删除前系统会再次确认。", color = T.text2, fontSize = T.caption)
                Text("用 Google ML Kit 和 MediaPipe 本机模型识别相似照片、内容（文档、二维码、美食、宠物、风景）、文字和人脸表情；照片质量评分是清晰度/曝光/对比度的估算。", color = T.text2, fontSize = T.caption)
                Text("在系统相册里收藏过的照片不会出现在任何清理分类里，也不会被自动标记删除。", color = T.text2, fontSize = T.caption)
            }
            Spacer(Modifier.height(30.dp))
        }
    }
    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("清除分析缓存？") },
            text = { Text("会重新分析所有照片，需要一些时间。标记不会丢。") },
            confirmButton = { TextButton(onClick = { confirmClear = false; vm.clearAnalysisCache() }) { Text("清除", color = T.danger) } },
            dismissButton = { TextButton(onClick = { confirmClear = false }) { Text("取消") } },
            containerColor = T.card,
        )
    }
}

@Composable
private fun Group(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, color = T.text2, fontSize = T.caption, modifier = Modifier.padding(start = 4.dp))
        Column(Modifier.fillMaxWidth().card(radius = 20.dp, padding = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
    }
}

@Composable
private fun SliderRow(label: String, value: Float, range: ClosedFloatingPointRange<Float>, display: String, onChange: (Float) -> Unit) {
    var v by remember(value) { mutableFloatStateOf(value) }
    Column {
        Row {
            Text(label, color = T.text, fontSize = T.body, modifier = Modifier.weight(1f))
            Text(display, color = T.accent, fontSize = T.callout, fontWeight = FontWeight.SemiBold)
        }
        Slider(v, { v = it }, valueRange = range, onValueChangeFinished = { onChange(v) },
            colors = SliderDefaults.colors(thumbColor = T.accent, activeTrackColor = T.accent, inactiveTrackColor = T.fillHigh))
    }
}
