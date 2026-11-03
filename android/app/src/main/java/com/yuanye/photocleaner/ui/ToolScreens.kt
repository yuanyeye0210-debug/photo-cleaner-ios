package com.yuanye.photocleaner.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Compress
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.Phase
import com.yuanye.photocleaner.QuickMode
import com.yuanye.photocleaner.R
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Fmt

/** 视频分类顶部：进入「压缩成 HEVC」 */
@Composable
fun CompressEntry(onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().card(radius = 20.dp, padding = 14.dp).pressable(onClick = onClick).semantics(mergeDescendants = true) { },
        verticalAlignment = Alignment.CenterVertically) {
        IconBadge(Icons.Rounded.Compress, size = 34.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(s(R.string.compress_entry), color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text(s(R.string.compress_entry_sub), color = T.text2, fontSize = T.caption)
        }
        Icon(Icons.Rounded.ChevronRight, null, tint = T.text3, modifier = Modifier.size(18.dp))
    }
}

/** 月份详情顶部：标记本月已整理 */
@Composable
fun MonthCleanedToggle(vm: CleanupViewModel, key: String) {
    val on = vm.isMonthCleaned(key)
    Row(Modifier.fillMaxWidth().card(radius = 20.dp, padding = 14.dp).pressable { vm.toggleMonthCleaned(key) }
        .semantics(mergeDescendants = true) { selected = on }, verticalAlignment = Alignment.CenterVertically) {
        Icon(if (on) Icons.Rounded.TaskAlt else Icons.Rounded.RadioButtonUnchecked, null, tint = if (on) T.keep else T.text2, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(10.dp))
        Text(if (on) s(R.string.month_cleaned_on) else s(R.string.month_mark_long), color = T.text, fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
    }
}

/** 小批量：那年今日 / 随机 10 张 / 稍后再看 —— 进来时固定这一批，用滑动整理 */
@Composable
fun QuickScreen(vm: CleanupViewModel, mode: QuickMode) {
    val a = LocalActions.current
    var batch by remember { mutableIntStateOf(0) }
    val ready = vm.items.isNotEmpty()
    val ids = remember(batch, ready) { if (ready) vm.quickIds(mode) else emptyList() }
    val title = when (mode) {
        QuickMode.ON_THIS_DAY -> s(R.string.quick_on_this_day)
        QuickMode.RANDOM -> s(R.string.quick_random)
        QuickMode.LATER -> s(R.string.quick_later)
    }
    Column(Modifier.fillMaxSize()) {
        TopBar(title, a.pop) {
            if (mode == QuickMode.RANDOM) Box(
                Modifier.size(40.dp).clip(CircleShape).background(T.card).pressable { batch++ },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Refresh, s(R.string.quick_another), tint = T.text, modifier = Modifier.size(20.dp)) }
        }
        Text(
            when (mode) {
                QuickMode.ON_THIS_DAY -> s(R.string.quick_on_this_day_desc)
                QuickMode.RANDOM -> s(R.string.quick_random_desc)
                QuickMode.LATER -> s(R.string.quick_later_desc)
            },
            color = T.text2, fontSize = T.caption, modifier = Modifier.padding(horizontal = T.pagePadding).padding(bottom = 6.dp),
        )
        if (ids.isEmpty()) {
            EmptyState(Icons.Rounded.Check, s(R.string.quick_empty),
                if (vm.scanning && !ready) s(R.string.empty_analyzing) else s(R.string.quick_empty_sub), Modifier.weight(1f))
        } else {
            key(batch) { SwipeReview(vm, ids, Modifier.weight(1f), finishedTitle = R.string.quick_finished) }
        }
    }
}

/** 桌面小组件进来：所有可清理、还没看过的，直接滑 */
@Composable
fun SwipeAllScreen(vm: CleanupViewModel) {
    val a = LocalActions.current
    var ids by remember { mutableStateOf<List<String>?>(null) }
    LaunchedEffect(vm.cleanableIds, vm.phase) {
        if (ids == null && (vm.cleanableIds.isNotEmpty() || vm.phase == Phase.DONE)) {
            val order = CleanCategory.entries.filter { !it.isBrowse }.flatMap { vm.ids(it) }.distinct()
            ids = vm.undecided(order.filter { it in vm.cleanableIds })
        }
    }
    Column(Modifier.fillMaxSize()) {
        TopBar(s(R.string.widget_swipe_title), a.pop)
        val list = ids
        when {
            list == null -> EmptyState(Icons.Rounded.Refresh, s(R.string.status_scanning), vm.progressText, Modifier.weight(1f))
            list.isEmpty() -> EmptyState(Icons.Rounded.Check, s(R.string.empty_clean), s(R.string.empty_none), Modifier.weight(1f))
            else -> SwipeReview(vm, list, Modifier.weight(1f))
        }
    }
}

/** 可勾选的缩略图（不是「删除」标记，用强调色） */
@Composable
private fun SelectThumb(vm: CleanupViewModel, id: String, on: Boolean, onToggle: () -> Unit) {
    val a = LocalActions.current
    val item = vm.item(id) ?: return
    Box(Modifier.semantics { selected = on }) {
        ThumbnailCell(item, marked = false, kept = false, modifier = Modifier
            .then(if (on) Modifier.border(3.dp, T.accent, RoundedCornerShape(12.dp)) else Modifier)
            .combinedClickable(
                onClickLabel = s(R.string.a11y_select), onLongClickLabel = s(R.string.a11y_preview),
                onClick = onToggle, onLongClick = { a.preview(item) },
            ))
        if (on) Box(Modifier.align(Alignment.TopEnd).padding(5.dp).size(22.dp).clip(CircleShape).background(T.accent),
            contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Check, null, tint = Color.Black, modifier = Modifier.size(15.dp)) }
        Text(Fmt.bytes(item.fileSize), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
            modifier = Modifier.align(Alignment.BottomEnd).padding(4.dp).clip(RoundedCornerShape(6.dp))
                .background(Color.Black.copy(alpha = 0.55f)).padding(horizontal = 4.dp, vertical = 1.dp))
    }
}

@Composable
private fun ToolLayout(
    vm: CleanupViewModel, title: String, ids: List<String>, selected: Set<String>, onSelect: (Set<String>) -> Unit,
    explain: List<String>, supported: Boolean, unsupportedText: String, button: String, onRun: () -> Unit,
) {
    val a = LocalActions.current
    val view = LocalView.current
    Column(Modifier.fillMaxSize()) {
        TopBar(title, a.pop)
        LazyVerticalGrid(
            GridCells.Adaptive(104.dp), Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(start = 14.dp, end = 14.dp, bottom = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(Modifier.fillMaxWidth().card(padding = 16.dp).padding(bottom = 2.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    explain.forEach { Text(it, color = T.text2, fontSize = T.callout) }
                    if (!supported) Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Info, null, tint = T.danger, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(unsupportedText, color = T.danger, fontSize = T.callout)
                    }
                }
            }
            if (ids.isNotEmpty()) item(span = { GridItemSpan(maxLineSpan) }) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 4.dp)) {
                    SecondaryButton(s(R.string.select_all), Icons.Rounded.CheckCircle) { Haptics.medium(view); onSelect(ids.toSet()) }
                    SecondaryButton(s(R.string.deselect_all), Icons.Rounded.RadioButtonUnchecked, T.text2) { Haptics.light(view); onSelect(emptySet()) }
                }
            }
            items(ids, key = { it }) { id ->
                SelectThumb(vm, id, id in selected) { Haptics.light(view); onSelect(if (id in selected) selected - id else selected + id) }
            }
        }
        if (ids.isEmpty()) EmptyState(Icons.Rounded.Check, s(R.string.empty_clean), s(R.string.empty_none), Modifier.weight(1f))
        PrimaryButton(button, Modifier.padding(horizontal = T.pagePadding, vertical = 10.dp),
            enabled = supported && selected.isNotEmpty() && vm.tool?.running != true) { Haptics.medium(view); onRun() }
    }
}

/** 视频压缩成 HEVC：新文件保留拍摄时间和地点，原视频进「待删除」 */
@Composable
fun CompressScreen(vm: CleanupViewModel) {
    val ids = remember(vm.items, vm.toDelete) {
        vm.items.filter { it.isVideo && it.id !in vm.toDelete && !it.name.contains("_HEVC") }.sortedByDescending { it.fileSize }.map { it.id }
    }
    var selected by remember { mutableStateOf(emptySet<String>()) }
    val sel = selected.filter { it in ids }.toSet()
    ToolLayout(
        vm, s(R.string.compress_title), ids, sel, { selected = it },
        listOf(s(R.string.compress_explain1), s(R.string.compress_explain2)),
        vm.compressor.supported, s(R.string.compress_unsupported),
        s(R.string.compress_button, sel.size, Fmt.bytes(vm.bytes(sel))),
    ) { vm.compressVideos(ids.filter { it in sel }); selected = emptySet() }
}

/** 动态照片转静态：去掉里面的小视频，原照片进「待删除」 */
@Composable
fun MotionScreen(vm: CleanupViewModel) {
    val ids = vm.ids(CleanCategory.MOTION).filter { it !in vm.toDelete }
    var selected by remember { mutableStateOf<Set<String>?>(null) }
    val sel = (selected ?: ids.toSet()).filter { it in ids }.toSet()
    val saving = sel.sumOf { vm.item(it)?.analysis?.motionBytes ?: 0L }
    ToolLayout(
        vm, s(R.string.cat_motion), ids, sel, { selected = it },
        listOf(s(R.string.motion_explain1), s(R.string.motion_explain2)),
        vm.motionConverter.supported, s(R.string.android10_needed),
        s(R.string.motion_button, sel.size, Fmt.bytes(saving)),
    ) { vm.convertMotion(ids.filter { it in sel }); selected = emptySet() }
}

