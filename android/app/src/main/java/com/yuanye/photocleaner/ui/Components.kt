package com.yuanye.photocleaner.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBackIosNew
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.yuanye.photocleaner.core.PhotoItem

fun Modifier.card(radius: Dp = T.rCard, padding: Dp = 0.dp): Modifier =
    this.clip(RoundedCornerShape(radius))
        .background(T.card)
        .border(1.dp, T.hairline, RoundedCornerShape(radius))
        .padding(padding)

/** 按下时轻微缩小 */
@Composable
fun Modifier.pressable(enabled: Boolean = true, onClick: () -> Unit): Modifier {
    val src = remember { MutableInteractionSource() }
    val pressed by src.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) 0.97f else 1f, T.spring(), label = "press")
    return this.scale(s).clickable(interactionSource = src, indication = null, enabled = enabled, onClick = onClick)
}

@Composable
fun IconBadge(icon: ImageVector, tint: Color = T.accent, size: Dp = 30.dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(tint.copy(alpha = 0.16f))
            .border(1.dp, tint.copy(alpha = 0.28f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(size * 0.5f))
    }
}

@Composable
fun PillBadge(text: String, tint: Color = T.accent, modifier: Modifier = Modifier) {
    Text(
        text, color = tint, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
        modifier = modifier.clip(CircleShape).background(tint.copy(alpha = 0.16f)).padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
fun CardHeader(icon: ImageVector, title: String, tint: Color = T.accent, trailing: @Composable () -> Unit = {}) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconBadge(icon, tint, 30.dp)
        Spacer(Modifier.width(8.dp))
        Text(title, color = T.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.weight(1f))
        trailing()
    }
}

@Composable
fun BigNumber(value: String, unit: String? = null, size: TextUnit = 40.sp, color: Color = T.text) {
    Row(verticalAlignment = Alignment.Bottom) {
        Text(value, color = color, fontSize = size, fontWeight = FontWeight.Bold, lineHeight = size)
        if (unit != null) {
            Spacer(Modifier.width(4.dp))
            Text(unit, color = T.text2, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(bottom = 4.dp))
        }
    }
}

@Composable
fun ThinProgress(value: Float, tint: Color = T.accent, modifier: Modifier = Modifier) {
    val v by animateFloatAsState(value.coerceIn(0f, 1f), T.spring(), label = "thin")
    Box(modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(T.fill)) {
        Box(Modifier.fillMaxWidth(v).fillMaxHeight().clip(CircleShape).background(tint))
    }
}

/** 圆环进度：中间大数字 */
@Composable
fun RingGauge(value: Float, center: String, caption: String, modifier: Modifier = Modifier, tint: Color = T.accent) {
    val v by animateFloatAsState(value.coerceIn(0f, 1f), T.spring(), label = "ring")
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = size.minDimension * 0.1f
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(T.fill, 135f, 270f, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            if (v > 0f) drawArc(tint, 135f, 270f * v, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(center, color = T.text, fontSize = 38.sp, fontWeight = FontWeight.Bold, lineHeight = 40.sp)
            Text(caption, color = T.text2, fontSize = 12.sp)
        }
    }
}

@Composable
fun SectionHeader(title: String, trailing: String? = null) {
    Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, color = T.text, fontSize = T.title, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        if (trailing != null) Text(trailing, color = T.text2, fontSize = T.caption, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** 分段选择（胶囊滑块） */
@Composable
fun <O> Segmented(options: List<O>, selected: O, label: (O) -> String, onSelect: (O) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(CircleShape).background(T.card).padding(4.dp)) {
        options.forEach { o ->
            val on = o == selected
            Box(
                Modifier.weight(1f).clip(CircleShape).background(if (on) T.fillHigh else Color.Transparent)
                    .clickable { onSelect(o) }.padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(label(o), color = if (on) T.text else T.text2, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, tint: Color = T.accent, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(52.dp).clip(RoundedCornerShape(18.dp))
            .background(if (enabled) tint else T.fill).pressable(enabled, onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, color = if (enabled) Color.Black else T.text3, fontSize = 16.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
fun SecondaryButton(text: String, icon: ImageVector? = null, tint: Color = T.accent, onClick: () -> Unit) {
    Row(
        Modifier.clip(CircleShape).background(T.card).border(1.dp, T.hairline, CircleShape)
            .pressable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(6.dp)) }
        Text(text, color = tint, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun CircleButton(icon: ImageVector, tint: Color, size: Dp, enabled: Boolean = true, onClick: () -> Unit) {
    Box(
        Modifier.size(size).clip(CircleShape).background(T.card).border(1.dp, T.hairline, CircleShape)
            .pressable(enabled, onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, tint = if (enabled) tint else T.text3, modifier = Modifier.size(size * 0.42f))
    }
}

@Composable
fun EmptyState(icon: ImageVector, title: String, message: String, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        IconBadge(icon, T.accent, 60.dp)
        Spacer(Modifier.height(12.dp))
        Text(title, color = T.text, fontSize = T.title, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(6.dp))
        Text(message, color = T.text2, fontSize = T.callout)
    }
}

/** 顶部导航栏（返回 + 标题） */
@Composable
fun TopBar(title: String, onBack: () -> Unit, trailing: @Composable () -> Unit = {}) {
    Box(Modifier.fillMaxWidth().height(52.dp).padding(horizontal = 8.dp)) {
        Box(
            Modifier.align(Alignment.CenterStart).size(40.dp).clip(CircleShape).background(T.card).clickable(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Rounded.ArrowBackIosNew, "返回", tint = T.text, modifier = Modifier.size(18.dp)) }
        Text(title, color = T.text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.align(Alignment.Center))
        Box(Modifier.align(Alignment.CenterEnd)) { trailing() }
    }
}

fun thumbRequest(ctx: android.content.Context, item: PhotoItem, px: Int = 320): ImageRequest =
    ImageRequest.Builder(ctx).data(item.uri).size(px, px).memoryCacheKey("thumb:${item.id}").crossfade(false).build()

/** 缩略图格子：标记删除 = 红色遮罩 + 勾；保留 = 小绿勾；推荐保留 = 星标 */
@Composable
fun ThumbnailCell(item: PhotoItem, marked: Boolean, kept: Boolean, isBest: Boolean = false, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    Box(modifier.aspectRatio(1f).clip(RoundedCornerShape(12.dp)).background(T.fill)) {
        AsyncImage(
            model = remember(item.id) { thumbRequest(ctx, item) }, contentDescription = null,
            contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize(),
        )
        if (item.isVideo) {
            Icon(Icons.Rounded.PlayArrow, null, tint = Color.White, modifier = Modifier.align(Alignment.BottomStart).padding(4.dp).size(18.dp))
        }
        if (isBest) {
            Row(
                Modifier.align(Alignment.TopStart).padding(4.dp).clip(CircleShape).background(T.accent).padding(horizontal = 6.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Star, null, tint = Color.Black, modifier = Modifier.size(11.dp))
                Text("推荐", color = Color.Black, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            }
        }
        if (marked) {
            Box(Modifier.fillMaxSize().background(T.danger.copy(alpha = 0.35f)))
            Box(
                Modifier.align(Alignment.TopEnd).padding(5.dp).size(22.dp).clip(CircleShape).background(T.danger),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(15.dp)) }
        } else if (kept) {
            Icon(Icons.Rounded.CheckCircle, null, tint = T.keep, modifier = Modifier.align(Alignment.TopEnd).padding(5.dp).size(20.dp))
        }
    }
}

@Composable
fun Spinner(size: Dp = 18.dp, color: Color = T.text2) {
    CircularProgressIndicator(Modifier.size(size), color = color, strokeWidth = 2.dp)
}
