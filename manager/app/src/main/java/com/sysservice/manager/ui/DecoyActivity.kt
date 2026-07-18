package com.sysservice.manager.ui

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.sysservice.manager.ui.theme.KernelSUTheme

/**
 * Decoy launcher screen. Looks like a plain "System Services" viewer.
 * The real manager (MainActivity) opens only via a hidden action:
 *   - long-press the "System Services" title  -> reveals a "Service Manager" menu item
 *   - or tap the title 7 times
 */
class DecoyActivity : ComponentActivity() {
    @OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            KernelSUTheme {
                val context = LocalContext.current
                var overflow by remember { mutableStateOf(false) }
                var hidden by remember { mutableStateOf(false) }
                var taps by remember { mutableIntStateOf(0) }

                val services = listOf(
                    "com.android.systemui", "com.google.android.gms",
                    "surfaceflinger", "media.codec", "netd",
                    "audioserver", "com.android.phone", "cameraserver",
                    "installd", "vold", "zygote64", "statsd"
                )

                fun openManager() {
                    startActivity(Intent(context, MainActivity::class.java))
                }

                Scaffold(
                    topBar = {
                        TopAppBar(
                            title = {
                                Text(
                                    text = "System Services",
                                    modifier = Modifier.combinedClickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null,
                                        onClick = {
                                            taps += 1
                                            if (taps >= 7) {
                                                taps = 0
                                                openManager()
                                            }
                                        },
                                        onLongClick = { hidden = true }
                                    )
                                )
                            },
                            actions = {
                                IconButton(onClick = { overflow = true }) {
                                    Icon(Icons.Default.MoreVert, contentDescription = null)
                                }
                                DropdownMenu(
                                    expanded = overflow,
                                    onDismissRequest = { overflow = false }
                                ) {
                                    DropdownMenuItem(text = { Text("Refresh") }, onClick = { overflow = false })
                                    DropdownMenuItem(text = { Text("Show system processes") }, onClick = { overflow = false })
                                    DropdownMenuItem(text = { Text("About") }, onClick = { overflow = false })
                                }
                                DropdownMenu(
                                    expanded = hidden,
                                    onDismissRequest = { hidden = false }
                                ) {
                                    DropdownMenuItem(
                                        text = { Text("Service Manager") },
                                        onClick = {
                                            hidden = false
                                            openManager()
                                        }
                                    )
                                }
                            }
                        )
                    }
                ) { padding ->
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = padding
                    ) {
                        items(services) { name ->
                            ListItem(
                                headlineContent = { Text(name) },
                                supportingContent = { Text("Running") }
                            )
                            HorizontalDivider()
                        }
                    }
                }
            }
        }
    }
}
