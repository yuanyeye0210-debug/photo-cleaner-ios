package com.yuanye.photocleaner

import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.activity.viewModels
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.decode.VideoFrameDecoder
import coil.memory.MemoryCache
import com.yuanye.photocleaner.ui.AppRoot

class PhotoCleanerApp : Application(), ImageLoaderFactory {
    override fun onCreate() {
        super.onCreate()
        CrashLog.install(this)
    }

    override fun newImageLoader(): ImageLoader =
        ImageLoader.Builder(this)
            .components { add(VideoFrameDecoder.Factory()) }
            .memoryCache { MemoryCache.Builder(this).maxSizePercent(0.3).build() }
            .crossfade(false)
            .build()
}

class MainActivity : ComponentActivity() {
    private val vm: CleanupViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        super.onCreate(savedInstanceState)
        setContent { AppRoot() }
        if (savedInstanceState == null) {
            handle(intent)
            CrashLog.showIfAny(this)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    /** 桌面小组件点进来：打开滑动整理 */
    private fun handle(intent: Intent?) {
        if (intent?.getStringExtra(EXTRA_OPEN) == OPEN_SWIPE) {
            intent.removeExtra(EXTRA_OPEN)
            vm.openSwipeRequest++
        }
    }

    companion object {
        const val EXTRA_OPEN = "open"
        const val OPEN_SWIPE = "swipe"
    }
}
