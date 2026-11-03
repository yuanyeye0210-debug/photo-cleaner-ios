package com.yuanye.photocleaner.data

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.imageembedder.ImageEmbedder
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.yuanye.photocleaner.core.AnalysisResult
import com.yuanye.photocleaner.core.GrayImage
import com.yuanye.photocleaner.core.ImageMath
import com.yuanye.photocleaner.core.PhotoItem
import com.yuanye.photocleaner.core.QualityScore
import com.yuanye.photocleaner.core.VisionRules
import com.yuanye.photocleaner.core.MotionPhoto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.tasks.await

/**
 * 本机 AI 识别（不联网、不上传）：
 *  - Google ML Kit：内容识别（图像标签）、二维码、文字识别（中文 + 英文）、人脸（睁眼 / 微笑）
 *  - MediaPipe Image Embedder（MobileNetV3 小模型，打包在 App 里）：图像特征向量，用于 AI 相似度
 *  - dHash / 拉普拉斯方差 / 亮度：与 iOS 版同一套算法
 */
class Analyzer(context: Context, private val repo: MediaRepository) {
    private val labeler = ImageLabeling.getClient(
        ImageLabelerOptions.Builder().setConfidenceThreshold(0.1f).build()
    )
    private val barcode = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
    )
    private val text = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
    private val face = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .setMinFaceSize(0.08f)
            .build()
    )
    /** 只数人脸（快速模式，不做睁眼/微笑分类） */
    private val faceCounter = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setMinFaceSize(0.1f)
            .build()
    )
    private val embedder: ImageEmbedder? = runCatching {
        ImageEmbedder.createFromOptions(
            context,
            ImageEmbedder.ImageEmbedderOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath("image_embedder.tflite").build())
                .setRunningMode(RunningMode.IMAGE)
                .setL2Normalize(true)
                .setQuantize(false)
                .build()
        )
    }.getOrNull()
    private val embedLock = Any()

    val hasEmbedder: Boolean get() = embedder != null

    suspend fun analyze(item: PhotoItem): AnalysisResult? {
        val uri = Uri.parse(item.uri)
        val bmp = repo.decode(uri, 384, 384) ?: return null
        val tiny = gray(Bitmap.createScaledBitmap(bmp, 9, 8, true))
        val (sw, sh) = ImageMath.fittedSize(bmp.width, bmp.height, 256)
        val small = gray(if (sw == bmp.width && sh == bmp.height) bmp else Bitmap.createScaledBitmap(bmp, sw, sh, true))
        val sharp = ImageMath.laplacianVariance(small)
        val bright = ImageMath.meanBrightness(small)
        val contrast = ImageMath.contrast(small)

        // 同一张位图同时跑：内容识别、二维码、特征向量、动态照片检测（以前是一个接一个）
        val input = InputImage.fromBitmap(bmp, 0)
        val labelTask = labeler.process(input)
        val qrTask = barcode.process(input)
        val faceTask = faceCounter.process(input)
        val (feature, motion) = coroutineScope {
            val f = async(Dispatchers.Default) { embed(bmp) }
            val m = async(Dispatchers.IO) { motionBytes(item) }
            f.await() to m.await()
        }
        val labels = runCatching { labelTask.await().map { it.text to it.confidence } }.getOrDefault(emptyList())
        // 只有真正读出内容的二维码才算（避免花纹、栅栏被误认）
        val hasQR = runCatching { qrTask.await().any { !it.rawValue.isNullOrEmpty() } }.getOrDefault(false)
        val faceCount = runCatching { faceTask.await().size }.getOrNull()
        val tags = VisionRules.tags(labels, hasQR)

        var r = AnalysisResult(
            dHash = ImageMath.dHash(tiny),
            sharpness = sharp,
            brightness = bright,
            contrast = contrast,
            feature = feature,
            quality = QualityScore.score(sharp, bright, contrast),
            tags = tags,
            motionBytes = motion,
            labels = VisionRules.subjectLabels(labels),
            faceCount = faceCount,
        )
        val w = if (item.width > 0) item.width else bmp.width
        val h = if (item.height > 0) item.height else bmp.height
        val aspect = maxOf(w, h).toDouble() / maxOf(1, minOf(w, h))
        if (VisionRules.shouldRecognizeText(item.isScreenshot, tags, VisionRules.textLikelihood(labels), bright, aspect)) {
            val (tw, th) = VisionRules.textTargetSize(w, h)
            val big = repo.decode(uri, tw, th)
            if (big != null) {
                val lines = runCatching {
                    text.process(InputImage.fromBitmap(big, 0)).await().textBlocks.flatMap { b -> b.lines.map { it.text } }
                }.getOrDefault(emptyList())
                r = r.copy(
                    textChecked = true,
                    textLines = lines.size,
                    textChars = lines.sumOf { it.count { ch -> !ch.isWhitespace() } },
                    verificationCode = VisionRules.verificationCode(lines),
                )
                // 文字很多时，文档 / 票据门槛放宽到 0.5
                if (r.textHeavy) r = r.copy(tags = VisionRules.tags(labels, hasQR, textHeavy = true))
            }
        }
        return r
    }

    /** 人脸质量（0~1）：多张脸取平均；没检测到人脸返回 null */
    suspend fun faceQuality(item: PhotoItem): Float? {
        val bmp = repo.decode(Uri.parse(item.uri), 768, 768) ?: return null
        val faces = runCatching { face.process(InputImage.fromBitmap(bmp, 0)).await() }.getOrNull() ?: return null
        val qs = faces.mapNotNull { QualityScore.face(it.leftEyeOpenProbability, it.rightEyeOpenProbability, it.smilingProbability) }
        if (qs.isEmpty()) return null
        return qs.average().toFloat()
    }

    /** 动态照片里内嵌视频的大小（只读文件头尾）；不是动态照片返回 0 */
    fun motionBytes(item: PhotoItem): Long {
        if (item.isVideo || !(item.mime.contains("jpeg") || item.mime.contains("jpg") || item.mime.isEmpty())) return 0
        return repo.withSource(Uri.parse(item.uri)) { src -> MotionPhoto.detect(src)?.videoBytes(src.size) } ?: 0L
    }

    private fun embed(bmp: Bitmap): ByteArray? {
        val e = embedder ?: return null
        return runCatching {
            synchronized(embedLock) {
                val res = e.embed(BitmapImageBuilder(bmp).build())
                res.embeddingResult().embeddings().firstOrNull()?.floatEmbedding()
            }
        }.getOrNull()?.let { VisionRules.normalized(it) }?.let { VisionRules.quantize(it) }
    }

    private fun gray(b: Bitmap): GrayImage {
        val w = b.width
        val h = b.height
        val px = IntArray(w * h)
        b.getPixels(px, 0, w, 0, 0, w, h)
        val out = ByteArray(w * h)
        for (i in px.indices) {
            val c = px[i]
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val bl = c and 0xFF
            out[i] = ((r * 299 + g * 587 + bl * 114) / 1000).toByte()
        }
        return GrayImage(w, h, out)
    }
}
