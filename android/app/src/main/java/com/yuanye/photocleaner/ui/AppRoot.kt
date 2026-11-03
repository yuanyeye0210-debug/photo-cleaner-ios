package com.yuanye.photocleaner.ui

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.yuanye.photocleaner.Access
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.Phase
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.PhotoItem
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

sealed interface Route {
    data class Category(val c: CleanCategory) : Route
    data class Month(val key: String) : Route
    data object Review : Route
    data object Settings : Route
}

enum class AppTab(val title: String, val icon: ImageVector) {
    HOME("首页", Icons.Rounded.Home), LIBRARY("分类", Icons.Rounded.GridView), CLEAN("清理", Icons.Rounded.Delete)
}

/** 页面之间共享的操作：导航、看大图、删除 */
class AppActions(
    val push: (Route) -> Unit,
    val pop: () -> Unit,
    val preview: (PhotoItem) -> Unit,
    /** 删除（系统会弹确认框），回调 true 表示删掉了 */
    val delete: (List<String>, (Boolean) -> Unit) -> Unit,
)

val LocalActions = staticCompositionLocalOf<AppActions> { error("no actions") }
val LocalVM = staticCompositionLocalOf<CleanupViewModel> { error("no vm") }

fun requiredPermissions(): Array<String> = when {
    Build.VERSION.SDK_INT >= 34 -> arrayOf(
        Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO,
        Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
    )
    Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
    Build.VERSION.SDK_INT >= 30 -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE)
}

fun currentAccess(ctx: android.content.Context): Access {
    fun g(p: String) = ContextCompat.checkSelfPermission(ctx, p) == PackageManager.PERMISSION_GRANTED
    return when {
        Build.VERSION.SDK_INT >= 33 && g(Manifest.permission.READ_MEDIA_IMAGES) -> Access.FULL
        Build.VERSION.SDK_INT >= 34 && g(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED) -> Access.LIMITED
        Build.VERSION.SDK_INT < 33 && g(Manifest.permission.READ_EXTERNAL_STORAGE) -> Access.FULL
        else -> Access.NONE
    }
}

@Composable
fun AppRoot() {
    MaterialTheme(colorScheme = darkColorScheme(primary = T.accent, background = T.bg, surface = T.card)) {
        val vm: CleanupViewModel = viewModel()
        val ctx = LocalContext.current
        val lifecycle = LocalLifecycleOwner.current.lifecycle

        // 每次回到 App 时重新检查权限（用户可能在系统设置里改了）
        DisposableEffect(lifecycle) {
            val obs = LifecycleEventObserver { _, e ->
                if (e == Lifecycle.Event.ON_RESUME) {
                    val a = currentAccess(ctx)
                    val changed = a != vm.access
                    vm.access = a
                    if (a != Access.NONE && (vm.phase == Phase.IDLE || changed)) vm.startScan()
                }
            }
            lifecycle.addObserver(obs)
            onDispose { lifecycle.removeObserver(obs) }
        }

        Box(Modifier.fillMaxSize().background(T.bg)) {
            if (vm.access == Access.NONE) {
                PermissionScreen(vm)
            } else {
                CompositionLocalProvider(LocalVM provides vm) { MainTabs(vm) }
            }
        }
    }
}

@Composable
private fun MainTabs(vm: CleanupViewModel) {
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    var tab by rememberSaveable { mutableStateOf(AppTab.HOME) }
    val stacks = remember { AppTab.entries.associateWith { mutableStateListOf<Route>() } }
    val stack: SnapshotStateList<Route> = stacks.getValue(tab)
    var preview by remember { mutableStateOf<PhotoItem?>(null) }
    var navForward by remember { mutableStateOf(true) }

    // ---- 删除：Android 11+ 系统确认框；更老的系统先弹我们自己的确认框 ----
    var pendingDelete by remember { mutableStateOf<Pair<List<String>, (Boolean) -> Unit>?>(null) }
    var legacyConfirm by remember { mutableStateOf<Pair<List<String>, (Boolean) -> Unit>?>(null) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { res ->
        val p = pendingDelete
        pendingDelete = null
        if (p != null) {
            if (res.resultCode == Activity.RESULT_OK) {
                vm.onDeleted(p.first); Haptics.success(view); p.second(true)
            } else {
                p.second(false)
            }
        }
    }
    val actions = remember {
        AppActions(
            push = { navForward = true; stacks.getValue(tab).add(it) },
            pop = { navForward = false; stacks.getValue(tab).removeLastOrNull() },
            preview = { preview = it },
            delete = { ids, done ->
                if (ids.isEmpty()) done(false) else {
                    val sender = vm.deleteRequest(ids)
                    if (sender != null) {
                        pendingDelete = ids to done
                        launcher.launch(IntentSenderRequest.Builder(sender).build())
                    } else if (Build.VERSION.SDK_INT < 30) {
                        legacyConfirm = ids to done
                    } else {
                        done(false)
                    }
                }
            },
        )
    }

    LaunchedEffect(vm.scanFinishedTick) { if (vm.scanFinishedTick > 0) Haptics.success(view) }

    BackHandler(enabled = preview != null || stack.isNotEmpty() || tab != AppTab.HOME) {
        when {
            preview != null -> preview = null
            stack.isNotEmpty() -> { navForward = false; stack.removeLastOrNull() }
            else -> tab = AppTab.HOME
        }
    }

    CompositionLocalProvider(LocalActions provides actions) {
        Box(Modifier.fillMaxSize()) {
            AnimatedContent(
                targetState = tab,
                transitionSpec = {
                    val fwd = targetState.ordinal > initialState.ordinal
                    (fadeIn(tween(220)) + scaleIn(initialScale = if (fwd) 0.96f else 1.02f)) togetherWith fadeOut(tween(160))
                },
                label = "tabs",
            ) { t ->
                val st = stacks.getValue(t)
                AnimatedContent(
                    targetState = st.lastOrNull(),
                    transitionSpec = {
                        if (navForward) slideInHorizontally { it } + fadeIn() togetherWith slideOutHorizontally { -it / 4 } + fadeOut()
                        else slideInHorizontally { -it / 4 } + fadeIn() togetherWith slideOutHorizontally { it } + fadeOut()
                    },
                    label = "stack",
                ) { route ->
                    Box(Modifier.fillMaxSize().background(T.bg).systemBarsPadding()) {
                        if (route == null) {
                            when (t) {
                                AppTab.HOME -> DashboardScreen(vm, openSettings = { actions.push(Route.Settings) })
                                AppTab.LIBRARY -> LibraryScreen(vm)
                                AppTab.CLEAN -> ReviewScreen(vm, inTab = true)
                            }
                        } else {
                            RouteScreen(vm, route)
                        }
                    }
                }
            }

            AnimatedVisibility(
                visible = stack.isEmpty(),
                enter = slideInVertically { it } + fadeIn(),
                exit = slideOutVertically { it } + fadeOut(),
                modifier = Modifier.align(Alignment.BottomCenter),
            ) {
                TabBar(
                    tab = tab,
                    scanning = vm.scanning,
                    onSelect = { if (it != tab) { tab = it } },
                    onRescan = { Haptics.medium(view); vm.startScan() },
                )
            }

            preview?.let { p -> PhotoPreview(p, onClose = { preview = null }) }
        }
    }

    legacyConfirm?.let { (ids, done) ->
        AlertDialog(
            onDismissRequest = { legacyConfirm = null; done(false) },
            title = { Text("删除 ${ids.size} 项？") },
            text = { Text("删除后无法恢复（Android 10 及以下没有系统回收站）。") },
            confirmButton = {
                TextButton(onClick = {
                    legacyConfirm = null
                    scope.launch { val ok = vm.deleteLegacy(ids); if (ok) Haptics.success(view); done(ok) }
                }) { Text("删除", color = T.danger) }
            },
            dismissButton = { TextButton(onClick = { legacyConfirm = null; done(false) }) { Text("取消") } },
        )
    }

    vm.lastDeleteMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = { vm.lastDeleteMessage = null },
            title = { Text("完成") },
            text = { Text(msg) },
            confirmButton = { TextButton(onClick = { vm.lastDeleteMessage = null }) { Text("好的") } },
            containerColor = T.card,
        )
    }
}

@Composable
private fun RouteScreen(vm: CleanupViewModel, route: Route) {
    val a = LocalActions.current
    when (route) {
        is Route.Category ->
            if (route.c == CleanCategory.SIMILAR) SimilarScreen(vm)
            else CategoryScreen(vm, route.c.title, vm.ids(route.c))
        is Route.Month -> {
            val m = vm.months.firstOrNull { it.key == route.key }
            CategoryScreen(vm, m?.title ?: route.key, m?.ids ?: emptyList())
        }
        Route.Review -> ReviewScreen(vm, inTab = false)
        Route.Settings -> SettingsScreen(vm, onBack = a.pop)
    }
}

/**
 * 底部悬浮胶囊页签栏：按住左右滑，手指在哪高亮就到哪（换格时震一下），松手切过去；轻点也能直接切。
 */
@Composable
private fun TabBar(tab: AppTab, scanning: Boolean, onSelect: (AppTab) -> Unit, onRescan: () -> Unit) {
    val view = LocalView.current
    val density = LocalDensity.current
    var widthPx by remember { mutableIntStateOf(0) }
    var hover by remember { mutableStateOf<AppTab?>(null) }
    var dragging by remember { mutableStateOf(false) }
    val highlightX = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    val count = AppTab.entries.size
    val segW = if (widthPx > 0) widthPx.toFloat() / count else 0f

    LaunchedEffect(tab, segW) {
        if (!dragging && segW > 0) highlightX.animateTo(tab.ordinal * segW, spring(0.75f, Spring.StiffnessMediumLow))
    }

    Row(
        Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.weight(1f).height(64.dp).clip(CircleShape)
                .background(Color(0xE61C1C1E)).border(1.dp, Color.White.copy(alpha = 0.10f), CircleShape)
                .padding(5.dp)
                .onSizeChanged { widthPx = it.width }
                .pointerInput(segW) {
                    if (segW <= 0f) return@pointerInput
                    awaitEachGesture {
                        val down = awaitFirstDown()
                        fun idx(x: Float) = (x / segW).toInt().coerceIn(0, count - 1)
                        dragging = true
                        hover = AppTab.entries[idx(down.position.x)]
                        scope.launch { highlightX.snapTo((down.position.x - segW / 2).coerceIn(0f, widthPx - segW)) }
                        var lastX = down.position.x
                        while (true) {
                            val ev = awaitPointerEvent()
                            val ch = ev.changes.firstOrNull { it.id == down.id } ?: break
                            if (!ch.pressed) break
                            lastX = ch.position.x
                            ch.consume()
                            scope.launch { highlightX.snapTo((lastX - segW / 2).coerceIn(0f, widthPx - segW)) }
                            val t = AppTab.entries[idx(lastX)]
                            if (t != hover) { hover = t; Haptics.light(view) }
                        }
                        val target = AppTab.entries[idx(lastX)]
                        dragging = false
                        hover = null
                        scope.launch { highlightX.animateTo(target.ordinal * segW, spring(0.75f, Spring.StiffnessMediumLow)) }
                        if (target != tab) Haptics.light(view)
                        onSelect(target)
                    }
                },
        ) {
            if (segW > 0) {
                val wDp = with(density) { segW.toDp() }
                Box(
                    Modifier.offset { IntOffset(highlightX.value.roundToInt(), 0) }
                        .width(wDp).fillMaxHeight()
                        .graphicsLayer { val s = if (dragging) 1.06f else 1f; scaleX = s; scaleY = s }
                        .clip(CircleShape).background(Color.White.copy(alpha = if (dragging) 0.18f else 0.12f)),
                )
            }
            Row(Modifier.fillMaxSize()) {
                val shown = hover ?: tab
                AppTab.entries.forEach { t ->
                    val on = t == shown
                    Column(
                        Modifier.weight(1f).fillMaxHeight()
                            .graphicsLayer { val s = if (dragging && on) 1.1f else 1f; scaleX = s; scaleY = s },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Icon(t.icon, t.title, tint = if (on) T.accent else T.text, modifier = Modifier.size(22.dp))
                        Text(t.title, color = if (on) T.accent else T.text, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
        AnimatedVisibility(visible = tab != AppTab.CLEAN, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
            Row {
                Spacer(Modifier.width(12.dp))
                Box(
                    Modifier.size(64.dp).clip(CircleShape).background(Color(0xE61C1C1E))
                        .border(1.dp, Color.White.copy(alpha = 0.10f), CircleShape)
                        .pressable(enabled = !scanning, onClick = onRescan),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(if (scanning) Icons.Rounded.HourglassTop else Icons.Rounded.Refresh, "重新扫描", tint = T.text, modifier = Modifier.size(24.dp))
                }
            }
        }
    }
}
