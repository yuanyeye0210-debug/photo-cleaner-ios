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
import com.yuanye.photocleaner.R
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Fmt

/** 「分类」页：分类列表 / 按月时间线 */
@Composable
fun LibraryScreen(vm: CleanupViewModel) {
    var mode by rememberSaveable { mutableIntStateOf(0) }
    val a = LocalActions.current
    val labels = listOf(s(R.string.tab_library), s(R.string.timeline))
    Column(Modifier.fillMaxSize().padding(horizontal = T.pagePadding), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(s(R.string.tab_library), color = T.text, fontSize = T.largeTitle, fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 8.dp).semantics { heading() })
        Segmented(listOf(0, 1), mode, { labels[it] }) { mode = it }
        if (mode == 0) {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(bottom = 120.dp)) {
                item { Text(s(R.string.n_categories, CleanCategory.entries.size), color = T.text2, fontSize = T.caption) }
                items(CleanCategory.entries) { c -> CategoryRow(vm, c, Modifier.pressable { a.push(Route.Category(c)) }) }
            }
        } else {
            if (vm.months.isEmpty()) {
                EmptyState(Icons.Rounded.CalendarMonth, s(R.string.no_data), s(R.string.no_data_months))
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
    Row(modifier.fillMaxWidth().height(78.dp).card(radius = 22.dp).semantics(mergeDescendants = true) { }.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
        IconBadge(c.icon, size = 40.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(s(c.titleRes), color = T.text, fontSize = T.headline, fontWeight = FontWeight.SemiBold)
            Text(s(c.subtitleRes), color = T.text2, fontSize = T.caption, maxLines = 1)
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
    val cleaned = vm.isMonthCleaned(m.key)
    val unit = s(R.string.month_unit).ifEmpty { java.text.DateFormatSymbols.getInstance().shortMonths.getOrElse(m.month - 1) { "" } }
    Column(Modifier.fillMaxWidth().card(padding = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.semantics(mergeDescendants = true) { }) {
            Text("${m.month}", color = if (cleaned) T.text3 else T.accent, fontSize = 40.sp, fontWeight = FontWeight.Bold, lineHeight = 40.sp)
            Text(unit, color = T.text2, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(start = 4.dp, bottom = 4.dp))
            Text("${m.year}", color = T.text3, fontSize = T.caption, modifier = Modifier.padding(start = 6.dp, bottom = 6.dp))
            Spacer(Modifier.weight(1f))
            if (cleaned) PillBadge(s(R.string.month_cleaned), T.keep)
            if (marked > 0) { Spacer(Modifier.width(6.dp)); PillBadge(s(R.string.delete_n, marked), T.danger) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.alpha(if (cleaned) 0.45f else 1f)) {
            m.ids.take(4).forEach { id ->
                val item = vm.item(id)
                Box(Modifier.weight(1f).height(64.dp).clip(RoundedCornerShape(10.dp))) {
                    if (item != null) AsyncImage(remember(id) { thumbRequest(ctx, item) }, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                }
            }
            repeat(maxOf(0, 4 - m.ids.size)) { Spacer(Modifier.weight(1f)) }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(s(R.string.n_items_size, m.ids.size, Fmt.bytes(vm.bytes(m.ids))), color = T.text2, fontSize = T.caption, modifier = Modifier.weight(1f))
            Text(if (cleaned) s(R.string.month_unmark) else s(R.string.month_mark), color = T.text2, fontSize = T.caption, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.pressable { vm.toggleMonthCleaned(m.key) }.padding(horizontal = 8.dp, vertical = 4.dp))
            PillBadge(s(R.string.organize), modifier = Modifier.pressable(onClick = onOpen))
        }
    }
}
