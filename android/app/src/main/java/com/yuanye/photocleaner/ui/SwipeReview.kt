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
import com.yuanye.photocleaner.core.swipeAction
import com.yuanye.photocleaner.core.SwipeAction
import com.yuanye.photocleaner.core.CardTag
import com.yuanye.photocleaner.core.TagKind
import com.yuanye.photocleaner.R
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
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


/** 滑动筛选：左滑标记删除，右滑保留，上滑稍后再看；不会立即删除，看完后统一确认 */
@Composable
fun SwipeReview(vm: CleanupViewModel, ids: List<String>, modifier: Modifier = Modifier, finishedTitle: Int = R.string.swipe_finished) {
    val ctx = LocalContext.current
    val view = LocalView.current
    val a = LocalActions.current
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val threshold = with(density) { 110.dp.toPx() }
    val flyOut = with(density) { 700.dp.toPx() }

    // 本轮队列：进来时还没决定过的（全是「稍后再看」的时候，就看这些）
    val queue = remember(ids) { vm.undecided(ids).ifEmpty { ids.filter { it !in vm.toDelete && it !in vm.kept } } }
    var pos by rememberSaveable(ids) { mutableIntStateOf(0) }
    /** 撤销用：id + 之前是不是在「稍后再看」里 */
    val history = remember(ids) { mutableStateListOf<Pair<String, Boolean>>() }
    val loaded = remember(ids) { mutableStateMapOf<String, Boolean>() }
    var flying by remember { mutableStateOf(false) }
    var showNotLoaded by remember { mutableStateOf(false) }
    val offset = remember { Animatable(Offset.Zero, Offset.VectorConverter) }

    // 预加载后面 8 张
    LaunchedEffect(pos, queue) {
        queue.drop(pos).take(9).forEach { id -> vm.item(id)?.let { ctx.imageLoader.enqueue(cardRequest(ctx, it)) } }
    }

    fun swipe(d: SwipeAction) {
        if (pos >= queue.size || flying) return
        val id = queue[pos]
        if (d == SwipeAction.DELETE && loaded[id] != true) {
            Haptics.warning(view)
            scope.launch { offset.animateTo(Offset.Zero, spring(0.7f, Spring.StiffnessMedium)) }
            showNotLoaded = true
            scope.launch { delay(1600); showNotLoaded = false }
            return
        }
        flying = true
        if (d == SwipeAction.DELETE) Haptics.medium(view) else Haptics.light(view)
        val wasLater = id in vm.later
        scope.launch {
            val target = when (d) {
                SwipeAction.DELETE -> Offset(-flyOut, offset.value.y + 30f)
                SwipeAction.KEEP -> Offset(flyOut, offset.value.y + 30f)
                SwipeAction.LATER -> Offset(offset.value.x, -flyOut * 1.4f)
            }
            offset.animateTo(target, tween(220, easing = FastOutLinearInEasing))
            when (d) {
                SwipeAction.DELETE -> vm.set(id, Decision.DELETE)
                SwipeAction.KEEP -> vm.set(id, Decision.KEEP)
                SwipeAction.LATER -> vm.setLater(id, true)
            }
            history.add(id to wasLater)
            offset.snapTo(Offset.Zero)
            pos += 1
            flying = false
        }
    }

    fun undo() {
        if (flying) return
        val (last, wasLater) = history.removeLastOrNull() ?: return
        Haptics.medium(view)
        vm.set(last, null)
        if (wasLater) vm.setLater(last, true)
        pos = maxOf(0, pos - 1)
        scope.launch { offset.snapTo(Offset.Zero) }
    }

    if (pos >= queue.size) {
        FinishedView(vm, queue.ifEmpty { ids }, modifier, finishedTitle, onUndo = if (history.isNotEmpty()) ({ undo() }) else null)
        return
    }

    val lDelete = s(R.string.action_delete)
    val lKeep = s(R.string.action_keep)
    val lLater = s(R.string.action_later)
    val lUndo = s(R.string.action_undo)

    Column(modifier.fillMaxWidth().padding(horizontal = T.pagePadding), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.weight(1f).fillMaxWidth().padding(vertical = 6.dp)) {
            // 下一张垫在后面
            queue.getOrNull(pos + 1)?.let { nid ->
                vm.item(nid)?.let { n ->
                    val progress = (maxOf(abs(offset.value.x), -offset.value.y) / threshold).coerceIn(0f, 1f)
                    PhotoCard(vm, n, Modifier.fillMaxSize().clearAndSetSemantics { }.graphicsLayer {
                        val k = 0.94f + 0.06f * progress; scaleX = k; scaleY = k; alpha = 0.6f + 0.4f * progress
                    }, onLoaded = { loaded[nid] = true })
                }
            }
            val id = queue[pos]
            val item = vm.item(id)
            if (item != null) {
                key(id) {
                    val dx = offset.value.x
                    val dy = offset.value.y
                    PhotoCard(
                        vm, item,
                        Modifier.fillMaxSize()
                            .offset { IntOffset(dx.roundToInt(), dy.roundToInt()) }
                            .graphicsLayer { rotationZ = dx / 40f }
                            // TalkBack：不能滑的时候用「操作」菜单
                            .semantics {
                                customActions = listOf(
                                    CustomAccessibilityAction(lDelete) { swipe(SwipeAction.DELETE); true },
                                    CustomAccessibilityAction(lKeep) { swipe(SwipeAction.KEEP); true },
                                    CustomAccessibilityAction(lLater) { swipe(SwipeAction.LATER); true },
                                )
                            }
                            .pointerInput(id) {
                                detectDragGestures(
                                    onDragEnd = {
                                        val v = offset.value
                                        val d = swipeAction(v.x, v.y, threshold)
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
                        upHint = -dy / threshold,
                        onLoaded = { loaded[id] = true },
                    )
                }
            }
            androidx.compose.animation.AnimatedVisibility(showNotLoaded, Modifier.align(Alignment.TopCenter).padding(top = 14.dp), enter = fadeIn(), exit = fadeOut()) {
                Text(s(R.string.swipe_not_loaded), color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.75f)).padding(horizontal = 14.dp, vertical = 8.dp))
            }
        }
        Text("${minOf(pos + 1, queue.size)} / ${queue.size}", color = T.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Text(s(R.string.swipe_hint), color = T.text3, fontSize = T.caption)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(22.dp), verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 16.dp)) {
            CircleButton(Icons.Rounded.Close, T.danger, 60.dp, lDelete) { swipe(SwipeAction.DELETE) }
            Box(Modifier.alpha(if (history.isEmpty()) 0.4f else 1f)) {
                CircleButton(Icons.AutoMirrored.Rounded.Undo, T.text2, 46.dp, lUndo, enabled = history.isNotEmpty()) { undo() }
            }
            CircleButton(Icons.Rounded.Schedule, T.accent, 46.dp, lLater) { swipe(SwipeAction.LATER) }
            CircleButton(Icons.Rounded.Check, T.keep, 60.dp, lKeep) { swipe(SwipeAction.KEEP) }
        }
    }
}

@Composable
private fun PhotoCard(vm: CleanupViewModel, item: PhotoItem, modifier: Modifier, overlayHint: Float = 0f, upHint: Float = 0f, onLoaded: () -> Unit) {
    val ctx = LocalContext.current
    var state by remember(item.id) { mutableStateOf<AsyncImagePainter.State>(AsyncImagePainter.State.Empty) }
    val tags = vm.cardTags(item)
    val tagTexts = tags.map { tagText(it) }
    val date = item.dateMillis?.let { fmtDate(it) } ?: ""
    val desc = listOf(s(if (item.isVideo) R.string.a11y_video else R.string.a11y_photo), date, Fmt.bytes(item.fileSize))
        .plus(tagTexts).filter { it.isNotEmpty() }.joinToString("，")
    Box(modifier.clip(RoundedCornerShape(28.dp)).background(T.card).semantics { contentDescription = desc }) {
        AsyncImage(
            model = remember(item.id) { cardRequest(ctx, item) }, contentDescription = null,
            contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize(),
            onState = { s -> state = s; if (s is AsyncImagePainter.State.Success) onLoaded() },
        )
        if (state !is AsyncImagePainter.State.Success) {
            Box(Modifier.align(Alignment.Center)) {
                if (state is AsyncImagePainter.State.Error) Text(s(R.string.cannot_load), color = T.text2, fontSize = 13.sp) else Spinner(28.dp)
            }
        }
        if (item.isVideo) Icon(Icons.Rounded.PlayCircle, null, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.align(Alignment.Center).size(64.dp))
        // 滑动方向提示
        if (upHint > 0.15f && upHint > abs(overlayHint) * 1.5f) {
            Box(Modifier.fillMaxSize().background(T.accent.copy(alpha = upHint.coerceAtMost(1f) * 0.25f)))
            Stamp(s(R.string.action_later), T.accent, Modifier.align(Alignment.BottomCenter).padding(bottom = 90.dp))
        } else if (overlayHint < -0.15f) {
            Box(Modifier.fillMaxSize().background(T.danger.copy(alpha = (-overlayHint).coerceAtMost(1f) * 0.3f)))
            Stamp(s(R.string.action_delete), T.danger, Modifier.align(Alignment.TopEnd).padding(20.dp))
        } else if (overlayHint > 0.15f) {
            Box(Modifier.fillMaxSize().background(T.keep.copy(alpha = overlayHint.coerceAtMost(1f) * 0.25f)))
            Stamp(s(R.string.action_keep), T.keep, Modifier.align(Alignment.TopStart).padding(20.dp))
        }
        // 底部信息
        Column(
            Modifier.align(Alignment.BottomStart).fillMaxWidth()
                .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f))))
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (tagTexts.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { tagTexts.forEach { TagChip(it) } }
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
fun tagText(t: CardTag): String = when (t.kind) {
    TagKind.SCREENSHOT -> s(R.string.tag_screenshot)
    TagKind.VIDEO -> s(R.string.tag_video)
    TagKind.CODE -> s(R.string.tag_code, t.arg ?: "")
    TagKind.QR -> s(R.string.tag_qr)
    TagKind.DOCUMENT -> s(R.string.tag_document)
    TagKind.TEXT -> s(R.string.tag_text)
    TagKind.BLURRY -> s(R.string.tag_blurry)
    TagKind.DARK -> s(R.string.tag_dark)
    TagKind.BRIGHT -> s(R.string.tag_bright)
    TagKind.LOW_QUALITY -> s(R.string.tag_low_quality)
    TagKind.MOTION -> s(R.string.tag_motion)
}

@Composable
fun TagChip(text: String) {
    Text(text, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Medium,
        modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).padding(horizontal = 8.dp, vertical = 3.dp))
}

/** 一类看完：列出本轮标记的照片，点缩略图取消标记，确认后才真正删除（系统再确认一次） */
@Composable
private fun FinishedView(vm: CleanupViewModel, queue: List<String>, modifier: Modifier, finishedTitle: Int, onUndo: (() -> Unit)?) {
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
                    Text(if (deletedCount >= 0) s(R.string.deleted_n, deletedCount) else s(finishedTitle), color = T.text, fontSize = T.title, fontWeight = FontWeight.Bold)
                    if (deletedCount < 0) {
                        if (marked.isEmpty()) Text(s(R.string.finished_none), color = T.text2, fontSize = T.callout)
                        else {
                            Text(s(R.string.finished_marked, marked.size, Fmt.bytes(vm.bytes(marked))), color = T.text2, fontSize = T.callout)
                            Text(s(R.string.finished_hint), color = T.text3, fontSize = T.caption)
                        }
                        val laterN = queue.count { it in vm.later }
                        if (laterN > 0) Text(s(R.string.finished_later, laterN), color = T.text3, fontSize = T.caption)
                        if (onUndo != null) Text(s(R.string.undo_last), color = T.accent, fontSize = T.callout, fontWeight = FontWeight.SemiBold,
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
                if (working) s(R.string.waiting_system) else s(R.string.confirm_delete_n, marked.size),
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
