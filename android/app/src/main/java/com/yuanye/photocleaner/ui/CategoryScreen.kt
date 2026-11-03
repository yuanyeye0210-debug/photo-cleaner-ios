package com.yuanye.photocleaner.ui

import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
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

/** 某个分类：「滑动筛选」和「网格多选」两种模式 */
@Composable
fun CategoryScreen(vm: CleanupViewModel, title: String, ids: List<String>) {
    val a = LocalActions.current
    var mode by rememberSaveable { mutableStateOf("滑动筛选") }
    val marked = ids.filter { it in vm.toDelete }
    val done = ids.count { vm.decision(it) != null }
    Column(Modifier.fillMaxSize()) {
        TopBar(title, a.pop)
        Column(Modifier.padding(horizontal = T.pagePadding).padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 进度：已看 / 总数，标记数 + 可释放
            Row(Modifier.fillMaxWidth().card(radius = 20.dp, padding = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                RingGauge(if (ids.isEmpty()) 0f else done.toFloat() / ids.size, "", "", Modifier.size(44.dp))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text("已看 $done / ${ids.size}", color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text("标记删除 ${marked.size} 项 · ${Fmt.bytes(vm.bytes(marked))}", color = T.text2, fontSize = T.caption)
                }
            }
            Segmented(listOf("滑动筛选", "网格多选"), mode, { it }) { mode = it }
        }
        if (ids.isEmpty()) {
            EmptyState(Icons.Rounded.Check, "这里很干净", if (vm.phase == Phase.DONE) "没有找到需要清理的内容" else "还在分析中，稍后再来看看",
                Modifier.weight(1f))
        } else if (mode == "滑动筛选") {
            SwipeReview(vm, ids, Modifier.weight(1f))
        } else {
            GridSelect(vm, ids, Modifier.weight(1f))
        }
    }
}

/** 网格多选：点一下标记/取消删除，长按看大图 */
@Composable
fun GridSelect(vm: CleanupViewModel, ids: List<String>, modifier: Modifier = Modifier) {
    val a = LocalActions.current
    val view = LocalView.current
    LazyVerticalGrid(
        GridCells.Adaptive(104.dp), modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 40.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 4.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SecondaryButton("全选", Icons.Rounded.CheckCircle) {
                        Haptics.medium(view); vm.markAll(ids.filter { vm.decision(it) != Decision.KEEP }, Decision.DELETE)
                    }
                    SecondaryButton("取消全选", Icons.Rounded.RadioButtonUnchecked, T.text2) {
                        Haptics.light(view); vm.markAll(ids.filter { it in vm.toDelete }, null)
                    }
                }
                Text("点一下选中删除，长按看大图。已标记「保留」的不会被全选。", color = T.text3, fontSize = T.caption)
            }
        }
        items(ids, key = { it }) { id ->
            val item = vm.item(id) ?: return@items
            ThumbnailCell(
                item, marked = id in vm.toDelete, kept = id in vm.kept,
                modifier = Modifier.combinedClickable(
                    onClick = { Haptics.light(view); vm.toggleDelete(id) },
                    onLongClick = { Haptics.medium(view); a.preview(item) },
                ),
            )
        }
    }
}
