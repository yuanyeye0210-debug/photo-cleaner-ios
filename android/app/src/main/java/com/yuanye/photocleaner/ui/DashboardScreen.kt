package com.yuanye.photocleaner.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Photo
import androidx.compose.material.icons.rounded.SdStorage
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.Access
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.Phase
import com.yuanye.photocleaner.QuickMode
import com.yuanye.photocleaner.R
import androidx.compose.foundation.Canvas
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.runtime.remember
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Fmt
import kotlin.math.roundToInt

/** 首页：问候 + 相册状态（圆环 + 2×2 指标）+ 待删除 + 分类 */
@Composable
fun DashboardScreen(vm: CleanupViewModel, openSettings: () -> Unit) {
    val a = LocalActions.current
    val settingsLabel = s(R.string.settings)
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = T.pagePadding),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(s(R.string.greeting_fmt, s(T.greeting()), vm.userName.ifBlank { s(R.string.hello) }), color = T.text, fontSize = 24.sp,
                fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Box(
                Modifier.size(46.dp).clip(CircleShape).background(T.accent.copy(alpha = 0.2f)).pressable(onClick = openSettings)
                    .semantics(mergeDescendants = true) { contentDescription = settingsLabel },
                contentAlignment = Alignment.Center,
            ) {
                Text(vm.userName.take(1).ifEmpty { s(R.string.me) }, color = T.accent, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }

        StatusCard(vm)

        if (vm.access == Access.LIMITED) {
            Row(Modifier.fillMaxWidth().card(padding = 14.dp)) {
                Icon(Icons.Rounded.Info, null, tint = T.accent, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(10.dp))
                Text(s(R.string.limited_note), color = T.text2, fontSize = T.caption)
            }
        }

        PendingCard(vm, Modifier.pressable { a.push(Route.Review) })

        SectionHeader(s(R.string.quick_title))
        QuickRow(vm)

        StatsCard(vm)

        SectionHeader(s(R.string.categories), if (vm.phase == Phase.DONE) s(R.string.analysis_done) else vm.progressText)
        CleanCategory.entries.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(T.gap)) {
                row.forEach { c -> CategoryCard(vm, c, Modifier.weight(1f).pressable { a.push(Route.Category(c)) }) }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        Spacer(Modifier.height(110.dp))
    }
}

@Composable
private fun StatusCard(vm: CleanupViewModel) {
    val scanning = vm.scanning
    val cleanable = vm.cleanableIds
    val cleanableBytes = vm.bytes(cleanable)
    val ratio = if (vm.totalBytes > 0) cleanableBytes.toFloat() / vm.totalBytes else 0f
    val videos = vm.items.count { it.isVideo }
    val shown = if (scanning) vm.progress else ratio
    Column(Modifier.fillMaxWidth().card(padding = 18.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        CardHeader(Icons.Rounded.Speed, s(R.string.status_title)) {
            PillBadge(when {
                vm.paused -> s(R.string.status_paused)
                scanning -> s(R.string.status_scanning)
                else -> s(R.string.status_cleanable)
            })
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            RingGauge(shown, "${(shown * 100).roundToInt()}", if (scanning) s(R.string.ring_scan) else s(R.string.ring_cleanable), Modifier.size(140.dp))
            Spacer(Modifier.width(18.dp))
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row { Metric(Icons.Rounded.Photo, s(R.string.m_photos), "${vm.items.size - videos}", Modifier.weight(1f)); Metric(Icons.Rounded.Videocam, s(R.string.m_videos), "$videos", Modifier.weight(1f)) }
                Row { Metric(Icons.Rounded.SdStorage, s(R.string.m_used), Fmt.bytes(vm.totalBytes), Modifier.weight(1f)); Metric(Icons.Rounded.AutoAwesome, s(R.string.m_cleanable), Fmt.bytes(cleanableBytes), Modifier.weight(1f)) }
            }
        }
        // 分析中：进度 + 暂停 / 继续（已分析的存在本机，下次接着来）
        if (vm.phase == Phase.ANALYZING || vm.paused) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(vm.progressText, color = T.text2, fontSize = T.caption, modifier = Modifier.weight(1f))
                SecondaryButton(
                    if (vm.paused) s(R.string.resume) else s(R.string.pause),
                    if (vm.paused) Icons.Rounded.PlayArrow else Icons.Rounded.Pause,
                ) { vm.togglePause() }
            }
        }
        // 失败 / 跳过
        val failed = vm.failedIds.size
        val fav = vm.skippedFavorites
        if (vm.phase == Phase.DONE && (failed > 0 || fav > 0)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Info, null, tint = T.text3, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    listOfNotNull(
                        if (failed > 0) s(R.string.failed_n, failed) else null,
                        if (fav > 0) s(R.string.fav_skipped_n, fav) else null,
                    ).joinToString(" · "),
                    color = T.text3, fontSize = T.caption, modifier = Modifier.weight(1f),
                )
                if (failed > 0) Text(s(R.string.retry), color = T.accent, fontSize = T.caption, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.pressable { vm.retryFailed() }.padding(4.dp))
            }
        }
    }
}

@Composable
private fun Metric(icon: ImageVector, label: String, value: String, modifier: Modifier) {
    Column(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = T.accent, modifier = Modifier.size(13.dp))
            Spacer(Modifier.width(4.dp))
            Text(label, color = T.text2, fontSize = 12.sp)
        }
        Text(value, color = T.text, fontSize = 17.sp, fontWeight = FontWeight.Bold, maxLines = 1)
    }
}

@Composable
private fun PendingCard(vm: CleanupViewModel, modifier: Modifier) {
    val cleanableBytes = maxOf(vm.bytes(vm.cleanableIds), 1L)
    val ratio = minOf(1f, vm.toDeleteBytes.toFloat() / cleanableBytes)
    Column(modifier.fillMaxWidth().card(padding = 18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        CardHeader(Icons.Rounded.Delete, s(R.string.pending_title), tint = T.danger) {
            PillBadge(if (vm.toDelete.isEmpty()) s(R.string.pending_none) else s(R.string.pending_go))
        }
        Row {
            Column(Modifier.weight(1f)) {
                Text(s(R.string.selected), color = T.text2, fontSize = 14.sp)
                BigNumber("${vm.toDelete.size}", s(R.string.unit_items))
            }
            Column(Modifier.width(130.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Column {
                    Text(s(R.string.can_free), color = T.text2, fontSize = 14.sp)
                    Text(if (vm.toDelete.isEmpty()) "--" else Fmt.bytes(vm.toDeleteBytes), color = T.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                }
                Column {
                    Text(s(R.string.kept), color = T.text2, fontSize = 14.sp)
                    Text("${vm.kept.size}", color = T.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row {
                Text(s(R.string.cleanable_total, Fmt.bytes(vm.bytes(vm.cleanableIds))), color = T.text2, fontSize = 13.sp, modifier = Modifier.weight(1f))
                Text("${(ratio * 100).roundToInt()}%", color = T.accent, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
            ThinProgress(ratio)
        }
    }
}

@Composable
private fun CategoryCard(vm: CleanupViewModel, c: CleanCategory, modifier: Modifier) {
    val ids = vm.ids(c)
    val pending = vm.undecided(ids).size
    val analyzing = vm.phase != Phase.DONE && c.needsAnalysis
    Column(modifier.card(radius = 22.dp, padding = 14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconBadge(c.icon, size = 30.dp)
            Spacer(Modifier.width(8.dp))
            Text(s(c.titleRes), color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, modifier = Modifier.weight(1f))
            if (analyzing) Spinner(14.dp)
        }
        BigNumber("${ids.size}", s(R.string.unit_items), 32.sp)
        Row {
            Text(Fmt.bytes(vm.bytes(ids)), color = T.text2, fontSize = T.caption, modifier = Modifier.weight(1f))
            if (pending > 0 && pending < ids.size) Text(s(R.string.n_to_review, pending), color = T.text2, fontSize = T.caption)
        }
    }
}

/** 小批量整理：那年今日 / 随机 10 张 / 稍后再看 */
@Composable
private fun QuickRow(vm: CleanupViewModel) {
    val a = LocalActions.current
    val onThisDay = remember(vm.items, vm.toDelete, vm.kept) { vm.undecided(vm.quickIds(QuickMode.ON_THIS_DAY)).size }
    val laterN = vm.later.count { vm.item(it) != null }
    Row(horizontalArrangement = Arrangement.spacedBy(T.gap)) {
        QuickCard(Icons.Rounded.History, s(R.string.quick_on_this_day), if (onThisDay > 0) s(R.string.n_items, onThisDay) else s(R.string.quick_none),
            Modifier.weight(1f)) { a.push(Route.Quick(QuickMode.ON_THIS_DAY)) }
        QuickCard(Icons.Rounded.Shuffle, s(R.string.quick_random), s(R.string.quick_random_sub),
            Modifier.weight(1f)) { a.push(Route.Quick(QuickMode.RANDOM)) }
        QuickCard(Icons.Rounded.Schedule, s(R.string.quick_later), if (laterN > 0) s(R.string.n_items, laterN) else s(R.string.quick_none),
            Modifier.weight(1f)) { a.push(Route.Quick(QuickMode.LATER)) }
    }
}

@Composable
private fun QuickCard(icon: ImageVector, title: String, sub: String, modifier: Modifier, onClick: () -> Unit) {
    Column(modifier.card(radius = 20.dp, padding = 12.dp).pressable(onClick = onClick).semantics(mergeDescendants = true) { },
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        IconBadge(icon, size = 28.dp)
        Text(title, color = T.text, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(sub, color = T.text2, fontSize = T.caption, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** 清理记录：累计释放 / 删除 + 最近 30 天柱状图 */
@Composable
private fun StatsCard(vm: CleanupViewModel) {
    val st = vm.stats
    val days = remember(st) { st.lastDays(vm.todayEpochDay(), 30) }
    val max = maxOf(1L, days.maxOrNull() ?: 0L)
    val month = days.sum()
    val chartDesc = s(R.string.stats_chart_desc, Fmt.bytes(month))
    Column(Modifier.fillMaxWidth().card(padding = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        CardHeader(Icons.Rounded.BarChart, s(R.string.stats_title))
        if (st.totalCount == 0) {
            Text(s(R.string.stats_empty), color = T.text2, fontSize = T.callout)
        } else {
            Row {
                Column(Modifier.weight(1f)) {
                    Text(s(R.string.stats_freed), color = T.text2, fontSize = 13.sp)
                    Text(Fmt.bytes(st.totalBytes), color = T.accent, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                }
                Column(Modifier.weight(1f)) {
                    Text(s(R.string.stats_deleted), color = T.text2, fontSize = 13.sp)
                    Text(s(R.string.n_items, st.totalCount), color = T.text, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                }
            }
            Canvas(Modifier.fillMaxWidth().height(56.dp).semantics { contentDescription = chartDesc }) {
                val n = days.size
                val gap = 3.dp.toPx()
                val w = (size.width - gap * (n - 1)) / n
                days.forEachIndexed { i, v ->
                    val h = if (v == 0L) 2.dp.toPx() else maxOf(4.dp.toPx(), size.height * v / max)
                    drawRoundRect(
                        if (v == 0L) T.fill else T.accent,
                        topLeft = Offset(i * (w + gap), size.height - h), size = Size(w, h),
                        cornerRadius = CornerRadius(w / 2, w / 2),
                    )
                }
            }
            Row {
                Text(s(R.string.stats_30d_ago), color = T.text3, fontSize = 11.sp, modifier = Modifier.weight(1f))
                Text(s(R.string.stats_30d, Fmt.bytes(month)), color = T.text3, fontSize = 11.sp)
            }
        }
    }
}
