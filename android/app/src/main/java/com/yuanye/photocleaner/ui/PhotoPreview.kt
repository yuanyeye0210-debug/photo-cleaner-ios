package com.yuanye.photocleaner.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import coil.imageLoader
import coil.memory.MemoryCache
import coil.request.ImageRequest
import com.yuanye.photocleaner.core.Fmt
import com.yuanye.photocleaner.core.PhotoItem

/** 长按看大图：先用已缓存的卡片图/缩略图秒开，再换成大图；双指缩放，点一下关闭 */
@Composable
fun PhotoPreview(item: PhotoItem, onClose: () -> Unit) {
    val ctx = LocalContext.current
    val req = remember(item.id) {
        val cache = ctx.imageLoader.memoryCache
        val ph = if (cache?.get(MemoryCache.Key("card:${item.id}")) != null) "card:${item.id}" else "thumb:${item.id}"
        ImageRequest.Builder(ctx).data(item.uri).size(2048, 2048).memoryCacheKey("full:${item.id}")
            .placeholderMemoryCacheKey(ph).crossfade(false).build()
    }
    var scale by remember { mutableFloatStateOf(1f) }
    var pan by remember { mutableStateOf(androidx.compose.ui.geometry.Offset.Zero) }
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Box(Modifier.fillMaxSize().background(Color.Black)
            .pointerInput(Unit) { detectTapGestures(onTap = { onClose() }, onDoubleTap = { scale = if (scale > 1f) 1f else 2.5f; pan = androidx.compose.ui.geometry.Offset.Zero }) }
            .pointerInput(Unit) { detectTransformGestures { _, p, z, _ -> scale = (scale * z).coerceIn(1f, 6f); pan = if (scale == 1f) androidx.compose.ui.geometry.Offset.Zero else pan + p } }
        ) {
            AsyncImage(req, null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize()
                .graphicsLayer { scaleX = scale; scaleY = scale; translationX = pan.x; translationY = pan.y })
            Row(Modifier.align(Alignment.TopStart).fillMaxWidth().systemBarsPadding().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${Fmt.bytes(item.fileSize)} · ${item.width}×${item.height}", color = Color.White.copy(alpha = 0.8f), fontSize = 13.sp, modifier = Modifier.weight(1f))
                Box(Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f)).pressable(onClick = onClose), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Close, "关闭", tint = Color.White, modifier = Modifier.size(20.dp))
                }
            }
        }
    }
}
