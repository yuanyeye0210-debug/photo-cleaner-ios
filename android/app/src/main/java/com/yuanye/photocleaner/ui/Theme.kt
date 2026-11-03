package com.yuanye.photocleaner.ui

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.core.CleanCategory
import java.util.Calendar

/** 深色主题：纯黑底、深灰大圆角卡片、统一一个橙色强调色 */
object T {
    val bg = Color(0xFF000000)
    val bgElevated = Color(0xFF0B0B0C)
    val card = Color(0xFF1C1C1E)
    val fill = Color(0xFF2C2C2E)
    val fillHigh = Color(0xFF3A3A3C)
    val hairline = Color.White.copy(alpha = 0.07f)
    val text = Color.White
    val text2 = Color(0xFF8E8E93)
    val text3 = Color(0xFF5E5E63)
    val accent = Color(0xFFF2A23C)          // 唯一强调色：主操作、关键数字、图标
    val danger = Color(0xFFFF5A4F)          // 只用于删除
    val keep = Color(0xFF3CC47C)            // 只用于「保留」

    val rCard = 24.dp
    val pagePadding = 16.dp
    val gap = 12.dp

    val largeTitle = 28.sp
    val title = 20.sp
    val headline = 17.sp
    val body = 15.sp
    val callout = 14.sp
    val caption = 12.sp

    fun <V> spring() = spring<V>(dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow)

    fun greeting(): String = when (Calendar.getInstance().get(Calendar.HOUR_OF_DAY)) {
        in 5..10 -> "早上好"
        in 11..12 -> "中午好"
        in 13..17 -> "下午好"
        in 18..22 -> "晚上好"
        else -> "夜深了"
    }
}

val CleanCategory.icon: ImageVector
    get() = when (this) {
        CleanCategory.SIMILAR -> Icons.Rounded.ContentCopy
        CleanCategory.SCREENSHOTS -> Icons.Rounded.PhoneAndroid
        CleanCategory.TEXT_IMAGES -> Icons.Rounded.Chat
        CleanCategory.DOCUMENTS -> Icons.Rounded.Description
        CleanCategory.QR_CODES -> Icons.Rounded.QrCode2
        CleanCategory.LOW_QUALITY -> Icons.Rounded.ThumbDown
        CleanCategory.BLURRY -> Icons.Rounded.BlurOn
        CleanCategory.POOR_LIGHT -> Icons.Rounded.WbSunny
        CleanCategory.LARGE -> Icons.Rounded.SdStorage
        CleanCategory.VIDEOS -> Icons.Rounded.Videocam
        CleanCategory.FOOD -> Icons.Rounded.Restaurant
        CleanCategory.PETS -> Icons.Rounded.Pets
        CleanCategory.SCENERY -> Icons.Rounded.Landscape
    }

/** 触感反馈 */
object Haptics {
    fun light(v: View) { v.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK) }
    fun medium(v: View) { v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY) }
    fun success(v: View) {
        v.performHapticFeedback(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY)
    }
    fun warning(v: View) {
        v.performHapticFeedback(if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS)
    }
}
