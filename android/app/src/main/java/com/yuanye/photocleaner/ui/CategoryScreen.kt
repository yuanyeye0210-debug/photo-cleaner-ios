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
import androidx.compose.ui.zIndex
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.Phase
import com.yuanye.photocleaner.R
import com.yuanye.photocleaner.core.Decision
import com.yuanye.photocleaner.core.Fmt

/** 某个分类：「滑动筛选」和「网格多选」两种模式 */
@Composable
fun CategoryScreen(vm: CleanupViewModel, title: String, ids: List<String>, extra: (@Composable () -> Unit)? = null) {
    val a = LocalActions.current
    var mode by rememberSaveable { mutableIntStateOf(0) }
    val labels = listOf(s(R.string.mode_swipe), s(R.string.mode_grid))
    val marked = ids.filter { it in vm.toDelete }
    val done = ids.count { vm.decision(it) != null }
    Column(Modifier.fillMaxSize()) {
        // zIndex：顶部栏、进度和「滑动筛选 / 网格多选」始终压在卡片上面，点按优先（卡片拖上来也不会盖住）
        Box(Modifier.zIndex(2f)) { TopBar(title, a.pop) }
        Column(Modifier.zIndex(2f).padding(horizontal = T.pagePadding).padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 进度：已看 / 总数，标记数 + 可释放
            Row(Modifier.fillMaxWidth().card(radius = 20.dp, padding = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                RingGauge(if (ids.isEmpty()) 0f else done.toFloat() / ids.size, "", "", Modifier.size(44.dp))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(s(R.string.seen_n, done, ids.size), color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                    Text(s(R.string.marked_n_size, marked.size, Fmt.bytes(vm.bytes(marked))), color = T.text2, fontSize = T.caption)
                }
            }
            extra?.invoke()
            Segmented(listOf(0, 1), mode, { labels[it] }) { mode = it }
        }
        if (ids.isEmpty()) {
            EmptyState(Icons.Rounded.Check, s(R.string.empty_clean), if (vm.phase == Phase.DONE) s(R.string.empty_none) else s(R.string.empty_analyzing),
                Modifier.weight(1f))
        } else if (mode == 0) {
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
    val toggleLabel = s(R.string.a11y_toggle_delete)
    val previewLabel = s(R.string.a11y_preview)
    LazyVerticalGrid(
        GridCells.Adaptive(104.dp), modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 40.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 4.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SecondaryButton(s(R.string.select_all), Icons.Rounded.CheckCircle) {
                        Haptics.medium(view); vm.markAll(ids.filter { vm.decision(it) != Decision.KEEP }, Decision.DELETE)
                    }
                    SecondaryButton(s(R.string.deselect_all), Icons.Rounded.RadioButtonUnchecked, T.text2) {
                        Haptics.light(view); vm.markAll(ids.filter { it in vm.toDelete }, null)
                    }
                }
                Text(s(R.string.grid_hint), color = T.text3, fontSize = T.caption)
            }
        }
        items(ids, key = { it }) { id ->
            val item = vm.item(id) ?: return@items
            ThumbnailCell(
                item, marked = id in vm.toDelete, kept = id in vm.kept,
                modifier = Modifier.combinedClickable(
                    onClickLabel = toggleLabel, onLongClickLabel = previewLabel,
                    onClick = { Haptics.light(view); vm.toggleDelete(id) },
                    onLongClick = { Haptics.medium(view); a.preview(item) },
                ),
            )
        }
    }
}
