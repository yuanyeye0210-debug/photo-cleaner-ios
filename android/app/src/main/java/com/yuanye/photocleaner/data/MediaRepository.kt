package com.yuanye.photocleaner.data

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.IntentSender
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import com.yuanye.photocleaner.core.PhotoItem
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** 读取系统相册（MediaStore）、解码图片、删除 */
class MediaRepository(private val context: Context) {
    private val cr: ContentResolver get() = context.contentResolver

    private fun collection(video: Boolean): Uri =
        if (Build.VERSION.SDK_INT >= 29) {
            if (video) MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            else MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            if (video) MediaStore.Video.Media.EXTERNAL_CONTENT_URI else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

    /** 全部照片和视频，按拍摄时间从新到旧 */
    fun queryAll(): List<PhotoItem> {
        val out = ArrayList<PhotoItem>()
        query(false, out)
        query(true, out)
        out.sortByDescending { it.dateMillis ?: 0L }
        return out
    }

    private fun query(video: Boolean, out: MutableList<PhotoItem>) {
        val base = collection(video)
        val cols = mutableListOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_ADDED,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.WIDTH,
            MediaStore.MediaColumns.HEIGHT,
            "datetaken",
            "bucket_display_name",
        )
        if (!video) cols += MediaStore.Images.ImageColumns.ORIENTATION
        if (Build.VERSION.SDK_INT >= 29) cols += MediaStore.MediaColumns.RELATIVE_PATH
        if (Build.VERSION.SDK_INT >= 30) cols += MediaStore.MediaColumns.IS_FAVORITE
        val c = runCatching { cr.query(base, cols.toTypedArray(), null, null, null) }.getOrNull() ?: return
        c.use {
            val iId = it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val iSize = it.getColumnIndex(MediaStore.MediaColumns.SIZE)
            val iAdded = it.getColumnIndex(MediaStore.MediaColumns.DATE_ADDED)
            val iMod = it.getColumnIndex(MediaStore.MediaColumns.DATE_MODIFIED)
            val iW = it.getColumnIndex(MediaStore.MediaColumns.WIDTH)
            val iH = it.getColumnIndex(MediaStore.MediaColumns.HEIGHT)
            val iTaken = it.getColumnIndex("datetaken")
            val iBucket = it.getColumnIndex("bucket_display_name")
            val iOri = if (!video) it.getColumnIndex(MediaStore.Images.ImageColumns.ORIENTATION) else -1
            val iPath = if (Build.VERSION.SDK_INT >= 29) it.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH) else -1
            val iFav = if (Build.VERSION.SDK_INT >= 30) it.getColumnIndex(MediaStore.MediaColumns.IS_FAVORITE) else -1
            while (it.moveToNext()) {
                val id = it.getLong(iId)
                val taken = if (iTaken >= 0 && !it.isNull(iTaken)) it.getLong(iTaken) else 0L
                val added = if (iAdded >= 0) it.getLong(iAdded) * 1000 else 0L
                val date = if (taken > 0) taken else if (added > 0) added else null
                var w = if (iW >= 0) it.getInt(iW) else 0
                var h = if (iH >= 0) it.getInt(iH) else 0
                val ori = if (iOri >= 0) it.getInt(iOri) else 0
                if (ori == 90 || ori == 270) { val t = w; w = h; h = t }
                val bucket = if (iBucket >= 0) it.getString(iBucket) ?: "" else ""
                val path = if (iPath >= 0) it.getString(iPath) ?: "" else ""
                val shot = !video && isScreenshotFolder(bucket, path)
                val fav = iFav >= 0 && it.getInt(iFav) == 1
                out += PhotoItem(
                    id = (if (video) "v" else "i") + id,
                    uri = ContentUris.withAppendedId(base, id).toString(),
                    fileSize = if (iSize >= 0) it.getLong(iSize) else 0L,
                    dateMillis = date,
                    isVideo = video,
                    isScreenshot = shot,
                    isFavorite = fav,
                    width = w,
                    height = h,
                    dateModified = if (iMod >= 0) it.getLong(iMod) else 0L,
                )
            }
        }
    }

    private fun isScreenshotFolder(bucket: String, path: String): Boolean {
        val s = (bucket + "|" + path).lowercase()
        return "screenshot" in s || "截屏" in s || "截图" in s || "screen_shot" in s || "screencapture" in s
    }

    /** 把图片解码成软件位图（ARGB_8888），缩放到不超过 maxW×maxH，自动按 EXIF 转正 */
    fun decode(uri: Uri, maxW: Int, maxH: Int): Bitmap? = runCatching {
        if (Build.VERSION.SDK_INT >= 28) {
            val src = ImageDecoder.createSource(cr, uri)
            val bmp = ImageDecoder.decodeBitmap(src) { decoder, info, _ ->
                val (w, h) = fit(info.size.width, info.size.height, maxW, maxH)
                decoder.setTargetSize(w, h)
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
            if (bmp.config == Bitmap.Config.ARGB_8888) bmp else bmp.copy(Bitmap.Config.ARGB_8888, false)
        } else {
            decodeLegacy(uri, maxW, maxH)
        }
    }.getOrNull()

    private fun decodeLegacy(uri: Uri, maxW: Int, maxH: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        cr.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= maxW && bounds.outHeight / (sample * 2) >= maxH) sample *= 2
        val opts = BitmapFactory.Options().apply { inSampleSize = sample; inPreferredConfig = Bitmap.Config.ARGB_8888 }
        var bmp = cr.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) } ?: return null
        val rot = cr.openInputStream(uri)?.use {
            when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } ?: 0f
        if (rot != 0f) {
            val m = Matrix().apply { postRotate(rot) }
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }
        val (w, h) = fit(bmp.width, bmp.height, maxW, maxH)
        return if (w != bmp.width) Bitmap.createScaledBitmap(bmp, w, h, true) else bmp
    }

    private fun fit(w: Int, h: Int, maxW: Int, maxH: Int): Pair<Int, Int> {
        if (w <= 0 || h <= 0) return max(1, maxW) to max(1, maxH)
        val s = min(1.0, min(maxW.toDouble() / w, maxH.toDouble() / h))
        return max(1, (w * s).roundToInt()) to max(1, (h * s).roundToInt())
    }

    /** Android 11+：系统删除确认框。trash = 移到回收站（30 天内可恢复） */
    fun deleteRequest(uris: List<Uri>, trash: Boolean): IntentSender? {
        if (Build.VERSION.SDK_INT < 30) return null
        val pi = if (trash) MediaStore.createTrashRequest(cr, uris, true) else MediaStore.createDeleteRequest(cr, uris)
        return pi.intentSender
    }

    /** Android 10 及以下：直接删除（界面上先自己弹确认框） */
    fun deleteLegacy(uris: List<Uri>): Int {
        var n = 0
        for (u in uris) n += runCatching { cr.delete(u, null, null) }.getOrDefault(0)
        return n
    }
}
