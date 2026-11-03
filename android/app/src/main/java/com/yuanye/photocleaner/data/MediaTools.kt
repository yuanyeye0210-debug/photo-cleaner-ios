package com.yuanye.photocleaner.data

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.container.Mp4LocationData
import androidx.media3.container.Mp4TimestampData
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EncoderUtil
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMuxer
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.yuanye.photocleaner.core.MotionPhoto
import com.yuanye.photocleaner.core.PhotoItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume

/** 工具结果 */
sealed interface ToolOutcome {
    data class Ok(val newUri: Uri, val before: Long, val after: Long) : ToolOutcome
    /** 压缩后不会更小 / 已经是 HEVC */
    data object NotSmaller : ToolOutcome
    data object AlreadyHevc : ToolOutcome
    data class Failed(val reason: String) : ToolOutcome
}

/**
 * 视频压缩成 HEVC（H.265）：Media3 Transformer + 手机自带的硬件编码器。
 * 新视频保留原来的拍摄时间（MediaStore + MP4 头）和地点（MP4 的 ©xyz 位置信息），放回原来的文件夹。
 * 原视频不会自动删：交给界面放进「待删除」，用户确认后才删。
 */
@OptIn(UnstableApi::class)
class VideoCompressor(private val context: Context, private val repo: MediaRepository) {

    val supported: Boolean by lazy {
        Build.VERSION.SDK_INT >= 29 && runCatching { EncoderUtil.getSupportedEncoders(MimeTypes.VIDEO_H265).isNotEmpty() }.getOrDefault(false)
    }

    private data class Meta(val bitrate: Int, val durationMs: Long, val location: Pair<Float, Float>?, val isHevc: Boolean)

    private fun meta(uri: Uri, size: Long): Meta {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(context, uri)
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val br = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull()
                ?: if (dur > 0) (size * 8000 / dur).toInt() else 0
            val loc = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_LOCATION)?.let(::parseIso6709)
            val mime = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: ""
            // 视频轨道编码：只有 API 30+ 能直接拿到，较老系统看容器里的 hvc1
            val hevc = mime.contains("hevc", true) || runCatching {
                val ex = android.media.MediaExtractor()
                ex.setDataSource(context, uri, null)
                val any = (0 until ex.trackCount).any { ex.getTrackFormat(it).getString(android.media.MediaFormat.KEY_MIME) == MimeTypes.VIDEO_H265 }
                ex.release(); any
            }.getOrDefault(false)
            Meta(br, dur, loc, hevc)
        } catch (e: Throwable) {
            Meta(0, 0, null, false)
        } finally {
            runCatching { r.release() }
        }
    }

    /** "+37.4219-122.0840/" → (37.4219, -122.0840) */
    private fun parseIso6709(s: String): Pair<Float, Float>? {
        val m = Regex("""([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)""").find(s) ?: return null
        val lat = m.groupValues[1].toFloatOrNull() ?: return null
        val lon = m.groupValues[2].toFloatOrNull() ?: return null
        if (lat == 0f && lon == 0f) return null
        return lat to lon
    }

    suspend fun compress(item: PhotoItem, onProgress: (Float) -> Unit): ToolOutcome {
        if (!supported) return ToolOutcome.Failed("unsupported")
        val uri = Uri.parse(item.uri)
        val m = withContext(Dispatchers.IO) { meta(uri, item.fileSize) }
        if (m.isHevc) return ToolOutcome.AlreadyHevc
        val out = File(context.cacheDir, "compress_${System.nanoTime()}.mp4")
        try {
            // 目标码率：原来的一半左右（HEVC 同画质大约省 40%~50%）
            val target = if (m.bitrate > 0) (m.bitrate * 0.5).toInt().coerceIn(800_000, 25_000_000) else 6_000_000
            val ok = export(uri, out, target, m, item.dateMillis, useInAppMuxer = true, onProgress = onProgress)
                ?: export(uri, out, target, m, item.dateMillis, useInAppMuxer = false, onProgress = onProgress)
                ?: return ToolOutcome.Failed("export")
            if (!ok) return ToolOutcome.Failed("export")
            val after = out.length()
            if (after <= 0) return ToolOutcome.Failed("empty")
            if (after >= item.fileSize * 0.9) return ToolOutcome.NotSmaller
            val base = item.name.substringBeforeLast('.').ifEmpty { "VID_" + System.currentTimeMillis() }
            val newUri = withContext(Dispatchers.IO) {
                repo.insert(true, base + "_HEVC.mp4", "video/mp4", item.relativePath, item.dateMillis, item.isFavorite) { os ->
                    out.inputStream().use { it.copyTo(os) }
                }
            } ?: return ToolOutcome.Failed("save")
            return ToolOutcome.Ok(newUri, item.fileSize, after)
        } finally {
            out.delete()
        }
    }

    /** 返回 true = 成功；false = 失败；null = 这种封装方式不行，换一种再试 */
    private suspend fun export(
        uri: Uri, out: File, bitrate: Int, m: Meta, dateTaken: Long?, useInAppMuxer: Boolean, onProgress: (Float) -> Unit,
    ): Boolean? = withContext(Dispatchers.Main) {
        out.delete()
        val enc = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
            .setEnableFallback(true)
            .build()
        val b = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H265)
            .setEncoderFactory(enc)
        if (useInAppMuxer) {
            b.setMuxerFactory(InAppMuxer.Factory.Builder().setMetadataProvider { entries ->
                // 写入拍摄时间和地点（原视频有的话）
                if (m.location != null) {
                    entries.removeAll { it is Mp4LocationData }
                    entries.add(Mp4LocationData(m.location.first, m.location.second))
                }
                if (dateTaken != null && dateTaken > 0) {
                    entries.removeAll { it is Mp4TimestampData }
                    val t = Mp4TimestampData.unixTimeToMp4TimeSeconds(dateTaken)
                    entries.add(Mp4TimestampData(t, t))
                }
            }.build())
        }
        var transformer: Transformer? = null
        coroutineScope {
            val poll = launch {
                val holder = ProgressHolder()
                while (true) {
                    delay(300)
                    val t = transformer ?: continue
                    if (t.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) onProgress(holder.progress / 100f)
                }
            }
            val result = suspendCancellableCoroutine<Boolean?> { cont ->
                val t = b.addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (cont.isActive) cont.resume(true)
                    }

                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                        // 自带封装器失败时换系统封装器再试一次
                        if (cont.isActive) cont.resume(if (useInAppMuxer) null else false)
                    }
                }).build()
                transformer = t
                cont.invokeOnCancellation { runCatching { t.cancel() } }
                t.start(EditedMediaItem.Builder(MediaItem.fromUri(uri)).build(), out.absolutePath)
            }
            poll.cancel()
            result
        }
    }
}

/**
 * 动态照片转静态：生成一张新的静态 JPEG（去掉内嵌的视频，EXIF 里的拍摄时间、地点原样保留），
 * 原来的动态照片交给界面放进「待删除」。
 */
class MotionConverter(private val repo: MediaRepository) {
    val supported: Boolean get() = Build.VERSION.SDK_INT >= 29

    fun convert(item: PhotoItem): ToolOutcome {
        if (!supported) return ToolOutcome.Failed("unsupported")
        val uri = Uri.parse(item.uri)
        val bytes = repo.readAll(uri) ?: return ToolOutcome.Failed("read")
        val info = MotionPhoto.detect(MotionPhoto.Bytes(bytes)) ?: return ToolOutcome.Failed("notMotion")
        val still = MotionPhoto.toStill(bytes, info)
        if (still.size >= bytes.size) return ToolOutcome.NotSmaller
        val base = item.name.substringBeforeLast('.').ifEmpty { "IMG_" + System.currentTimeMillis() }
        val newUri = repo.insert(false, base + "_still.jpg", "image/jpeg", item.relativePath, item.dateMillis, item.isFavorite) { os ->
            os.write(still)
        } ?: return ToolOutcome.Failed("save")
        return ToolOutcome.Ok(newUri, bytes.size.toLong(), still.size.toLong())
    }
}
