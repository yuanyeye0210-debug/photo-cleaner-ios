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
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Fmt
import kotlin.math.roundToInt

/** 首页：问候 + 相册状态（圆环 + 2×2 指标）+ 待删除 + 分类 */
@Composable
fun DashboardScreen(vm: CleanupViewModel, openSettings: () -> Unit) {
    val a = LocalActions.current
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = T.pagePadding),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("${T.greeting()}，${vm.userName.ifBlank { "你好" }}", color = T.text, fontSize = 24.sp,
                fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Box(
                Modifier.size(46.dp).clip(CircleShape).background(T.accent.copy(alpha = 0.2f)).pressable(onClick = openSettings),
                contentAlignment = Alignment.Center,
            ) {
                Text(vm.userName.take(1).ifEmpty { "我" }, color = T.accent, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            }
        }

        StatusCard(vm)

        if (vm.access == Access.LIMITED) {
            Row(Modifier.fillMaxWidth().card(padding = 14.dp)) {
                Icon(Icons.Rounded.Info, null, tint = T.accent, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(10.dp))
                Text("你只允许访问部分照片，只能清理这些照片。可到「设置 › 应用 › 相册清理 › 权限 › 照片和视频」改为「始终允许所有」。",
                    color = T.text2, fontSize = T.caption)
            }
        }

        PendingCard(vm, Modifier.pressable { a.push(Route.Review) })

        SectionHeader("分类", if (vm.phase == Phase.DONE) "分析完成" else vm.progressText)
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
        CardHeader(Icons.Rounded.Speed, "相册状态") {
            PillBadge(if (scanning) "扫描中" else "可清理")
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            RingGauge(shown, "${(shown * 100).roundToInt()}", if (scanning) "扫描 %" else "可清理 %", Modifier.size(140.dp))
            Spacer(Modifier.width(18.dp))
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row { Metric(Icons.Rounded.Photo, "照片", "${vm.items.size - videos}", Modifier.weight(1f)); Metric(Icons.Rounded.Videocam, "视频", "$videos", Modifier.weight(1f)) }
                Row { Metric(Icons.Rounded.SdStorage, "占用", Fmt.bytes(vm.totalBytes), Modifier.weight(1f)); Metric(Icons.Rounded.AutoAwesome, "可清理", Fmt.bytes(cleanableBytes), Modifier.weight(1f)) }
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
        CardHeader(Icons.Rounded.Delete, "待删除", tint = T.danger) {
            PillBadge(if (vm.toDelete.isEmpty()) "未选择" else "去确认 ›")
        }
        Row {
            Column(Modifier.weight(1f)) {
                Text("已选", color = T.text2, fontSize = 14.sp)
                BigNumber("${vm.toDelete.size}", "项")
            }
            Column(Modifier.width(130.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Column {
                    Text("可释放", color = T.text2, fontSize = 14.sp)
                    Text(if (vm.toDelete.isEmpty()) "--" else Fmt.bytes(vm.toDeleteBytes), color = T.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                }
                Column {
                    Text("已保留", color = T.text2, fontSize = 14.sp)
                    Text("${vm.kept.size}", color = T.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row {
                Text("可清理共 ${Fmt.bytes(vm.bytes(vm.cleanableIds))}", color = T.text2, fontSize = 13.sp, modifier = Modifier.weight(1f))
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
            Text(c.title, color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, modifier = Modifier.weight(1f))
            if (analyzing) Spinner(14.dp)
        }
        BigNumber("${ids.size}", "项", 32.sp)
        Row {
            Text(Fmt.bytes(vm.bytes(ids)), color = T.text2, fontSize = T.caption, modifier = Modifier.weight(1f))
            if (pending > 0 && pending < ids.size) Text("$pending 待看", color = T.text2, fontSize = T.caption)
        }
    }
}
