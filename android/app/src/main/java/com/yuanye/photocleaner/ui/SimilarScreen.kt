package com.yuanye.photocleaner.ui

import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.Phase
import com.yuanye.photocleaner.core.Decision
import com.yuanye.photocleaner.core.Fmt
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 相似照片：按组显示，每组推荐保留一张（表情 > 质量评分 > 清晰度 > 像素） */
@Composable
fun SimilarScreen(vm: CleanupViewModel) {
    val a = LocalActions.current
    val view = LocalView.current
    var confirmAll by remember { mutableStateOf(false) }
    val groups = vm.similarGroups
    val bests = groups.map { vm.bestId(it) }
    val extras = groups.zip(bests).flatMap { (g, b) -> g.filter { it != b } }
    Column(Modifier.fillMaxSize()) {
        TopBar("相似照片", a.pop)
        if (groups.isEmpty()) {
            EmptyState(Icons.Rounded.Check, "没有相似照片", if (vm.phase == Phase.DONE) "相册里没有找到连拍或重复的照片" else vm.progressText.ifEmpty { "分析中…" }, Modifier.weight(1f))
            return@Column
        }
        LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(T.pagePadding, 4.dp, T.pagePadding, 40.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Column(Modifier.fillMaxWidth().card(padding = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    CardHeader(Icons.Rounded.AutoAwesome, "${groups.size} 组相似")
                    Text("每组留最好的一张（看表情、质量评分和清晰度）", color = T.text2, fontSize = T.callout)
                    Text("可释放 ${Fmt.bytes(vm.bytes(extras))}", color = T.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    PrimaryButton("一键处理全部 ${extras.size} 张", enabled = extras.isNotEmpty()) { Haptics.medium(view); confirmAll = true }
                }
            }
            itemsIndexed(groups, key = { _, g -> g.first() }) { i, g ->
                val best = bests[i]
                Column(Modifier.fillMaxWidth().card(padding = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${g.size} 张相似", color = T.text, fontSize = T.headline, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        vm.item(g.first())?.dateMillis?.let {
                            Text(SimpleDateFormat("yyyy/M/d HH:mm", Locale.CHINA).format(Date(it)), color = T.text2, fontSize = T.caption)
                        }
                    }
                    g.chunked(3).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            row.forEach { id ->
                                val item = vm.item(id)
                                if (item != null) ThumbnailCell(
                                    item, marked = id in vm.toDelete, kept = id in vm.kept, isBest = id == best,
                                    modifier = Modifier.weight(1f).combinedClickable(
                                        onClick = { Haptics.light(view); vm.toggleDelete(id) },
                                        onLongClick = { Haptics.medium(view); a.preview(item) },
                                    ),
                                ) else Spacer(Modifier.weight(1f))
                            }
                            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        SecondaryButton("保留推荐，删其余 ${g.size - 1} 张") { Haptics.medium(view); vm.keepBestDeleteRest(g) }
                        SecondaryButton("全部保留", tint = T.text2) { Haptics.light(view); vm.markAll(g, Decision.KEEP) }
                    }
                }
            }
        }
    }
    if (confirmAll) {
        AlertDialog(
            onDismissRequest = { confirmAll = false },
            title = { Text("每组只保留推荐的一张，其余全部选为删除？") },
            text = { Text("只是标记，不会立刻删除。最后还要在「清理」页再确认一次。") },
            confirmButton = { TextButton(onClick = { confirmAll = false; groups.forEach { vm.keepBestDeleteRest(it) }; Haptics.success(view) }) { Text("全部处理（${extras.size} 张）", color = T.danger) } },
            dismissButton = { TextButton(onClick = { confirmAll = false }) { Text("取消") } },
            containerColor = T.card,
        )
    }
}
