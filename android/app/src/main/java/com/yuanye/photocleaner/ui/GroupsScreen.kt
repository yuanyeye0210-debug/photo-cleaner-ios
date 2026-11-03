package com.yuanye.photocleaner.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DeleteSweep
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
import com.yuanye.photocleaner.R
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Decision
import com.yuanye.photocleaner.core.Fmt

/** 每组最多直接显示这么多张缩略图（再多的用「还有 N 张」） */
private const val MAX_THUMBS = 24

/**
 * 分组页：相似照片 / 完全重复 / 连拍。
 * 每组推荐保留一张；可以「保留推荐，删其余」「全部保留」，或者「整组全部删除」（一张都不留）。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GroupsScreen(vm: CleanupViewModel, c: CleanCategory) {
    val a = LocalActions.current
    val view = LocalView.current
    var confirmAll by remember { mutableStateOf(false) }
    var confirmWhole by remember { mutableStateOf<List<String>?>(null) }
    val groups = vm.groups(c)
    // 推荐保留 / 可释放只在分组变化时算一次（以前每次点选、每个扫描批次都要重算）
    val bests = remember(groups, c) { groups.map { vm.bestId(it, c) } }
    val extras = remember(groups, bests) { groups.zip(bests).flatMap { (g, b) -> g.filter { it != b && vm.item(it)?.isFavorite != true } } }
    val extraBytes = remember(extras) { vm.bytes(extras) }
    val (headerTitle, headerSub, groupTitle) = when (c) {
        CleanCategory.DUPLICATES -> Triple(R.string.groups_dup_n, R.string.groups_dup_sub, R.string.group_dup_n)
        CleanCategory.BURSTS -> Triple(R.string.groups_burst_n, R.string.groups_burst_sub, R.string.group_burst_n)
        else -> Triple(R.string.groups_similar_n, R.string.groups_similar_sub, R.string.group_similar_n)
    }
    Column(Modifier.fillMaxSize()) {
        TopBar(s(c.titleRes), a.pop)
        if (groups.isEmpty()) {
            EmptyState(Icons.Rounded.Check, s(R.string.groups_empty),
                if (vm.phase == Phase.DONE) s(R.string.empty_none) else vm.progressText.ifEmpty { s(R.string.empty_analyzing) }, Modifier.weight(1f))
            return@Column
        }
        LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(T.pagePadding, 4.dp, T.pagePadding, 40.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Column(Modifier.fillMaxWidth().card(padding = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    CardHeader(Icons.Rounded.AutoAwesome, s(headerTitle, groups.size))
                    Text(s(headerSub), color = T.text2, fontSize = T.callout)
                    Text(s(R.string.can_free_size, Fmt.bytes(extraBytes)), color = T.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                    PrimaryButton(s(R.string.handle_all_n, extras.size), enabled = extras.isNotEmpty()) { Haptics.medium(view); confirmAll = true }
                }
            }
            itemsIndexed(groups, key = { _, g -> g.first() }) { i, g ->
                val best = bests[i]
                val favs = g.count { vm.item(it)?.isFavorite == true }
                Column(Modifier.fillMaxWidth().card(padding = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(s(groupTitle, g.size), color = T.text, fontSize = T.headline, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        vm.item(g.first())?.dateMillis?.let { Text(fmtDate(it), color = T.text2, fontSize = T.caption) }
                    }
                    val shown = g.take(MAX_THUMBS)
                    shown.chunked(3).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            row.forEach { id ->
                                val item = vm.item(id)
                                if (item != null) Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally) {
                                    ThumbnailCell(
                                        item, marked = id in vm.toDelete, kept = id in vm.kept, isBest = id == best,
                                        modifier = Modifier.fillMaxWidth().combinedClickable(
                                            onClickLabel = s(R.string.a11y_toggle_delete), onLongClickLabel = s(R.string.a11y_preview),
                                            onClick = { Haptics.light(view); vm.toggleDelete(id) },
                                            onLongClick = { Haptics.medium(view); a.preview(item) },
                                        ),
                                    )
                                    // 分错了：把这张从组里拿出来，并记住（重新扫描也不会再分进来）
                                    if (c == CleanCategory.SIMILAR) {
                                        val label = s(R.string.a11y_not_similar)
                                        Text(
                                            s(R.string.not_similar), color = T.text2, fontSize = T.caption,
                                            modifier = Modifier.clip(RoundedCornerShape(50)).background(T.fill)
                                                .clickable(onClickLabel = label) { Haptics.light(view); vm.markNotSimilar(id, g) }
                                                .padding(horizontal = 10.dp, vertical = 5.dp),
                                        )
                                    }
                                } else Spacer(Modifier.weight(1f))
                            }
                            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                    if (g.size > shown.size) Text(s(R.string.n_more, g.size - shown.size), color = T.text3, fontSize = T.caption)
                    if (favs > 0) Text(s(R.string.group_favs_note, favs), color = T.text3, fontSize = T.caption)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        val rest = g.count { it != best && vm.item(it)?.isFavorite != true }
                        SecondaryButton(s(R.string.keep_best_delete_rest, rest)) { Haptics.medium(view); vm.keepBestDeleteRest(g, c) }
                        SecondaryButton(s(R.string.keep_all), tint = T.text2) { Haptics.light(view); vm.markAll(g, Decision.KEEP) }
                        if (vm.deletableCount(g) > 0) {
                            SecondaryButton(s(R.string.delete_whole_group), Icons.Rounded.DeleteSweep, tint = T.danger) {
                                Haptics.warning(view); confirmWhole = g
                            }
                        }
                    }
                }
            }
        }
    }
    if (confirmAll) {
        AlertDialog(
            onDismissRequest = { confirmAll = false },
            title = { Text(s(R.string.handle_all_title)) },
            text = { Text(s(R.string.mark_only_note)) },
            confirmButton = {
                TextButton(onClick = { confirmAll = false; groups.forEach { vm.keepBestDeleteRest(it, c) }; Haptics.success(view) }) {
                    Text(s(R.string.handle_all_confirm, extras.size), color = T.danger)
                }
            },
            dismissButton = { TextButton(onClick = { confirmAll = false }) { Text(s(R.string.cancel)) } },
            containerColor = T.card,
        )
    }
    confirmWhole?.let { g ->
        val n = vm.deletableCount(g)
        val favs = g.size - n
        AlertDialog(
            onDismissRequest = { confirmWhole = null },
            title = { Text(s(R.string.whole_group_title, n)) },
            text = {
                Text(buildString {
                    append(s(R.string.mark_only_note))
                    if (favs > 0) append("\n").append(s(R.string.group_favs_note, favs))
                })
            },
            confirmButton = {
                TextButton(onClick = { confirmWhole = null; vm.deleteWholeGroup(g); Haptics.success(view) }) {
                    Text(s(R.string.delete_whole_group), color = T.danger)
                }
            },
            dismissButton = { TextButton(onClick = { confirmWhole = null }) { Text(s(R.string.cancel)) } },
            containerColor = T.card,
        )
    }
}
