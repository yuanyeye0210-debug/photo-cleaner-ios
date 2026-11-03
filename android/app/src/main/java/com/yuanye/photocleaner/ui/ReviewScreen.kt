package com.yuanye.photocleaner.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.core.Fmt

/** 「清理」：所有标记删除的照片，点一下取消标记，底部一键删除（系统会再确认） */
@Composable
fun ReviewScreen(vm: CleanupViewModel, inTab: Boolean) {
    val a = LocalActions.current
    val view = LocalView.current
    val ids = vm.items.map { it.id }.filter { it in vm.toDelete }
    var working by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()) {
        if (!inTab) TopBar("待删除", a.pop)
        LazyVerticalGrid(
            GridCells.Adaptive(96.dp), Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = T.pagePadding, vertical = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(Modifier.padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (inTab) Text("清理", color = T.text, fontSize = T.largeTitle, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
                    Text(
                        if (vm.useTrash && vm.trashSupported) "删除后进入系统回收站，30 天内可恢复" else "删除后无法恢复",
                        color = T.text2, fontSize = T.caption,
                    )
                    if (ids.isNotEmpty()) Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("点缩略图取消标记，长按看大图", color = T.text3, fontSize = T.caption, modifier = Modifier.weight(1f))
                        Text("清空", color = T.accent, fontSize = T.callout, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.pressable { Haptics.light(view); vm.markAll(ids, null) }.padding(6.dp))
                    }
                }
            }
            if (ids.isEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    EmptyState(Icons.Rounded.TaskAlt, "还没有要删除的", "在分类里左滑或多选标记删除", Modifier.height(360.dp))
                }
            }
            items(ids, key = { it }) { id ->
                val item = vm.item(id) ?: return@items
                ThumbnailCell(item, marked = true, kept = false, modifier = Modifier.combinedClickable(
                    onClick = { Haptics.light(view); vm.set(id, null) },
                    onLongClick = { Haptics.medium(view); a.preview(item) },
                ))
            }
            item(span = { GridItemSpan(maxLineSpan) }) { Spacer(Modifier.height(if (inTab) 110.dp else 20.dp)) }
        }
        if (ids.isNotEmpty()) {
            Row(
                Modifier.fillMaxWidth().background(T.bg).padding(horizontal = T.pagePadding, vertical = 10.dp)
                    .padding(bottom = if (inTab) 86.dp else 0.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("${ids.size} 项", color = T.text, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                    Text(Fmt.bytes(vm.bytes(ids)), color = T.text2, fontSize = T.caption)
                }
                PrimaryButton(if (working) "等待确认…" else "删除", Modifier.width(160.dp), tint = T.danger, enabled = !working) {
                    Haptics.warning(view)
                    working = true
                    a.delete(ids) { working = false }
                }
            }
        }
    }
}
