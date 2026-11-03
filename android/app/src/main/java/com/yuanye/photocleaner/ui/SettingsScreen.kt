package com.yuanye.photocleaner.ui

import android.os.Build
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.yuanye.photocleaner.BuildConfig
import com.yuanye.photocleaner.CleanupViewModel
import com.yuanye.photocleaner.R
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import kotlin.math.roundToInt

@Composable
fun SettingsScreen(vm: CleanupViewModel, onBack: () -> Unit) {
    val view = LocalView.current
    var name by remember { mutableStateOf(vm.userName) }
    var confirmClear by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize()) {
        TopBar(s(R.string.settings), { vm.updateName(name.trim()); onBack() })
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = T.pagePadding),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Group(s(R.string.set_name)) {
                OutlinedTextField(
                    name, { name = it; vm.updateName(it.trim()) }, singleLine = true, modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = T.accent, unfocusedBorderColor = T.fillHigh,
                        focusedTextColor = T.text, unfocusedTextColor = T.text, cursorColor = T.accent),
                    label = { Text(s(R.string.set_name)) },
                )
                Text(s(R.string.set_name_preview, s(R.string.greeting_fmt, s(T.greeting()), name.ifBlank { s(R.string.hello) })), color = T.text2, fontSize = T.caption)
            }
            Group(s(R.string.set_detect)) {
                SliderRow(s(R.string.set_blur), vm.blurThreshold.toFloat(), 20f..200f, "${vm.blurThreshold.roundToInt()}") { vm.updateBlur(it.roundToInt().toDouble()) }
                SliderRow(s(R.string.set_large), vm.largeFileMB.toFloat(), 2f..100f, s(R.string.set_large_value, vm.largeFileMB.roundToInt())) { vm.updateLarge(it.roundToInt().toDouble()) }
                Text(s(R.string.set_detect_note), color = T.text2, fontSize = T.caption)
                Text(s(R.string.set_full_library_note), color = T.text2, fontSize = T.caption)
            }
            Group(s(R.string.set_delete)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(s(R.string.set_trash), color = T.text, fontSize = T.body)
                        Text(if (vm.trashSupported) s(R.string.set_trash_off) else s(R.string.set_trash_unsupported), color = T.text2, fontSize = T.caption)
                    }
                    Switch(vm.useTrash && vm.trashSupported, { vm.updateTrash(it) }, enabled = vm.trashSupported,
                        colors = SwitchDefaults.colors(checkedTrackColor = T.accent))
                }
                Text(s(R.string.google_photos_note), color = T.text2, fontSize = T.caption)
                HorizontalDivider(color = T.hairline)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(s(R.string.set_kept), color = T.text2, fontSize = T.callout, modifier = Modifier.weight(1f))
                    Text(s(R.string.n_items, vm.kept.size), color = T.text, fontSize = T.callout, fontWeight = FontWeight.SemiBold)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(s(R.string.quick_later), color = T.text2, fontSize = T.callout, modifier = Modifier.weight(1f))
                    Text(s(R.string.n_items, vm.later.size), color = T.text, fontSize = T.callout, fontWeight = FontWeight.SemiBold)
                }
                SecondaryButton(s(R.string.set_reset_kept), tint = T.text2) { Haptics.light(view); vm.resetKept() }
                SecondaryButton(s(R.string.set_clear_cache), tint = T.text2) { confirmClear = true }
            }
            Group(s(R.string.set_privacy)) {
                Text(s(R.string.privacy_1), color = T.text2, fontSize = T.caption)
                Text(s(R.string.privacy_2), color = T.text2, fontSize = T.caption)
                Text(s(R.string.privacy_3), color = T.text2, fontSize = T.caption)
            }
            Group(s(R.string.set_about)) {
                Text(s(R.string.about_version, s(R.string.app_name), BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE, Build.VERSION.RELEASE), color = T.text, fontSize = T.callout)
                Text(s(R.string.about_ml), color = T.text2, fontSize = T.caption)
                Text(s(R.string.about_favorites), color = T.text2, fontSize = T.caption)
                Text(s(R.string.about_language), color = T.text2, fontSize = T.caption)
            }
            Spacer(Modifier.height(30.dp))
        }
    }
    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text(s(R.string.clear_cache_title)) },
            text = { Text(s(R.string.clear_cache_text)) },
            confirmButton = { TextButton(onClick = { confirmClear = false; vm.clearAnalysisCache() }) { Text(s(R.string.clear), color = T.danger) } },
            dismissButton = { TextButton(onClick = { confirmClear = false }) { Text(s(R.string.cancel)) } },
            containerColor = T.card,
        )
    }
}

@Composable
private fun Group(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, color = T.text2, fontSize = T.caption, modifier = Modifier.padding(start = 4.dp).semantics { heading() })
        Column(Modifier.fillMaxWidth().card(radius = 20.dp, padding = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)
    }
}

@Composable
private fun SliderRow(label: String, value: Float, range: ClosedFloatingPointRange<Float>, display: String, onChange: (Float) -> Unit) {
    var v by remember(value) { mutableFloatStateOf(value) }
    Column {
        Row {
            Text(label, color = T.text, fontSize = T.body, modifier = Modifier.weight(1f))
            Text(display, color = T.accent, fontSize = T.callout, fontWeight = FontWeight.SemiBold)
        }
        Slider(v, { v = it }, valueRange = range, onValueChangeFinished = { onChange(v) },
            colors = SliderDefaults.colors(thumbColor = T.accent, activeTrackColor = T.accent, inactiveTrackColor = T.fillHigh))
    }
}
