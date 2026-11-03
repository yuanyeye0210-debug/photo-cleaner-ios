package com.yuanye.photocleaner

import android.app.Application
import android.content.Context
import android.content.IntentSender
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
import com.yuanye.photocleaner.core.BestCandidate
import com.yuanye.photocleaner.core.CategoryRules
import com.yuanye.photocleaner.core.CleanCategory
import com.yuanye.photocleaner.core.Decision
import com.yuanye.photocleaner.core.Fmt
import com.yuanye.photocleaner.core.HashEntry
import com.yuanye.photocleaner.core.PhotoItem
import com.yuanye.photocleaner.core.SimilarityGrouper
import com.yuanye.photocleaner.core.AnalysisResult
import com.yuanye.photocleaner.data.AnalysisCache
import com.yuanye.photocleaner.data.Analyzer
import com.yuanye.photocleaner.data.MediaRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Calendar

enum class Phase { IDLE, LOADING, ANALYZING, DONE }
enum class Access { NONE, LIMITED, FULL }

data class MonthGroup(val key: String, val year: Int, val month: Int, val ids: List<String>) {
    val title: String get() = "${year}年${month}月"
}

/** 全局状态：扫描、分类、标记、删除（对应 iOS 版 CleanupStore） */
class CleanupViewModel(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("photocleaner", Context.MODE_PRIVATE)
    val repo = MediaRepository(app)
    private val analyzer by lazy { Analyzer(app, repo) }
    private val cache = AnalysisCache(app)

    var access by mutableStateOf(Access.NONE)
    var phase by mutableStateOf(Phase.IDLE); private set
    var progress by mutableFloatStateOf(0f); private set
    var progressText by mutableStateOf(""); private set

    var items by mutableStateOf<List<PhotoItem>>(emptyList()); private set
    var categoryIds by mutableStateOf<Map<CleanCategory, List<String>>>(emptyMap()); private set
    var similarGroups by mutableStateOf<List<List<String>>>(emptyList()); private set
    var months by mutableStateOf<List<MonthGroup>>(emptyList()); private set
    var totalBytes by mutableStateOf(0L); private set

    var toDelete by mutableStateOf(prefs.getStringSet(K_DELETE, emptySet())!!.toSet()); private set
    var kept by mutableStateOf(prefs.getStringSet(K_KEPT, emptySet())!!.toSet()); private set

    var blurThreshold by mutableDoubleStateOf(prefs.getFloat(K_BLUR, 60f).toDouble()); private set
    var largeFileMB by mutableDoubleStateOf(prefs.getFloat(K_LARGE, 8f).toDouble()); private set
    var analyzeLimit by mutableIntStateOf(prefs.getInt(K_LIMIT, 3000)); private set
    var userName by mutableStateOf(prefs.getString(K_NAME, "叶原野")!!); private set
    var useTrash by mutableStateOf(prefs.getBoolean(K_TRASH, true)); private set
    var lastDeleteMessage by mutableStateOf<String?>(null)
    /** 每次扫描完成 +1（界面据此震动一下） */
    var scanFinishedTick by mutableIntStateOf(0); private set

    private var index: Map<String, Int> = emptyMap()
    private var scanJob: Job? = null

    val scanning: Boolean get() = phase == Phase.LOADING || phase == Phase.ANALYZING
    val trashSupported: Boolean get() = Build.VERSION.SDK_INT >= 30

    // ---------------- 设置 ----------------
    fun updateBlur(v: Double) { blurThreshold = v; prefs.edit().putFloat(K_BLUR, v.toFloat()).apply(); rebuildCategories() }
    fun updateLarge(v: Double) { largeFileMB = v; prefs.edit().putFloat(K_LARGE, v.toFloat()).apply(); rebuildCategories() }
    fun updateLimit(v: Int) { analyzeLimit = v; prefs.edit().putInt(K_LIMIT, v).apply() }
    fun updateName(v: String) { userName = v; prefs.edit().putString(K_NAME, v).apply() }
    fun updateTrash(v: Boolean) { useTrash = v; prefs.edit().putBoolean(K_TRASH, v).apply() }

    // ---------------- 扫描 ----------------
    fun startScan() {
        scanJob?.cancel()
        scanJob = viewModelScope.launch { scan() }
    }

    private suspend fun scan() {
        phase = Phase.LOADING
        progress = 0f
        progressText = "正在读取相册…"
        val (metas, cached) = withContext(Dispatchers.IO) { repo.queryAll() to cache.load() }
        val withCache = metas.map { m ->
            val e = cached[m.id]
            if (e != null && e.dateModified == m.dateModified && !m.isVideo) m.copy(analysis = e.result) else m
        }
        replaceItems(withCache)
        pruneDecisions()
        rebuildCategories()
        progress = 0.05f

        // 逐张 AI 分析：视频、收藏不分析；同时 4 张并行
        phase = Phase.ANALYZING
        val targets = items.filter { !it.isVideo && !it.isFavorite }.take(analyzeLimit)
        val todo = targets.filter { it.analysis == null }
        val total = targets.size
        var done = total - todo.size
        progressText = "正在用 AI 分析照片… $done/$total"
        if (todo.isNotEmpty()) {
            coroutineScope {
                val queue = Channel<PhotoItem>(Channel.UNLIMITED)
                todo.forEach { queue.trySend(it) }
                queue.close()
                val results = Channel<Pair<String, AnalysisResult?>>(Channel.UNLIMITED)
                repeat(4) {
                    launch(Dispatchers.Default) {
                        for (it in queue) {
                            if (!isActive) break
                            val r = runCatching { analyzer.analyze(it) }.getOrNull()
                            results.send(it.id to r)
                        }
                    }
                }
                val pending = ArrayList<Pair<String, AnalysisResult?>>()
                repeat(todo.size) { n ->
                    pending += results.receive()
                    done++
                    if (pending.size >= 8 || n == todo.size - 1) {
                        applyResults(pending)
                        pending.clear()
                        progress = 0.05f + 0.85f * done / maxOf(1, total)
                        progressText = "正在用 AI 分析照片… $done/$total"
                    }
                    if (n % 240 == 239) {
                        rebuildCategories()
                        saveCache()
                    }
                }
            }
        }
        saveCache()

        // 相似分组（AI 特征 + dHash + 拍摄时间），截图和收藏不参与
        progressText = "正在查找相似照片…"
        val entries = items.mapNotNull { item ->
            val a = item.analysis ?: return@mapNotNull null
            if (item.isScreenshot || item.isFavorite) return@mapNotNull null
            HashEntry(item.id, a.dHash, item.dateMillis?.let { it / 1000.0 }, a.feature)
        }
        val groups = withContext(Dispatchers.Default) {
            SimilarityGrouper.groups(entries, featureNear = FEATURE_NEAR, featureDup = FEATURE_DUP)
        }
        similarGroups = groups
        rebuildCategories()

        // 相似组里的照片算人脸质量，用来挑「推荐保留」
        val faceTargets = groups.flatten().mapNotNull { item(it) }.filter { it.analysis?.faceChecked == false }
        if (faceTargets.isNotEmpty()) {
            progress = 0.92f
            progressText = "正在挑选每组最好的一张…"
            var fDone = 0
            coroutineScope {
                val queue = Channel<PhotoItem>(Channel.UNLIMITED)
                faceTargets.forEach { queue.trySend(it) }
                queue.close()
                val results = Channel<Pair<String, Float?>>(Channel.UNLIMITED)
                repeat(4) {
                    launch(Dispatchers.Default) {
                        for (it in queue) results.send(it.id to runCatching { analyzer.faceQuality(it) }.getOrNull())
                    }
                }
                val batch = ArrayList<Pair<String, Float?>>()
                repeat(faceTargets.size) { n ->
                    batch += results.receive()
                    fDone++
                    if (batch.size >= 8 || n == faceTargets.size - 1) {
                        val copy = items.toMutableList()
                        for ((id, q) in batch) {
                            val i = index[id] ?: continue
                            copy[i] = copy[i].copy(analysis = copy[i].analysis?.copy(faceQuality = q, faceChecked = true))
                        }
                        items = copy
                        batch.clear()
                        progress = 0.92f + 0.08f * fDone / faceTargets.size
                    }
                }
            }
            saveCache()
        }
        rebuildCategories()
        progress = 1f
        progressText = "分析完成"
        phase = Phase.DONE
        scanFinishedTick++
    }

    private fun applyResults(results: List<Pair<String, AnalysisResult?>>) {
        if (results.isEmpty()) return
        val copy = items.toMutableList()
        for ((id, r) in results) {
            val i = index[id] ?: continue
            if (r != null) copy[i] = copy[i].copy(analysis = r)
        }
        items = copy
    }

    private suspend fun saveCache() {
        val snapshot = items
        withContext(Dispatchers.IO) {
            cache.save(snapshot.filter { it.analysis != null }
                .associate { it.id to AnalysisCache.Entry(it.dateModified, it.analysis!!) })
        }
    }

    fun clearAnalysisCache() {
        cache.clear()
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
        persist()
    }

    fun rebuildCategories() {
        categoryIds = CategoryRules.build(items, similarGroups, blurThreshold, largeFileMB)
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
    fun undecided(ids: List<String>): List<String> = ids.filter { it !in toDelete && it !in kept }

    /** 可清理（不含视频、大文件和美食/宠物/风景） */
    val cleanableIds: Set<String>
        get() = CleanCategory.entries.filter { it != CleanCategory.VIDEOS && it != CleanCategory.LARGE && !it.isBrowse }
            .flatMap { ids(it) }.toSet()

    fun cardTags(item: PhotoItem): List<String> = CategoryRules.cardTags(item, blurThreshold)

    fun bestId(group: List<String>): String? {
        val its = group.mapNotNull { item(it) }
        if (its.isEmpty()) return null
        val i = SimilarityGrouper.bestIndex(its.map {
            BestCandidate(it.analysis?.faceQuality, it.analysis?.quality, it.analysis?.sharpness ?: 0.0, it.pixelCount)
        })
        return its[i].id
    }

    // ---------------- 标记 ----------------
    fun set(id: String, d: Decision?) {
        when (d) {
            Decision.DELETE -> { toDelete = toDelete + id; kept = kept - id }
            Decision.KEEP -> { kept = kept + id; toDelete = toDelete - id }
            null -> { toDelete = toDelete - id; kept = kept - id }
        }
        persist()
    }

    fun toggleDelete(id: String) = set(id, if (id in toDelete) null else Decision.DELETE)

    fun markAll(ids: Collection<String>, d: Decision?) {
        val s = ids.toSet()
        when (d) {
            Decision.DELETE -> { toDelete = toDelete + s; kept = kept - s }
            Decision.KEEP -> { kept = kept + s; toDelete = toDelete - s }
            null -> { toDelete = toDelete - s; kept = kept - s }
        }
        persist()
    }

    /** 相似组：保留最佳，其余标记删除（收藏的不自动标记） */
    fun keepBestDeleteRest(group: List<String>) {
        val best = bestId(group) ?: return
        markAll(group.filter { it != best && item(it)?.isFavorite != true }, Decision.DELETE)
        set(best, Decision.KEEP)
    }

    fun resetKept() { kept = emptySet(); persist() }

    private fun persist() {
        prefs.edit().putStringSet(K_DELETE, toDelete).putStringSet(K_KEPT, kept).apply()
    }

    // ---------------- 删除 ----------------
    fun uris(ids: List<String>): List<Uri> = ids.mapNotNull { item(it)?.uri?.let(Uri::parse) }

    /** Android 11+ 返回系统确认框；更老的系统返回 null（界面自己弹确认框后调 deleteLegacy） */
    fun deleteRequest(ids: List<String>): IntentSender? = runCatching { repo.deleteRequest(uris(ids), useTrash && trashSupported) }.getOrNull()

    suspend fun deleteLegacy(ids: List<String>): Boolean {
        val n = withContext(Dispatchers.IO) { repo.deleteLegacy(uris(ids)) }
        if (n > 0) onDeleted(ids)
        return n > 0
    }

    /** 系统确认删除后调用：从列表里移除 */
    fun onDeleted(ids: List<String>) {
        val freed = bytes(ids)
        val gone = ids.toSet()
        replaceItems(items.filter { it.id !in gone })
        similarGroups = similarGroups.map { g -> g.filter { it !in gone } }.filter { it.size > 1 }
        toDelete = toDelete - gone
        persist()
        rebuildCategories()
        val where = if (useTrash && trashSupported) "已移到系统回收站，30 天内可在相册/文件管理的「回收站」恢复。" else "已永久删除。"
        lastDeleteMessage = "已删除 ${ids.size} 项，释放 ${Fmt.bytes(freed)}。$where"
    }

    fun onDeleteCancelled() {
        lastDeleteMessage = null
    }

    companion object {
        private const val K_DELETE = "toDeleteIDs"
        private const val K_KEPT = "keptIDs"
        private const val K_BLUR = "blurThreshold"
        private const val K_LARGE = "largeFileMB"
        private const val K_LIMIT = "analyzeLimit"
        private const val K_NAME = "userName"
        private const val K_TRASH = "useTrash"
        /** MobileNetV3 特征向量（已归一化）的距离阈值：比苹果的特征稍宽一点 */
        const val FEATURE_NEAR = 0.5f
        const val FEATURE_DUP = 0.3f
    }
}
