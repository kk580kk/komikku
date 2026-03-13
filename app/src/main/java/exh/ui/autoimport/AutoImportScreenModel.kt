package exh.ui.autoimport

import android.content.Context
import androidx.compose.runtime.getValue
import cafe.adriel.voyager.core.model.StateScreenModel
import cafe.adriel.voyager.core.model.screenModelScope
import com.aallam.similarity.NormalizedLevenshtein
import eu.kanade.domain.manga.model.toSManga
import eu.kanade.tachiyomi.source.CatalogueSource
import eu.kanade.tachiyomi.source.online.all.EHentai
import exh.util.ThrottleManager
import exh.util.trimOrNull
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.supervisorScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.withContext
import logcat.LogPriority
import mihon.feature.migration.list.search.SmartSourceSearchEngine
import tachiyomi.core.common.util.lang.withIOContext
import tachiyomi.core.common.util.system.logcat
import eu.kanade.domain.chapter.interactor.SyncChaptersWithSource
import eu.kanade.domain.manga.interactor.UpdateManga
import tachiyomi.domain.category.interactor.SetMangaCategories
import tachiyomi.domain.library.service.LibraryPreferences
import tachiyomi.domain.local.interactor.ScanLocalSource
import tachiyomi.domain.manga.interactor.GetManga
import tachiyomi.domain.manga.interactor.GetMangaByUrlAndSourceId
import tachiyomi.domain.manga.interactor.NetworkToLocalManga
import tachiyomi.domain.manga.model.Manga
import tachiyomi.domain.source.service.SourceManager
import uy.kohesive.injekt.Injekt
import uy.kohesive.injekt.api.get
import eu.kanade.tachiyomi.util.system.ImportNotificationHelper

class AutoImportScreenModel(
    private val sourceManager: SourceManager = Injekt.get(),
    private val getManga: GetManga = Injekt.get(),
    private val getMangaByUrlAndSourceId: GetMangaByUrlAndSourceId = Injekt.get(),
    private val networkToLocalManga: NetworkToLocalManga = Injekt.get(),
    private val updateManga: UpdateManga = Injekt.get(),
    private val syncChaptersWithSource: SyncChaptersWithSource = Injekt.get(),
    private val scanLocalSource: ScanLocalSource = Injekt.get(),
    private val libraryPreferences: LibraryPreferences = Injekt.get(),
) : StateScreenModel<AutoImportState>(AutoImportState()) {

    private val smartSearchEngine = SmartSourceSearchEngine(null)
    private val normalizedLevenshtein = NormalizedLevenshtein()
    private val throttleManager = ThrottleManager()

    /**
     * Scan local folders and populate titles
     */
    fun scanLocalFolders() {
        screenModelScope.launch(Dispatchers.IO) {
            mutableState.update { it.copy(state = AutoImportState.State.SCANNING) }
            try {
                val localDirs = scanLocalSource.await()
                // Extract manga titles from paths like "downloads/E-Hentai (ZH)/MangaName"
                val titles = localDirs.map { it.substringAfterLast('/') }.distinct()
                mutableState.update { 
                    it.copy(
                        titlesText = titles.joinToString("\n"),
                        state = AutoImportState.State.INPUT,
                        scannedCount = titles.size,
                    )
                }
            } catch (e: Exception) {
                logcat(LogPriority.ERROR, e) { "Failed to scan local folders" }
                mutableState.update { 
                    it.copy(
                        state = AutoImportState.State.INPUT,
                        scanError = e.message ?: "Unknown error",
                    )
                }
            }
        }
    }

    fun updateTitles(text: String) {
        mutableState.update { it.copy(titlesText = text) }
    }

    /**
     * One-click auto import: scan folders → extract titles → import in background
     * Fully automated, no user confirmation needed
     */
    fun startAutoImport(context: Context) {
        screenModelScope.launch(Dispatchers.IO + handler) {
            throttleManager.resetThrottle()
            val notificationHelper = ImportNotificationHelper(context)
            
            // Step 1: Scan local folders
            mutableState.update { it.copy(state = AutoImportState.State.SCANNING) }
            val localDirs = try {
                scanLocalSource.await()
            } catch (e: Exception) {
                logcat(LogPriority.ERROR, e) { "Failed to scan local folders" }
                notificationHelper.showImportError("Auto Import", "Scan failed: ${e.message}")
                mutableState.update { it.copy(state = AutoImportState.State.INPUT, scanError = e.message) }
                return@launch
            }
            
            // Step 2: Extract titles from paths
            val titles = localDirs.map { extractTitleFromPath(it) }.distinct()
            
            if (titles.isEmpty()) {
                notificationHelper.showImportError("Auto Import", "No local manga folders found")
                mutableState.update { it.copy(state = AutoImportState.State.INPUT) }
                return@launch
            }
            
            // Step 3: Start background import
            mutableState.update { state ->
                state.copy(
                    progress = 0,
                    progressTotal = titles.size,
                    state = AutoImportState.State.PROGRESS,
                    events = emptyList(),
                    summary = null,
                    isBackgroundRunning = true,
                )
            }
            
            // Show start notification
            notificationHelper.showAutoImportStart(titles.size)
            
            // Perform import
            performImport(titles, context, background = true, notificationHelper = notificationHelper)
        }
    }

    /**
     * Extract clean title from path like "downloads/E-Hentai (ZH)/MangaName"
     */
    private fun extractTitleFromPath(path: String): String {
        return path
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .trim()
    }

    private val handler = CoroutineExceptionHandler { _, throwable ->
        if (throwable !is CancellationException) {
            logcat(LogPriority.ERROR, throwable)
        }
    }

    /**
     * Get default category ID for imported manga
     */
    private suspend fun getDefaultCategoryId(): Long? {
        return try {
            val defaultCategoryId = libraryPreferences.defaultCategory().get()
            if (defaultCategoryId >= 0) {
                defaultCategoryId.toLong()
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    fun startImport(context: Context, background: Boolean = false) {
        val titles = parseTitles(state.value.titlesText)
        if (titles.isEmpty()) {
            mutableState.update { it.copy(dialog = AutoImportDialog.NoTitlesSpecified) }
            return
        }

        val sources = sourceManager.getVisibleCatalogueSources()
        if (sources.isEmpty()) {
            mutableState.update { it.copy(dialog = AutoImportDialog.NoSourcesEnabled) }
            return
        }

        // KMK -->: If background mode, don't show progress UI
        if (background) {
            mutableState.update { state ->
                state.copy(
                    progress = 0,
                    progressTotal = titles.size,
                    state = AutoImportState.State.INPUT,
                    events = emptyList(),
                    summary = null,
                    isBackgroundRunning = true,
                )
            }
        } else {
            mutableState.update { state ->
                state.copy(
                    progress = 0,
                    progressTotal = titles.size,
                    state = AutoImportState.State.PROGRESS,
                    events = emptyList(),
                    summary = null,
                )
            }
        }
        // KMK <--

        screenModelScope.launch(Dispatchers.IO + handler) {
            throttleManager.resetThrottle()
            performImport(titles, context, background, null)
        }
    }

    /**
     * Perform import with adaptive concurrency and progress notifications
     */
    private suspend fun performImport(
        titles: List<String>,
        context: Context,
        background: Boolean,
        notificationHelper: ImportNotificationHelper?,
    ) {
        val imported = mutableListOf<String>()
        val failed = mutableListOf<String>()
        val errors = mutableListOf<String>()
        val defaultCategoryId = getDefaultCategoryId()
        val sources = sourceManager.getVisibleCatalogueSources()
        
        if (sources.isEmpty()) {
            logcat(LogPriority.ERROR) { "No sources enabled for import" }
            return
        }

        // KMK -->: Adaptive concurrency based on total count
        val concurrentLimit = calculateAdaptiveConcurrency(titles.size)
        val semaphore = Semaphore(concurrentLimit)
        logcat(LogPriority.INFO) { "Starting import with adaptive concurrency: $concurrentLimit (total: ${titles.size})" }
        
        // Process titles concurrently
        coroutineScope {
            val deferredList = titles.mapIndexed { index, title ->
                async {
                    semaphore.acquire()
                    try {
                        ensureActive()
                        val result = withIOContext {
                            processTitle(title, sources, context, defaultCategoryId)
                        }
                        val message = when (result) {
                            is AutoImportResult.Imported -> "✓ ${result.mangaTitle}"
                            is AutoImportResult.NoMatch -> "✗ $title (no match)"
                            is AutoImportResult.Error -> "✗ $title (${result.message})"
                        }
                        Triple<Int, AutoImportResult, String>(index, result, message)
                    } finally {
                        semaphore.release()
                    }
                }
            }
            deferredList.awaitAll().forEach { item ->
                val (index, result, message) = item
                when (result) {
                    is AutoImportResult.Imported -> imported.add(result.title)
                    is AutoImportResult.NoMatch -> failed.add(result.title)
                    is AutoImportResult.Error -> errors.add("${result.title}: ${result.message}")
                }
                // KMK -->: Only update UI if not in background mode
                if (!background) {
                    mutableState.update { state ->
                        state.copy(
                            progress = index + 1,
                            events = state.events + message,
                        )
                    }
                }
                // KMK -->: Update notification every 10 items in background mode
                if (background && notificationHelper != null && (index + 1) % 10 == 0) {
                    notificationHelper.showAutoImportProgress(
                        current = index + 1,
                        total = titles.size,
                        imported = imported.size,
                        failed = failed.size,
                    )
                }
                // KMK <--
            }
        }
        // KMK <--

        val summary = AutoImportSummary(
            importedCount = imported.size,
            failedCount = failed.size,
            errorCount = errors.size,
            failedTitles = failed,
            errorMessages = errors,
        )
        
        // KMK -->: If background mode, save summary and show notification
        if (background) {
            mutableState.update { state ->
                state.copy(
                    isBackgroundRunning = false,
                    backgroundSummary = summary,
                )
            }
            // Show completion notification
            notificationHelper?.showAutoImportComplete(
                summary.importedCount,
                summary.failedCount,
                summary.errorCount
            )
            logcat(LogPriority.INFO) { "Background import completed: ${summary.importedCount} imported, ${summary.failedCount} failed" }
        } else {
            mutableState.update { state ->
                state.copy(summary = summary)
            }
        }
        // KMK <--
    }

    /**
     * Calculate adaptive concurrency based on total item count
     * - Small batch (< 20): 5 concurrent
     * - Medium batch (20-50): 3 concurrent
     * - Large batch (> 50): 2 concurrent (avoid overwhelming sources)
     */
    private fun calculateAdaptiveConcurrency(total: Int): Int {
        return when {
            total < 20 -> 5
            total < 50 -> 3
            else -> 2
        }
    }

    private suspend fun processTitle(
        title: String,
        sources: List<CatalogueSource>,
        context: Context,
        defaultCategoryId: Long? = null,
    ): AutoImportResult = supervisorScope {
        val searchTitle = title.trim()
        if (searchTitle.isBlank()) return@supervisorScope AutoImportResult.NoMatch(searchTitle)

        // Check if manga already exists in library
        val existingManga = getMangaByUrlAndSourceId.await(searchTitle, LOCAL_SOURCE_ID)
        if (existingManga != null) {
            if (existingManga.favorite) {
                return@supervisorScope AutoImportResult.Imported(searchTitle, existingManga.ogTitle, skipped = true)
            } else {
                // Mark as favorite and add to category
                updateManga.awaitUpdateFavorite(existingManga.id, true)
                if (defaultCategoryId != null) {
                    SetMangaCategories(Injekt.get()).await(existingManga.id, listOf(defaultCategoryId))
                }
                return@supervisorScope AutoImportResult.Imported(searchTitle, existingManga.ogTitle)
            }
        }

        // KMK -->: Try multiple search strategies
        // Strategy 1: Search with full title
        var best = searchWithStrategy(searchTitle, sources)
        
        // Strategy 2: If not found, try with keywords extracted from title
        if (best == null || best.second < SIMILARITY_THRESHOLD) {
            val keywords = extractKeywords(searchTitle)
            for (keyword in keywords) {
                best = searchWithStrategy(keyword, sources)
                if (best != null && best.second >= SIMILARITY_THRESHOLD) {
                    logcat(LogPriority.INFO) { "Found match with keyword '$keyword' for title '$searchTitle'" }
                    break
                }
            }
        }
        // KMK <--

        if (best == null || best.second < SIMILARITY_THRESHOLD) {
            return@supervisorScope AutoImportResult.NoMatch(searchTitle)
        }

        val (manga, similarity) = best
        try {
            addMangaToLibrary(manga, context, defaultCategoryId)
            return@supervisorScope AutoImportResult.Imported(searchTitle, manga.ogTitle, similarity = similarity)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            logcat(LogPriority.ERROR, e) { "AutoImport add failed for ${manga.ogTitle}" }
            return@supervisorScope AutoImportResult.Error(searchTitle, e.message ?: "Unknown error")
        }
    }

    // KMK -->: Search with a single query string
    private suspend fun searchWithStrategy(
        query: String,
        sources: List<CatalogueSource>,
    ): Pair<Manga, Double>? {
        if (query.isBlank()) return null
        
        return coroutineScope {
            val candidates = sources.map { source ->
                async {
                    try {
                        smartSearchEngine.deepSearch(source, query)
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        logcat(LogPriority.WARN, e) { "Search failed for source ${source.name} with query '$query'" }
                        null
                    }
                }
            }.mapNotNull { it.await() }

            candidates
                .map { manga -> manga to normalizedLevenshtein.similarity(query, manga.ogTitle) }
                .maxByOrNull { it.second }
        }
    }

    /**
     * Extract keywords from title for fallback search.
     * Priority:
     * 1. Text in square brackets [] - usually author/artist
     * 2. First 10 characters of main title
     * 3. Text in parentheses () - usually subtitle (optional)
     */
    internal fun extractKeywords(title: String): List<String> {
        val keywords = mutableListOf<String>()
        
        // Extract text in square brackets [] - usually author/artist
        val squareBracketRegex = Regex("""\[([^\]]+)\]""")
        squareBracketRegex.findAll(title).forEach { match ->
            val keyword = match.groupValues[1].trim()
            if (keyword.length >= 2) {
                keywords.add(keyword)
            }
        }
        
        // Extract first 10 characters of main title (remove brackets first)
        val mainTitle = title
            .replace(squareBracketRegex, "")
            .replace(Regex("""\([^)]*\)"""), "")
            .trim()
        if (mainTitle.length >= 5) {
            // Take first 10 chars or until first space
            val firstPart = mainTitle.take(10).split(' ').firstOrNull()
            if (!firstPart.isNullOrBlank() && firstPart.length >= 3) {
                keywords.add(firstPart)
            }
            // Also add the first 10 chars as a whole
            if (mainTitle.length >= 10) {
                keywords.add(mainTitle.take(10).trim())
            }
        }
        
        // Extract text in parentheses () - usually subtitle
        val parenRegex = Regex("""\(([^)]+)\)""")
        parenRegex.findAll(title).forEach { match ->
            val keyword = match.groupValues[1].trim()
            if (keyword.length >= 3 && keyword.length <= 20) {
                keywords.add(keyword)
            }
        }
        
        return keywords.distinct()
    }
    // KMK <--

    private suspend fun addMangaToLibrary(
        manga: Manga,
        context: Context,
        defaultCategoryId: Long? = null,
    ) = withContext(Dispatchers.IO) {
        val source = sourceManager.get(manga.source) as? CatalogueSource ?: return@withContext
        var localManga = getManga.await(manga.id) ?: networkToLocalManga(manga)
        try {
            val newManga = source.getMangaDetails(localManga.toSManga())
            updateManga.awaitUpdateFromSource(localManga, newManga, true)
            localManga = getManga.await(localManga.id)!!
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            // Continue with existing details
        }
        val chapters = if (source is EHentai) {
            source.getChapterList(localManga.toSManga(), throttleManager::throttle)
        } else {
            source.getChapterList(localManga.toSManga())
        }
        if (chapters.isNotEmpty()) {
            syncChaptersWithSource.await(chapters, localManga, source)
        }
        updateManga.awaitUpdateFavorite(localManga.id, true)
        
        // Add to default category if specified
        if (defaultCategoryId != null) {
            SetMangaCategories(Injekt.get()).await(localManga.id, listOf(defaultCategoryId))
        }
    }

    internal fun parseTitles(text: String): List<String> {
        return text
            .split("\n", ",")
            .map { it.trimOrNull() }
            .filterNotNull()
            .distinct()
    }

    fun finish() {
        mutableState.update {
            it.copy(
                progressTotal = 0,
                progress = 0,
                titlesText = it.titlesText,
                state = AutoImportState.State.INPUT,
                events = emptyList(),
                summary = null,
            )
        }
    }

    fun dismissDialog() {
        mutableState.update { it.copy(dialog = null) }
    }

    sealed class AutoImportDialog {
        data object NoTitlesSpecified : AutoImportDialog()
        data object NoSourcesEnabled : AutoImportDialog()
    }

    sealed class AutoImportResult {
        data class Imported(
            val title: String,
            val mangaTitle: String,
            val skipped: Boolean = false,
            val similarity: Double? = null,
        ) : AutoImportResult()
        data class NoMatch(val title: String) : AutoImportResult()
        data class Error(val title: String, val message: String) : AutoImportResult()
    }

    companion object {
        private const val SIMILARITY_THRESHOLD = 0.4
        private const val LOCAL_SOURCE_ID = 0L
        // KMK -->: Limit concurrent requests to avoid overwhelming sources
        private const val CONCURRENT_LIMIT = 3
    }
}

data class AutoImportState(
    val titlesText: String = "",
    val progressTotal: Int = 0,
    val progress: Int = 0,
    val state: AutoImportState.State = AutoImportState.State.INPUT,
    val events: List<String> = emptyList(),
    val summary: AutoImportSummary? = null,
    val dialog: AutoImportScreenModel.AutoImportDialog? = null,
    val scannedCount: Int = 0,
    val scanError: String? = null,
    // KMK -->: Background import state
    val isBackgroundRunning: Boolean = false,
    val backgroundSummary: AutoImportSummary? = null,
    // KMK <--
) {
    enum class State {
        INPUT,
        SCANNING,
        PROGRESS,
    }
}

data class AutoImportSummary(
    val importedCount: Int,
    val failedCount: Int,
    val errorCount: Int,
    val failedTitles: List<String>,
    val errorMessages: List<String>,
)
