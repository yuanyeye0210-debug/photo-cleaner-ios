package com.yuanye.photocleaner.widget

import android.content.Context
import android.content.Intent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.yuanye.photocleaner.MainActivity
import com.yuanye.photocleaner.R
import com.yuanye.photocleaner.core.Fmt
import com.yuanye.photocleaner.data.WidgetData

/** 桌面小组件：显示还有多少可以清理，点一下直接打开滑动整理 */
class PhotoWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = WidgetData.read(context)
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_OPEN, MainActivity.OPEN_SWIPE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val title = context.getString(R.string.widget_title)
        val big = if (s == null) "—" else s.cleanable.toString()
        val line1 = if (s == null) context.getString(R.string.widget_open_first)
        else context.getString(R.string.widget_cleanable, Fmt.bytes(s.cleanableBytes))
        val line2 = if (s != null && s.pending > 0) context.getString(R.string.widget_pending, s.pending) else context.getString(R.string.widget_tap)
        provideContent {
            Column(
                modifier = GlanceModifier.fillMaxSize().background(Color(0xFF1C1C1E)).cornerRadius(22.dp).padding(14.dp)
                    .clickable(actionStartActivity(intent))
                    .semantics { contentDescription = "$title, $big, $line1, $line2" },
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                Text(title, style = TextStyle(color = ColorProvider(Color(0xFFAEAEB2)), fontSize = 13.sp, fontWeight = FontWeight.Medium))
                Spacer(GlanceModifier.height(4.dp))
                Text(big, style = TextStyle(color = ColorProvider(Color(0xFFFF9F0A)), fontSize = 34.sp, fontWeight = FontWeight.Bold))
                Text(line1, style = TextStyle(color = ColorProvider(Color.White), fontSize = 13.sp))
                Spacer(GlanceModifier.height(2.dp))
                Text(line2, style = TextStyle(color = ColorProvider(Color(0xFF8E8E93)), fontSize = 12.sp))
            }
        }
    }

    companion object {
        suspend fun refresh(context: Context) = PhotoWidget().updateAll(context)
    }
}

class PhotoWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PhotoWidget()
}
