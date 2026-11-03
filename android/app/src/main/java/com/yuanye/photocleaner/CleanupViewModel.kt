package com.yuanye.photocleaner

import android.app.Application
import android.content.Context
import android.content.IntentSender
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.yuanye.photocleaner.core.AnalysisResult
import com.yuanye.photocleaner.core.BestCandidate
import com.yuanye.photocleaner.core.BurstGrouper
import com.yuanye.photocleaner.core.CardTag
import com.yuanye.photocleaner.core.CategoryRules
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.CleanStats
import com.yuanye.photocleaner.core.Decision
import com.yuanye.photocleaner.core.DeleteCheck
import com.yuanye.photocleaner.core.ExactDuplicates
import com.yuanye.photocleaner.core.Fmt
import com.yuanye.photocleaner.core.GroupingParams
import com.yuanye.photocleaner.core.HashEntry
import com.yuanye.photocleaner.core.PairKey
import com.yuanye.photocleaner.core.PhotoItem
import com.yuanye.photocleaner.core.QuickBatches
import com.yuanye.photocleaner.core.SimilarityGrouper
import com.yuanye.photocleaner.data.AnalysisCache
import com.yuanye.photocleaner.data.Analyzer
import com.yuanye.photocleaner.data.HashCache
import com.yuanye.photocleaner.data.MarksStore
import com.yuanye.photocleaner.data.MediaRepository
import com.yuanye.photocleaner.data.MotionConverter
import com.yuanye.photocleaner.data.StatsStore
import com.yuanye.photocleaner.data.ToolOutcome
import com.yuanye.photocleaner.data.VideoCompressor
import com.yuanye.photocleaner.data.WidgetData
import com.yuanye.photocleaner.widget.PhotoWidget
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Calendar
import java.util.concurrent.atomic.AtomicInteger

enum class Phase { IDLE, LOADING, ANALYZING, DONE }
enum class Access { NONE, LIMITED, FULL }

data class MonthGroup(val key: String, val year: Int, val month: Int, val ids: List<String>)

/** 小批量整理（与 iOS 版 QuickMode 一致） */
enum class QuickMode { ON_THIS_DAY, RANDOM, LATER }

/** 视频压缩 / 动态照片转换的进度 */
data class ToolState(val running: Boolean, val done: Int, val total: Int, val current: Float, val message: String? = null)

/** 全局状态：扫描、分类、标记、删除（对应 iOS 版 CleanupStore） */
class CleanupViewModel(app: Application) : AndroidViewModel(app) {
    private val ctx: Context get() = getApplication()
    private val prefs = app.getSharedPreferences("photocleaner", Context.MODE_PRIVATE)
    val repo = MediaRepository(app)
    private val analyzer by lazy { Analyzer(app, repo) }
    private val cache = AnalysisCache(app)
    private val hashCache = HashCache(app)
    private val marksStore = MarksStore(app)
    private val statsStore = StatsStore(app)
    val compressor by lazy { VideoCompressor(app, repo) }
    val motionConverter = MotionConverter(repo)

    var access by mutableStateOf(Access.NONE)
    var phase by mutableStateOf(Phase.IDLE); private set
    var progress by mutableFloatStateOf(0f); private set
    var progressText by mutableStateOf(""); private set
    /** 暂停分析（下次「继续」从断点接着分析，已分析的都存在缓存里） */
    var paused by mutableStateOf(false); private set
    var analyzedCount by mutableIntStateOf(0); private set
    var analyzeTotal by mutableIntStateOf(0); private set

    var items by mutableStateOf<List<PhotoItem>>(emptyList()); private set
    var categoryIds by mutableStateOf<Map<CleanCategory, List<String>>>(emptyMap()); private set
    var similarGroups by mutableStateOf<List<List<String>>>(emptyList()); private set
    var duplicateGroups by mutableStateOf<List<List<String>>>(emptyList()); private set
    var burstGroups by mutableStateOf<List<List<String>>>(emptyList()); private set
    var months by mutableStateOf<List<MonthGroup>>(emptyList()); private set
    var totalBytes by mutableStateOf(0L); private set
    var cleanableIds by mutableStateOf<Set<String>>(emptySet()); private set
    /** 读不出来 / 分析失败、被跳过的照片 */
    var failedIds by mutableStateOf<Set<String>>(emptySet()); private set

    private val initialMarks = marksStore.load()
    var toDelete by mutableStateOf(initialMarks.toDelete); private set
    var kept by mutableStateOf(initialMarks.kept); private set
    var later by mutableStateOf(initialMarks.later); private set
    var cleanedMonths by mutableStateOf(initialMarks.cleanedMonths); private set
    var notSimilar by mutableStateOf(initialMarks.notSimilar); private set
    var stats by mutableStateOf(statsStore.load()); private set

    var blurThreshold by mutableDoubleStateOf(runCatching { prefs.getFloat(K_BLUR, 60f) }.getOrDefault(60f).toDouble()); private set
    var largeFileMB by mutableDoubleStateOf(runCatching { prefs.getFloat(K_LARGE, 8f) }.getOrDefault(8f).toDouble()); private set
    var userName by mutableStateOf(runCatching { prefs.getString(K_NAME, null) }.getOrNull() ?: ctx.getString(R.string.default_name)); private set
    var useTrash by mutableStateOf(runCatching { prefs.getBoolean(K_TRASH, true) }.getOrDefault(true)); private set
    var lastDeleteMessage by mutableStateOf<String?>(null)
    var tool by mutableStateOf<ToolState?>(null)
    /** 桌面小组件点进来：直接打开滑动整理 */
    var openSwipeRequest by mutableIntStateOf(0)
    /** 每次扫描完成 +1（界面据此震动一下） */
    var scanFinishedTick by mutableIntStateOf(0); private set

    private var index: Map<String, Int> = emptyMap()
    private var scanJob: Job? = null
    private var observer: ContentObserver? = null
    private var observerJob: Job? = null
    private var rescanPending = false
    private var saveMarksJob: Job? = null
    private var cachedAnalysis: Map<String, AnalysisCache.Entry>? = null

    val scanning: Boolean get() = phase == Phase.LOADING || phase == Phase.ANALYZING
    val trashSupported: Boolean get() = Build.VERSION.SDK_INT >= 30

    // ---------------- 设置 ----------------
    fun updateBlur(v: Double) { blurThreshold = v; prefs.edit().putFloat(K_BLUR, v.toFloat()).apply(); rebuildCategories() }
    fun updateLarge(v: Double) { largeFileMB = v; prefs.edit().putFloat(K_LARGE, v.toFloat()).apply(); rebuildCategories() }
    fun updateName(v: String) { userName = v; prefs.edit().putString(K_NAME, v).apply() }
    fun updateTrash(v: Boolean) { useTrash = v; prefs.edit().putBoolean(K_TRASH, v).apply() }

    // ---------------- 相册变化监听 ----------------

    /** 有权限后开始监听：拍了新照片、别的 App 删了照片，2 秒后自动增量刷新（只分析新的 / 改过的） */
    fun startObserving() {
        if (observer != null) return
        observer = runCatching { repo.observe { onLibraryChanged() } }.getOrNull()
    }

    private fun onLibraryChanged() {
        observerJob?.cancel()
        observerJob = viewModelScope.launch {
            delay(2000)
            if (scanning || tool?.running == true) rescanPending = true else startScan()
        }
    }

    override fun onCleared() {
        observer?.let { runCatching { repo.unobserve(it) } }
        super.onCleared()
    }

    // ---------------- 扫描 ----------------
    fun startScan() {
        scanJob?.cancel()
        rescanPending = false
        scanJob = viewModelScope.launch { scan() }
    }

    fun togglePause() {
        paused = !paused
        if (paused) progressText = ctx.getString(R.string.progress_paused, analyzedCount, analyzeTotal)
    }

    private suspend fun scan() {
        phase = Phase.LOADING
        progress = 0f
        progressText = ctx.getString(R.string.progress_reading)
        val metas = withContext(Dispatchers.IO) { repo.queryAll() }
        val cached = cachedAnalysis ?: withContext(Dispatchers.IO) { cache.load() }.also { cachedAnalysis = it }
        val current = items.associateBy { it.id }
        val merged = metas.map { m ->
            if (m.isVideo) return@map m
            val old = current[m.id]
            if (old?.analysis != null && old.dateModified == m.dateModified) return@map m.copy(analysis = old.analysis)
            val e = cached[m.id]
            if (e != null && e.dateModified == m.dateModified) m.copy(analysis = e.result) else m
        }
        replaceItems(merged)
        pruneDecisions()
        failedIds = failedIds.filter { index.containsKey(it) }.toSet()
        rebuildCategories()
        progress = 0.03f

        // 逐张 AI 分析：全部照片（不设上限），视频、收藏不分析；已分析的直接用缓存
        phase = Phase.ANALYZING
        val targets = items.filter { !it.isVideo && !it.isFavorite }
        val todo = targets.filter { it.analysis == null && it.id !in failedIds }
        analyzeTotal = targets.size
        val doneCount = AtomicInteger(targets.size - todo.size)
        analyzedCount = doneCount.get()
        progressText = ctx.getString(R.string.progress_analyzing, analyzedCount, analyzeTotal)
        if (todo.isNotEmpty()) {
            coroutineScope {
                val queue = Channel<PhotoItem>(Channel.UNLIMITED)
                todo.forEach { queue.trySend(it) }
                queue.close()
                val results = Channel<Pair<String, AnalysisResult?>>(Channel.UNLIMITED)
                repeat(WORKERS) {
                    launch(Dispatchers.Default) {
                        for (it in queue) {
                            while (paused && isActive) delay(300)
                            if (!isActive) break
                            val r = runCatching { analyzer.analyze(it) }.getOrNull()
                            results.send(it.id to r)
                        }
                    }
                }
                // 界面按批更新：每 48 张或每秒一次，避免频繁重组
                val pending = ArrayList<Pair<String, AnalysisResult?>>()
                var lastFlush = System.currentTimeMillis()
                var sinceRebuild = 0
                repeat(todo.size) { n ->
                    pending += results.receive()
                    analyzedCount = doneCount.incrementAndGet()
                    val now = System.currentTimeMillis()
                    val last = n == todo.size - 1
                    if (pending.size >= 48 || now - lastFlush > 1000 || last) {
                        sinceRebuild += pending.size
                        applyResults(pending)
                        pending.clear()
                        lastFlush = now
                        progress = 0.03f + 0.82f * analyzedCount / maxOf(1, analyzeTotal)
                        progressText = if (paused) ctx.getString(R.string.progress_paused, analyzedCount, analyzeTotal)
                        else ctx.getString(R.string.progress_analyzing, analyzedCount, analyzeTotal)
                    }
                    if (sinceRebuild >= 600 && !last) {
                        sinceRebuild = 0
                        rebuildCategories()
                        saveCache()
                    }
                }
            }
        }
        saveCache()

        // 完全重复：同大小的文件算内容哈希
        progress = 0.86f
        progressText = ctx.getString(R.string.progress_duplicates)
        duplicateGroups = withContext(Dispatchers.IO) { findDuplicates(items) }

        // 连拍：文件名 + 时间
        burstGroups = withContext(Dispatchers.Default) { BurstGrouper.groups(items.filter { !it.isFavorite }) }

        // 相似分组（AI 特征 + dHash + 拍摄时间），截图和收藏不参与；完全重复的每组只拿一张参与
        progress = 0.9f
        progressText = ctx.getString(R.string.progress_similar)
        val dupExtra = duplicateGroups.flatMap { it.drop(1) }.toSet()
        val entries = items.mapNotNull { item ->
            val a = item.analysis ?: return@mapNotNull null
            if (item.isScreenshot || item.isFavorite || item.id in dupExtra) return@mapNotNull null
            HashEntry(item.id, a.dHash, item.dateMillis?.let { it / 1000.0 }, a.feature,
                aspect = HashEntry.aspect(item.width, item.height), labels = a.labels, faces = a.faceCount)
        }
        val excluded = notSimilar
        val groups = withContext(Dispatchers.Default) {
            SimilarityGrouper.groups(entries, GroupingParams(featureNear = FEATURE_NEAR, featureDup = FEATURE_DUP), excluded)
        }
        similarGroups = groups
        rebuildCategories()

        // 相似组 / 连拍里的照片算人脸质量，用来挑「推荐保留」
        val faceTargets = (groups.flatten() + burstGroups.flatten()).distinct().mapNotNull { item(it) }
            .filter { it.analysis?.faceChecked == false }
        if (faceTargets.isNotEmpty()) {
            progress = 0.93f
            progressText = ctx.getString(R.string.progress_best)
            var fDone = 0
            coroutineScope {
                val queue = Channel<PhotoItem>(Channel.UNLIMITED)
                faceTargets.forEach { queue.trySend(it) }
                queue.close()
                val results = Channel<Pair<String, Float?>>(Channel.UNLIMITED)
                repeat(WORKERS) {
                    launch(Dispatchers.Default) {
                        for (it in queue) {
                            while (paused && isActive) delay(300)
                            results.send(it.id to runCatching { analyzer.faceQuality(it) }.getOrNull())
                        }
                    }
                }
                val batch = ArrayList<Pair<String, Float?>>()
                repeat(faceTargets.size) { n ->
                    batch += results.receive()
                    fDone++
                    if (batch.size >= 32 || n == faceTargets.size - 1) {
                        val copy = items.toMutableList()
                        for ((id, q) in batch) {
                            val i = index[id] ?: continue
                            copy[i] = copy[i].copy(analysis = copy[i].analysis?.copy(faceQuality = q, faceChecked = true))
                        }
                        items = copy
                        batch.clear()
                        progress = 0.93f + 0.07f * fDone / faceTargets.size
                    }
                }
            }
            saveCache()
        }
        rebuildCategories()
        progress = 1f
        progressText = ctx.getString(R.string.progress_done)
        phase = Phase.DONE
        scanFinishedTick++
        updateWidget()
        if (rescanPending) { rescanPending = false; onLibraryChanged() }
    }

    private fun findDuplicates(all: List<PhotoItem>): List<List<String>> {
        val hc = hashCache.load()
        var changed = false
        val groups = ExactDuplicates.groups(all) { it ->
            val e = hc[it.id]
            if (e != null && e.mod == it.dateModified && e.size == it.fileSize) return@groups e.hash
            val h = repo.contentHash(Uri.parse(it.uri)) ?: return@groups null
            hc[it.id] = HashCache.Entry(it.dateModified, it.fileSize, h)
            changed = true
            h
        }
        val live = all.mapTo(HashSet()) { it.id }
        if (hc.keys.retainAll(live)) changed = true
        if (changed) hashCache.save(hc)
        return groups
    }

    private fun applyResults(results: List<Pair<String, AnalysisResult?>>) {
        if (results.isEmpty()) return
        val copy = items.toMutableList()
        val failed = HashSet<String>()
        for ((id, r) in results) {
            val i = index[id] ?: continue
            if (r != null) copy[i] = copy[i].copy(analysis = r) else failed += id
        }
        items = copy
        if (failed.isNotEmpty()) failedIds = failedIds + failed
    }

    private suspend fun saveCache() {
        val snapshot = items
        withContext(Dispatchers.IO) {
            val map = snapshot.filter { it.analysis != null }
                .associate { it.id to AnalysisCache.Entry(it.dateModified, it.analysis!!) }
            cache.save(map)
            cachedAnalysis = map
        }
    }

    fun clearAnalysisCache() {
        cache.clear()
        hashCache.clear()
        cachedAnalysis = emptyMap()
        failedIds = emptySet()
        replaceItems(items.map { it.copy(analysis = null) })
        startScan()
    }

    /** 重新试一遍分析失败的照片 */
    fun retryFailed() {
        failedIds = emptySet()
        startScan()
    }

    private fun replaceItems(new: List<PhotoItem>) {
        items = new
        index = new.withIndex().associate { it.value.id to it.index }
        totalBytes = new.sumOf { it.fileSize }
    }

    private fun pruneDecisions() {
        toDelete = toDelete.filter { index.containsKey(it) }.toSet()
        kept = kept.filter { index.containsKey(it) }.toSet()
        later = later.filter { index.containsKey(it) }.toSet()
        notSimilar = notSimilar.filter { k -> PairKey.ids(k)?.let { index.containsKey(it.first) && index.containsKey(it.second) } == true }.toSet()
        persist()
    }

    fun rebuildCategories() {
        categoryIds = CategoryRules.build(items, similarGroups, blurThreshold, largeFileMB, duplicateGroups, burstGroups)
        cleanableIds = CleanCategory.entries.filter { it != CleanCategory.VIDEOS && it != CleanCategory.LARGE && !it.isBrowse }
            .flatMap { categoryIds[it] ?: emptyList() }.toSet()
        val cal = Calendar.getInstance()
        val buckets = LinkedHashMap<String, MutableList<String>>()
        val ym = HashMap<String, Pair<Int, Int>>()
        for (it in items) {
            val d = it.dateMillis ?: continue
            cal.timeInMillis = d
            val y = cal.get(Calendar.YEAR)
            val m = cal.get(Calendar.MONTH) + 1
            val key = String.format(java.util.Locale.US, "%04d-%02d", y, m)
            buckets.getOrPut(key) { mutableListOf() }.add(it.id)
            ym[key] = y to m
        }
        months = buckets.keys.sortedDescending().map { MonthGroup(it, ym[it]!!.first, ym[it]!!.second, buckets[it]!!) }
    }

    private fun updateWidget() {
        val c = undecided(cleanableIds.toList())
        WidgetData.write(ctx, WidgetData.Snapshot(c.size, bytes(c), toDelete.size, toDeleteBytes, System.currentTimeMillis()))
        viewModelScope.launch { runCatching { PhotoWidget.refresh(ctx) } }
    }

    // ---------------- 查询 ----------------
    fun item(id: String): PhotoItem? = index[id]?.let { items.getOrNull(it) }
    fun ids(c: CleanCategory): List<String> = categoryIds[c] ?: emptyList()
    fun bytes(ids: Collection<String>): Long = ids.sumOf { item(it)?.fileSize ?: 0L }
    val toDeleteBytes: Long get() = bytes(toDelete)
    fun decision(id: String): Decision? = when (id) {
        in toDelete -> Decision.DELETE
        in kept -> Decision.KEEP
        else -> null
    }
    /** 还没决定的（「稍后再看」的也先跳过） */
    fun undecided(ids: List<String>): List<String> = ids.filter { it !in toDelete && it !in kept && it !in later }

    fun cardTags(item: PhotoItem): List<CardTag> = CategoryRules.cardTags(item, blurThreshold)

    fun groups(c: CleanCategory): List<List<String>> = when (c) {
        CleanCategory.DUPLICATES -> duplicateGroups
        CleanCategory.BURSTS -> burstGroups
        else -> similarGroups
    }

    /** 每组推荐保留的那张 */
    fun bestId(group: List<String>, c: CleanCategory = CleanCategory.SIMILAR): String? {
        val its = group.mapNotNull { item(it) }
        if (its.isEmpty()) return null
        its.firstOrNull { it.isFavorite }?.let { return it.id }
        if (c == CleanCategory.DUPLICATES) return its.first().id   // 已按「最早的」排好
        if (c == CleanCategory.BURSTS) BurstGrouper.coverIndex(its.map { it.name })?.let { return its[it].id }
        val i = SimilarityGrouper.bestIndex(its.map {
            BestCandidate(it.analysis?.faceQuality, it.analysis?.quality, it.analysis?.sharpness ?: 0.0, it.pixelCount)
        })
        return its[i].id
    }

    /** 那年今日 / 随机 10 张 / 稍后再看 */
    fun quickIds(mode: QuickMode, seed: Long = System.currentTimeMillis()): List<String> = when (mode) {
        QuickMode.ON_THIS_DAY -> QuickBatches.onThisDay(items, System.currentTimeMillis())
        QuickMode.RANDOM -> QuickBatches.random(undecided(items.filter { !it.isFavorite }.map { it.id }), 10, seed)
        QuickMode.LATER -> items.filter { it.id in later }.map { it.id }
    }

    /** 失败 / 跳过统计（首页显示） */
    val skippedFavorites: Int get() = items.count { it.isFavorite && !it.isVideo }
    val videoCount: Int get() = items.count { it.isVideo }

    // ---------------- 标记 ----------------
    fun set(id: String, d: Decision?) {
        if (d == Decision.DELETE && item(id)?.isFavorite == true) return   // 收藏的永远不标记删除
        when (d) {
            Decision.DELETE -> { toDelete = toDelete + id; kept = kept - id }
            Decision.KEEP -> { kept = kept + id; toDelete = toDelete - id }
            null -> { toDelete = toDelete - id; kept = kept - id }
        }
        later = later - id
        persist()
    }

    /** 「不是相似」：把这张从相似组里拿出来，并记住（重新扫描也不会再分进来） */
    fun markNotSimilar(id: String, group: List<String>) {
        notSimilar = notSimilar + group.filter { it != id }.map { PairKey.make(id, it) }
        val g = group.toSet()
        similarGroups = similarGroups.mapNotNull { grp ->
            if (grp.toSet() != g) grp else grp.filter { it != id }.takeIf { it.size > 1 }
        }
        rebuildCategories()
        persist()
    }

    fun toggleDelete(id: String) = set(id, if (id in toDelete) null else Decision.DELETE)

    fun markAll(ids: Collection<String>, d: Decision?) {
        val s = (if (d == Decision.DELETE) ids.filter { item(it)?.isFavorite != true } else ids).toSet()
        when (d) {
            Decision.DELETE -> { toDelete = toDelete + s; kept = kept - s }
            Decision.KEEP -> { kept = kept + s; toDelete = toDelete - s }
            null -> { toDelete = toDelete - s; kept = kept - s }
        }
        later = later - s
        persist()
    }

    /** 上滑：稍后再看（不删也不留，先从队列里拿走） */
    fun setLater(id: String, on: Boolean) {
        later = if (on) later + id else later - id
        if (on) { toDelete = toDelete - id; kept = kept - id }
        persist()
    }

    /** 分组：保留推荐的那张，其余标记删除（收藏的不标记） */
    fun keepBestDeleteRest(group: List<String>, c: CleanCategory = CleanCategory.SIMILAR) {
        val best = bestId(group, c) ?: return
        markAll(group.filter { it != best }, Decision.DELETE)
        set(best, Decision.KEEP)
    }

    /** 整组全部删除：一张都不留（收藏的除外） */
    fun deleteWholeGroup(group: List<String>) = markAll(group, Decision.DELETE)

    fun deletableCount(group: List<String>): Int = group.count { item(it)?.isFavorite != true }

    fun resetKept() { kept = emptySet(); later = emptySet(); persist() }

    fun isMonthCleaned(key: String) = key in cleanedMonths
    fun toggleMonthCleaned(key: String) {
        cleanedMonths = if (key in cleanedMonths) cleanedMonths - key else cleanedMonths + key
        persist()
    }

    /** 防抖写文件（连续滑动时不会每张都写一次） */
    private fun persist() {
        val snap = MarksStore.Marks(toDelete, kept, later, cleanedMonths, notSimilar)
        saveMarksJob?.cancel()
        saveMarksJob = viewModelScope.launch {
            delay(300)
            withContext(Dispatchers.IO) { marksStore.save(snap) }
        }
    }

    // ---------------- 删除 ----------------
    fun uris(ids: List<String>): List<Uri> = ids.mapNotNull { item(it)?.uri?.let(Uri::parse) }

    /** Android 11+ 返回系统确认框；更老的系统返回 null（界面自己弹确认框后调 deleteLegacy） */
    fun deleteRequest(ids: List<String>): IntentSender? = runCatching { repo.deleteRequest(uris(ids), useTrash && trashSupported) }.getOrNull()

    suspend fun deleteLegacy(ids: List<String>) {
        val items = ids.mapNotNull { id -> item(id)?.let { id to Uri.parse(it.uri) } }
        val ok = withContext(Dispatchers.IO) { repo.deleteLegacy(items.map { it.second }) }
        val gone = items.indices.filter { ok[it] }.map { items[it].first }
        finishDelete(ids, gone)
    }

    /** 系统确认删除后调用：逐个核对，真的删掉了才从列表里移除；没删掉的留在待删除里 */
    fun onDeleted(ids: List<String>) {
        viewModelScope.launch {
            val (gone, _) = withContext(Dispatchers.IO) {
                DeleteCheck.split(ids) { id -> item(id)?.let { repo.exists(Uri.parse(it.uri)) } ?: false }
            }
            finishDelete(ids, gone)
        }
    }

    private suspend fun finishDelete(requested: List<String>, gone: List<String>) {
        val freed = bytes(gone)
        val goneSet = gone.toSet()
        val failed = requested.size - gone.size
        if (gone.isNotEmpty()) {
            replaceItems(items.filter { it.id !in goneSet })
            similarGroups = similarGroups.map { g -> g.filter { it !in goneSet } }.filter { it.size > 1 }
            duplicateGroups = duplicateGroups.map { g -> g.filter { it !in goneSet } }.filter { it.size > 1 }
            burstGroups = burstGroups.map { g -> g.filter { it !in goneSet } }.filter { it.size > 1 }
            toDelete = toDelete - goneSet
            kept = kept - goneSet
            later = later - goneSet
            persist()
            rebuildCategories()
            stats = stats.record(epochDay(), freed, gone.size)
            val snap = stats
            withContext(Dispatchers.IO) { statsStore.save(snap) }
            updateWidget()
        }
        val where = if (useTrash && trashSupported) ctx.getString(R.string.deleted_where_trash) else ctx.getString(R.string.deleted_where_permanent)
        lastDeleteMessage = when {
            gone.isEmpty() -> ctx.getString(R.string.deleted_none, failed)
            failed > 0 -> ctx.getString(R.string.deleted_partial, gone.size, Fmt.bytes(freed), failed)
            else -> ctx.getString(R.string.deleted_ok, gone.size, Fmt.bytes(freed), where)
        }
    }

    fun onDeleteCancelled() {
        lastDeleteMessage = null
    }

    private fun epochDay(): Long {
        val cal = Calendar.getInstance()
        val offset = cal.timeZone.getOffset(cal.timeInMillis)
        return Math.floorDiv(cal.timeInMillis + offset, 86_400_000L)
    }

    fun todayEpochDay(): Long = epochDay()

    // ---------------- 视频压缩 / 动态照片转静态 ----------------

    fun compressVideos(ids: List<String>) {
        if (tool?.running == true) return
        val list = ids.mapNotNull { item(it) }.filter { it.isVideo }
        viewModelScope.launch {
            var ok = 0; var saved = 0L; var skipped = 0; var failed = 0
            val originals = ArrayList<String>()
            list.forEachIndexed { i, v ->
                tool = ToolState(true, i, list.size, 0f)
                when (val r = compressor.compress(v) { p -> tool = ToolState(true, i, list.size, p) }) {
                    is ToolOutcome.Ok -> { ok++; saved += r.before - r.after; originals += v.id }
                    ToolOutcome.NotSmaller, ToolOutcome.AlreadyHevc -> skipped++
                    is ToolOutcome.Failed -> failed++
                }
            }
            markAll(originals, Decision.DELETE)
            tool = ToolState(false, list.size, list.size, 1f, buildString {
                append(ctx.getString(R.string.compress_result, ok, Fmt.bytes(saved)))
                if (skipped > 0) append(ctx.getString(R.string.tool_skipped, skipped))
                if (failed > 0) append(ctx.getString(R.string.tool_failed, failed))
            })
            if (rescanPending) onLibraryChanged()
        }
    }

    fun convertMotion(ids: List<String>) {
        if (tool?.running == true) return
        val list = ids.mapNotNull { item(it) }
        viewModelScope.launch {
            var ok = 0; var saved = 0L; var failed = 0
            val originals = ArrayList<String>()
            list.forEachIndexed { i, p ->
                tool = ToolState(true, i, list.size, 0f)
                when (val r = withContext(Dispatchers.IO) { runCatching { motionConverter.convert(p) }.getOrElse { ToolOutcome.Failed("x") } }) {
                    is ToolOutcome.Ok -> { ok++; saved += r.before - r.after; originals += p.id }
                    else -> failed++
                }
            }
            markAll(originals, Decision.DELETE)
            tool = ToolState(false, list.size, list.size, 1f, buildString {
                append(ctx.getString(R.string.motion_result, ok, Fmt.bytes(saved)))
                if (failed > 0) append(ctx.getString(R.string.tool_failed, failed))
            })
            if (rescanPending) onLibraryChanged()
        }
    }

    fun dismissTool() { if (tool?.running != true) tool = null }

    companion object {
        private const val K_BLUR = "blurThreshold"
        private const val K_LARGE = "largeFileMB"
        private const val K_NAME = "userName"
        private const val K_TRASH = "useTrash"
        private const val WORKERS = 4
        /** MobileNetV3 特征向量（已归一化）的距离阈值：比苹果的特征稍宽一点 */
        /** 安卓 MobileNetV3 特征：同一次连拍 ≤ 0.35（原来 0.5 太松），重复图 ≤ 0.3 */
        const val FEATURE_NEAR = 0.35f
        const val FEATURE_DUP = 0.3f
    }
}
