package com.yuanye.photocleaner.ui

import com.yuanye.photocleaner.R

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PhotoLibrary
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yuanye.photocleaner.Access
import com.yuanye.photocleaner.CleanupViewModel

@Composable
fun PermissionScreen(vm: CleanupViewModel) {
    val ctx = LocalContext.current
    var asked by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        asked = true
        val a = currentAccess(ctx)
        vm.access = a
        if (a != Access.NONE) vm.startScan()
    }
    Column(
        Modifier.fillMaxSize().systemBarsPadding().padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        IconBadge(Icons.Rounded.PhotoLibrary, T.accent, 84.dp)
        Spacer(Modifier.height(20.dp))
        Text(s(R.string.app_name), color = T.text, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        Text(
            s(R.string.perm_intro),
            color = T.text2, fontSize = 15.sp, textAlign = TextAlign.Center, lineHeight = 22.sp,
        )
        Spacer(Modifier.height(18.dp))
        Row(Modifier.card(radius = 18.dp, padding = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Lock, null, tint = T.accent, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(10.dp))
            Text(s(R.string.perm_privacy), color = T.text2, fontSize = 13.sp)
        }
        Spacer(Modifier.height(28.dp))
        PrimaryButton(s(R.string.perm_allow)) { launcher.launch(requiredPermissions()) }
        if (asked) {
            Spacer(Modifier.height(12.dp))
            Text(s(R.string.perm_settings), color = T.accent, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.pressable {
                    ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName)))
                })
        }
    }
}
