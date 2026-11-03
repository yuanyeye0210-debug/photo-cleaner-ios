package com.yuanye.photocleaner.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.compose.AsyncImagePainter
import coil.imageLoader
import coil.request.ImageRequest
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.core.Decision
import com.yuanye.photocleaner.core.Fmt
import com.yuanye.photocleaner.core.PhotoItem
import com.yuanye.photocleaner.core.swipeDecision
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

fun cardRequest(ctx: android.content.Context, item: PhotoItem): ImageRequest =
    ImageRequest.Builder(ctx).data(item.uri).size(900, 1400).memoryCacheKey("card:${item.id}")
        .placeholderMemoryCacheKey("thumb:${item.id}").crossfade(false).build()


/** 滑动筛选：左滑标记删除，右滑保留，不会立即删除；看完后统一确认 */
@Composable
fun SwipeReview(vm: CleanupViewModel, ids: List<String>, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val view = LocalView.current
    val a = LocalActions.current
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val threshold = with(density) { 110.dp.toPx() }
    val flyOut = with(density) { 700.dp.toPx() }

    // 本轮队列：进来时还没决定过的
    val queue = remember(ids) { vm.undecided(ids).ifEmpty { ids.filter { it !in vm.toDelete && it !in vm.kept } } }
    var pos by rememberSaveable(ids) { mutableIntStateOf(0) }
    val history = remember(ids) { mutableStateListOf<String>() }
    val loaded = remember(ids) { mutableStateMapOf<String, Boolean>() }
    var flying by remember { mutableStateOf(false) }
    var showNotLoaded by remember { mutableStateOf(false) }
    val offset = remember { Animatable(Offset.Zero, Offset.VectorConverter) }

    // 预加载后面 8 张
    LaunchedEffect(pos, queue) {
        queue.drop(pos).take(9).forEach { id -> vm.item(id)?.let { ctx.imageLoader.enqueue(cardRequest(ctx, it)) } }
    }

    fun swipe(d: Decision) {
        if (pos >= queue.size || flying) return
        val id = queue[pos]
        if (d == Decision.DELETE && loaded[id] != true) {
            Haptics.warning(view)
            scope.launch { offset.animateTo(Offset.Zero, spring(0.7f, Spring.StiffnessMedium)) }
            showNotLoaded = true
            scope.launch { delay(1600); showNotLoaded = false }
            return
        }
        flying = true
        if (d == Decision.DELETE) Haptics.medium(view) else Haptics.light(view)
        scope.launch {
            offset.animateTo(Offset(if (d == Decision.DELETE) -flyOut else flyOut, offset.value.y + 30f), tween(220, easing = FastOutLinearInEasing))
            vm.set(id, d)
            history.add(id)
            offset.snapTo(Offset.Zero)
            pos += 1
            flying = false
        }
    }

    fun undo() {
        if (flying) return
        val last = history.removeLastOrNull() ?: return
        Haptics.medium(view)
        vm.set(last, null)
        pos = maxOf(0, pos - 1)
        scope.launch { offset.snapTo(Offset.Zero) }
    }

    if (pos >= queue.size) {
        FinishedView(vm, queue.ifEmpty { ids }, modifier, onUndo = if (history.isNotEmpty()) ({ undo() }) else null)
        return
    }

    Column(modifier.fillMaxWidth().padding(horizontal = T.pagePadding), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.weight(1f).fillMaxWidth().padding(vertical = 6.dp)) {
            // 下一张垫在后面
            queue.getOrNull(pos + 1)?.let { nid ->
                vm.item(nid)?.let { n ->
                    val progress = (abs(offset.value.x) / threshold).coerceIn(0f, 1f)
                    PhotoCard(vm, n, Modifier.fillMaxSize().graphicsLayer {
                        val s = 0.94f + 0.06f * progress; scaleX = s; scaleY = s; alpha = 0.6f + 0.4f * progress
                    }, onLoaded = { loaded[nid] = true })
                }
            }
            val id = queue[pos]
            val item = vm.item(id)
            if (item != null) {
                key(id) {
                    val dx = offset.value.x
                    PhotoCard(
                        vm, item,
                        Modifier.fillMaxSize()
                            .offset { IntOffset(dx.roundToInt(), offset.value.y.roundToInt()) }
                            .graphicsLayer { rotationZ = dx / 40f }
                            .pointerInput(id) {
                                detectDragGestures(
                                    onDragEnd = {
                                        val v = offset.value
                                        val d = swipeDecision(v.x, v.y, threshold)
                                        if (d != null) swipe(d)
                                        else scope.launch { offset.animateTo(Offset.Zero, spring(0.7f, Spring.StiffnessMedium)) }
                                    },
                                    onDragCancel = { scope.launch { offset.animateTo(Offset.Zero, spring(0.7f)) } },
                                ) { ch, drag ->
                                    if (flying) return@detectDragGestures
                                    ch.consume()
                                    scope.launch { offset.snapTo(offset.value + drag) }
                                }
                            }
                            .pointerInput(id) {
                                detectTapGestures(
                                    onTap = {
                                        if (item.isVideo) runCatching {
                                            ctx.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse(item.uri), "video/*")
                                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                                        } else a.preview(item)
                                    },
                                    onLongPress = { Haptics.medium(view); a.preview(item) },
                                )
                            },
                        overlayHint = dx / threshold,
                        onLoaded = { loaded[id] = true },
                    )
                }
            }
            androidx.compose.animation.AnimatedVisibility(showNotLoaded, Modifier.align(Alignment.TopCenter).padding(top = 14.dp), enter = fadeIn(), exit = fadeOut()) {
                Text("图片还没加载出来，先别删", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.75f)).padding(horizontal = 14.dp, vertical = 8.dp))
            }
        }
        Text("${minOf(pos + 1, queue.size)} / ${queue.size}", color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Text("左滑标记删除 · 右滑保留 · 不会立即删除", color = T.text3, fontSize = T.caption)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(32.dp), verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 16.dp)) {
            CircleButton(Icons.Rounded.Close, T.danger, 60.dp) { swipe(Decision.DELETE) }
            Box(Modifier.alpha(if (history.isEmpty()) 0.4f else 1f)) {
                CircleButton(Icons.AutoMirrored.Rounded.Undo, T.text2, 46.dp, enabled = history.isNotEmpty()) { undo() }
            }
            CircleButton(Icons.Rounded.Check, T.keep, 60.dp) { swipe(Decision.KEEP) }
        }
    }
}

@Composable
private fun PhotoCard(vm: CleanupViewModel, item: PhotoItem, modifier: Modifier, overlayHint: Float = 0f, onLoaded: () -> Unit) {
    val ctx = LocalContext.current
    var state by remember(item.id) { mutableStateOf<AsyncImagePainter.State>(AsyncImagePainter.State.Empty) }
    Box(modifier.clip(RoundedCornerShape(28.dp)).background(T.card)) {
        AsyncImage(
            model = remember(item.id) { cardRequest(ctx, item) }, contentDescription = null,
            contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize(),
            onState = { s -> state = s; if (s is AsyncImagePainter.State.Success) onLoaded() },
        )
        if (state !is AsyncImagePainter.State.Success) {
            Box(Modifier.align(Alignment.Center)) {
                if (state is AsyncImagePainter.State.Error) Text("无法加载", color = T.text2, fontSize = 13.sp) else Spinner(28.dp)
            }
        }
        if (item.isVideo) Icon(Icons.Rounded.PlayCircle, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.align(Alignment.Center).size(64.dp))
        // 滑动方向提示
        if (overlayHint < -0.15f) {
            Box(Modifier.fillMaxSize().background(T.danger.copy(alpha = (-overlayHint).coerceAtMost(1f) * 0.3f)))
            Stamp("删除", T.danger, Modifier.align(Alignment.TopEnd).padding(20.dp))
        } else if (overlayHint > 0.15f) {
            Box(Modifier.fillMaxSize().background(T.keep.copy(alpha = overlayHint.coerceAtMost(1f) * 0.25f)))
            Stamp("保留", T.keep, Modifier.align(Alignment.TopStart).padding(20.dp))
        }
        // 底部信息
        Column(
            Modifier.align(Alignment.BottomStart).fillMaxWidth()
                .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f))))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            val tags = vm.cardTags(item)
            if (tags.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { tags.forEach { CardTag(it) } }
            val date = item.dateMillis?.let { SimpleDateFormat("yyyy年M月d日 HH:mm", Locale.CHINA).format(Date(it)) } ?: ""
            Text(date, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
            Text("${Fmt.bytes(item.fileSize)} · ${item.width}×${item.height}", color = Color.White.copy(alpha = 0.75f), fontSize = 12.sp)
        }
    }
}

@Composable
private fun Stamp(text: String, color: Color, modifier: Modifier) {
    Text(text, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold,
        modifier = modifier.clip(RoundedCornerShape(10.dp)).background(color).padding(horizontal = 14.dp, vertical = 6.dp))
}

@Composable
fun CardTag(text: String) {
    Text(text, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Medium,
        modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).padding(horizontal = 8.dp, vertical = 3.dp))
}

/** 一类看完：列出本轮标记的照片，点缩略图取消标记，确认后才真正删除（系统再确认一次） */
@Composable
private fun FinishedView(vm: CleanupViewModel, queue: List<String>, modifier: Modifier, onUndo: (() -> Unit)?) {
    val a = LocalActions.current
    val view = LocalView.current
    val marked = queue.filter { it in vm.toDelete }
    var working by remember { mutableStateOf(false) }
    var deletedCount by remember { mutableIntStateOf(-1) }
    Column(modifier.fillMaxWidth()) {
        LazyVerticalGrid(
            GridCells.Adaptive(84.dp), Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = T.pagePadding, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                Column(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    IconBadge(Icons.Rounded.Check, T.keep, 56.dp)
                    Text(if (deletedCount >= 0) "已删除 $deletedCount 项" else "这一类看完了", color = T.text, fontSize = T.title, fontWeight = FontWeight.Bold)
                    if (deletedCount < 0) {
                        if (marked.isEmpty()) Text("没有标记要删除的照片", color = T.text2, fontSize = T.callout)
                        else {
                            Text("标记了 ${marked.size} 项，可释放 ${Fmt.bytes(vm.bytes(marked))}", color = T.text2, fontSize = T.callout)
                            Text("照片还没删除 · 点缩略图可取消标记", color = T.text3, fontSize = T.caption)
                        }
                        if (onUndo != null) Text("撤销上一张", color = T.accent, fontSize = T.callout, fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.pressable(onClick = onUndo).padding(6.dp))
                    }
                }
            }
            items(marked, key = { it }) { id ->
                val item = vm.item(id) ?: return@items
                ThumbnailCell(item, marked = false, kept = false,
                    modifier = Modifier.pressable { Haptics.light(view); vm.set(id, Decision.KEEP) })
            }
        }
        if (marked.isNotEmpty()) {
            PrimaryButton(
                if (working) "等待系统确认…" else "确认删除 ${marked.size} 项",
                Modifier.padding(horizontal = T.pagePadding, vertical = 10.dp), tint = T.danger, enabled = !working,
            ) {
                Haptics.warning(view)
                working = true
                val n = marked.size
                a.delete(marked) { ok -> working = false; if (ok) deletedCount = n }
            }
        }
    }
}
