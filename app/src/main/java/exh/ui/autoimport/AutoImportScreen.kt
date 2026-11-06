package exh.ui.autoimport

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import cafe.adriel.voyager.core.model.rememberScreenModel
import cafe.adriel.voyager.navigator.LocalNavigator
import cafe.adriel.voyager.navigator.currentOrThrow
import eu.kanade.presentation.components.AppBar
import eu.kanade.presentation.util.Screen
import tachiyomi.i18n.MR
import tachiyomi.i18n.kmk.KMR
import tachiyomi.i18n.sy.SYMR
import tachiyomi.presentation.core.components.material.Button
import tachiyomi.presentation.core.components.material.Scaffold
import tachiyomi.presentation.core.components.material.padding
import tachiyomi.presentation.core.i18n.stringResource
import tachiyomi.presentation.core.util.plus

class AutoImportScreen : Screen() {

    @Composable
    override fun Content() {
        val screenModel = rememberScreenModel { AutoImportScreenModel() }
        val state by screenModel.state.collectAsState()
        val navigator = LocalNavigator.currentOrThrow
        val context = LocalContext.current

        Scaffold(
            topBar = { scrollBehavior ->
                AppBar(
                    title = stringResource(KMR.strings.auto_import),
                    navigateUp = navigator::pop,
                    scrollBehavior = scrollBehavior,
                )
            },
        ) { paddingValues ->
            when (state.state) {
                AutoImportState.State.INPUT, AutoImportState.State.SCANNING -> {
                    Column(
                        Modifier
                            .padding(paddingValues)
                            .verticalScroll(rememberScrollState())
                            .padding(MaterialTheme.padding.medium),
                    ) {
                        Text(
                            text = stringResource(KMR.strings.auto_import_title),
                            style = MaterialTheme.typography.titleLarge,
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = stringResource(KMR.strings.auto_import_description),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Spacer(Modifier.height(16.dp))
                        
                        // Show scanning status
                        if (state.state == AutoImportState.State.SCANNING) {
                            Text(
                                text = stringResource(KMR.strings.auto_import_scanning),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(Modifier.height(16.dp))
                        }
                        
                        // Show scan error
                        state.scanError?.let { error ->
                            Text(
                                text = stringResource(KMR.strings.auto_import_scan_error, error),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error,
                            )
                            Spacer(Modifier.height(16.dp))
                        }
                        
                        // KMK -->: Single one-click auto import button
                        Button(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = { screenModel.startAutoImport(context) },
                            enabled = state.state != AutoImportState.State.SCANNING,
                        ) {
                            Text(
                                text = if (state.state == AutoImportState.State.SCANNING) {
                                    stringResource(KMR.strings.auto_import_scanning)
                                } else {
                                    stringResource(KMR.strings.auto_import_button)
                                }
                            )
                        }
                        // KMK <--
                        
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = stringResource(KMR.strings.auto_import_help),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                AutoImportState.State.PROGRESS -> {
                    LazyColumn(
                        contentPadding = paddingValues + PaddingValues(MaterialTheme.padding.medium),
                    ) {
                        item(key = "top") {
                            Column {
                                Text(
                                    text = stringResource(KMR.strings.auto_import_importing),
                                    style = MaterialTheme.typography.titleLarge,
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(
                                    Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    val progress = state.progress.toFloat()
                                    if (state.progressTotal > 0 && !progress.isNaN()) {
                                        val realProgress = progress / state.progressTotal
                                        if (!realProgress.isNaN()) {
                                            LinearProgressIndicator(
                                                progress = { realProgress },
                                                modifier = Modifier
                                                    .padding(top = 2.dp)
                                                    .weight(1f),
                                            )
                                        }
                                    }
                                    Text(
                                        text = "${state.progress}/${state.progressTotal}",
                                        modifier = Modifier.weight(0.15f),
                                        textAlign = TextAlign.Center,
                                        style = MaterialTheme.typography.bodyMedium,
                                    )
                                }
                                Spacer(modifier = Modifier.height(12.dp))
                            }
                        }
                        itemsIndexed(
                            state.events,
                            key = { index, text -> "auto-import-${index + text.hashCode()}" },
                        ) { _, text ->
                            Text(
                                text = text,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.fillMaxWidth(),
                                textAlign = TextAlign.Center,
                            )
                        }
                        state.summary?.let { summary ->
                            item(key = "summary") {
                                Column {
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Text(
                                        text = stringResource(
                                            KMR.strings.auto_import_summary,
                                            summary.importedCount,
                                            summary.failedCount,
                                            summary.errorCount,
                                        ),
                                        style = MaterialTheme.typography.titleMedium,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier.fillMaxWidth(),
                                    )
                                    if (summary.failedTitles.isNotEmpty()) {
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(
                                            text = stringResource(KMR.strings.auto_import_failed_titles),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.error,
                                        )
                                        summary.failedTitles.forEach { title ->
                                            Text(
                                                text = "  • $title",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.error,
                                            )
                                        }
                                    }
                                    if (summary.errorMessages.isNotEmpty()) {
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(
                                            text = stringResource(KMR.strings.auto_import_errors),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.error,
                                        )
                                        summary.errorMessages.forEach { error ->
                                            Text(
                                                text = "  • $error",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.error,
                                            )
                                        }
                                    }
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Button(
                                        modifier = Modifier.fillMaxWidth(),
                                        onClick = screenModel::finish,
                                    ) {
                                        Text(text = stringResource(MR.strings.action_ok))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        val onDismissRequest = screenModel::dismissDialog
        when (state.dialog) {
            AutoImportScreenModel.AutoImportDialog.NoTitlesSpecified -> AlertDialog(
                onDismissRequest = onDismissRequest,
                confirmButton = {
                    TextButton(onClick = onDismissRequest) {
                        Text(text = stringResource(MR.strings.action_ok))
                    }
                },
                title = {
                    Text(text = stringResource(KMR.strings.auto_import_no_titles))
                },
                text = {
                    Text(text = stringResource(KMR.strings.auto_import_no_titles_message))
                },
            )
            AutoImportScreenModel.AutoImportDialog.NoSourcesEnabled -> AlertDialog(
                onDismissRequest = onDismissRequest,
                confirmButton = {
                    TextButton(onClick = onDismissRequest) {
                        Text(text = stringResource(MR.strings.action_ok))
                    }
                },
                title = {
                    Text(text = stringResource(KMR.strings.auto_import_no_sources))
                },
                text = {
                    Text(text = stringResource(KMR.strings.auto_import_no_sources_message))
                },
            )
            null -> Unit
        }
    }
}
