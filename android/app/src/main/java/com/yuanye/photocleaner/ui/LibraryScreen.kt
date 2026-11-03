package com.yuanye.photocleaner.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.MonthGroup
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Fmt

/** 「分类」页：分类列表 / 按月时间线 */
@Composable
fun LibraryScreen(vm: CleanupViewModel) {
    var mode by rememberSaveable { mutableStateOf("分类") }
    val a = LocalActions.current
    Column(Modifier.fillMaxSize().padding(horizontal = T.pagePadding), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("分类", color = T.text, fontSize = T.largeTitle, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
        Segmented(listOf("分类", "时间线"), mode, { it }) { mode = it }
        if (mode == "分类") {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(bottom = 120.dp)) {
                item { Text("${CleanCategory.entries.size} 个分类", color = T.text2, fontSize = T.caption) }
                items(CleanCategory.entries) { c -> CategoryRow(vm, c, Modifier.pressable { a.push(Route.Category(c)) }) }
            }
        } else {
            if (vm.months.isEmpty()) {
                EmptyState(Icons.Rounded.CalendarMonth, "还没有数据", "扫描完成后按月份显示")
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(bottom = 120.dp)) {
                    items(vm.months, key = { it.key }) { m -> MonthCard(vm, m) { a.push(Route.Month(m.key)) } }
                }
            }
        }
    }
}

@Composable
private fun CategoryRow(vm: CleanupViewModel, c: CleanCategory, modifier: Modifier) {
    val ids = vm.ids(c)
    Row(modifier.fillMaxWidth().height(78.dp).card(radius = 22.dp).padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        IconBadge(c.icon, size = 40.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(c.title, color = T.text, fontSize = T.headline, fontWeight = FontWeight.SemiBold)
            Text(c.subtitle, color = T.text2, fontSize = T.caption, maxLines = 1)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("${ids.size}", color = T.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(Fmt.bytes(vm.bytes(ids)), color = T.text2, fontSize = T.caption)
        }
        Spacer(Modifier.width(8.dp))
        Icon(Icons.Rounded.ChevronRight, null, tint = T.text3, modifier = Modifier.size(18.dp))
    }
}

@Composable
private fun MonthCard(vm: CleanupViewModel, m: MonthGroup, onOpen: () -> Unit) {
    val ctx = LocalContext.current
    val marked = m.ids.count { it in vm.toDelete }
    Column(Modifier.fillMaxWidth().card(padding = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text("${m.month}", color = T.accent, fontSize = 40.sp, fontWeight = FontWeight.Bold, lineHeight = 40.sp)
            Text("月", color = T.text2, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp, bottom = 4.dp))
            Text("${m.year}", color = T.text3, fontSize = T.caption, modifier = Modifier.padding(start = 6.dp, bottom = 6.dp))
            Spacer(Modifier.weight(1f))
            if (marked > 0) PillBadge("删除 $marked", T.danger)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            m.ids.take(4).forEach { id ->
                val item = vm.item(id)
                Box(Modifier.weight(1f).height(64.dp).clip(RoundedCornerShape(10.dp))) {
                    if (item != null) AsyncImage(remember(id) { thumbRequest(ctx, item) }, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                }
            }
            repeat(maxOf(0, 4 - m.ids.size)) { Spacer(Modifier.weight(1f)) }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("${m.ids.size} 项 · ${Fmt.bytes(vm.bytes(m.ids))}", color = T.text2, fontSize = T.caption, modifier = Modifier.weight(1f))
            PillBadge("整理 ›", modifier = Modifier.pressable(onClick = onOpen))
        }
    }
}
