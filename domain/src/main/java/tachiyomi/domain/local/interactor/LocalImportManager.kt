package tachiyomi.domain.local.interactor

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import tachiyomi.domain.category.interactor.GetCategories
import tachiyomi.domain.category.interactor.SetMangaCategories
import tachiyomi.domain.library.service.LibraryPreferences
import tachiyomi.domain.local.repository.LocalSourceRepository
import tachiyomi.domain.manga.interactor.GetMangaByUrlAndSourceId
import tachiyomi.domain.manga.model.Manga
import tachiyomi.domain.manga.model.MangaUpdate
import tachiyomi.domain.manga.repository.MangaRepository
import exh.source.EHENTAI_EXT_SOURCES
import exh.source.EXHENTAI_EXT_SOURCES
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Semaphore
import logcat.LogPriority
import tachiyomi.core.common.util.system.logcat

/**
 * Service for importing local manga from the downloads directory into the library.
 * Scans the downloads folder (including subdirectories like downloads/E-Hentai, etc.),
 * identifies the source based on directory structure, and imports manga with correct source ID.
 */
class LocalImportManager(
    private val getMangaByUrlAndSourceId: GetMangaByUrlAndSourceId,
    private val getCategories: GetCategories,
    private val setMangaCategories: SetMangaCategories,
    private val mangaRepository: MangaRepository,
    private val libraryPreferences: LibraryPreferences,
    private val scanLocalSource: ScanLocalSource,
    private val getLocalMangaDetails: GetLocalMangaDetails,
    private val localSourceRepository: LocalSourceRepository,
) {

    /**
     * Map directory names to source IDs
     */
    private val directoryToSourceMap = mapOf(
        "E-Hentai (ZH)" to 4678440076103929247L,
        "E-Hentai (ALL)" to 1713178126840476467L,
        "E-Hentai (All)" to 1713178126840476467L,
        "ExHentai (ZH)" to 1394807835077780591L,
        "ExHentai (ALL)" to 6225928719850211219L,
        "ExHentai (All)" to 6225928719850211219L,
    )

    /**
     * Extract source ID from directory path like "downloads/E-Hentai (ZH)/MangaName"
     */
    private fun getSourceIdFromPath(path: String): Long? {
        val parts = path.split('/')
        if (parts.size < 2) return null
        
        val categoryName = parts[1] // e.g., "E-Hentai (ZH)"
        return directoryToSourceMap[categoryName]
    }

    private val _importState = MutableStateFlow<ImportState>(ImportState.Idle)
    val importState: StateFlow<ImportState> = _importState.asStateFlow()

    /**
     * Scan and import all manga from the local source directory.
     * @param addToDefaultCategory If true, adds imported manga to the default category (if set)
     * @param background If true, runs in background without updating UI state frequently
     */
    suspend fun importAll(addToDefaultCategory: Boolean = true, background: Boolean = false) {
        try {
            _importState.value = ImportState.Scanning

            // Get all manga directories
            val mangaDirs = scanLocalSource.await()

            if (mangaDirs.isEmpty()) {
                val message = "No local manga folders found"
                _importState.value = ImportState.Completed(0, 0, 0, message)
                return
            }

            // KMK -->: Don't update UI during scanning if background mode
            if (!background) {
                _importState.value = ImportState.Importing(0, mangaDirs.size)
            }

            var importedCount = 0
            var skippedCount = 0
            var errorCount = 0

            val defaultCategoryId = if (addToDefaultCategory) {
                getDefaultCategoryId()
            } else {
                null
            }

            // KMK -->: Use concurrent processing with semaphore for background mode
            val semaphore = Semaphore(CONCURRENT_LIMIT)
            
            if (background) {
                // Background mode: process concurrently
                coroutineScope {
                    val scope = this
                    val results = mangaDirs.mapIndexed { index, mangaDirName ->
                        scope.async {
                            semaphore.acquire()
                            try {
                                processMangaImport(mangaDirName, LOCAL_SOURCE_ID, defaultCategoryId)
                            } finally {
                                semaphore.release()
                            }
                        }
                    }.awaitAll()
                    
                    // Count results
                    results.forEach { result ->
                        when (result) {
                            is ImportResult.Imported -> importedCount++
                            is ImportResult.Skipped -> skippedCount++
                            is ImportResult.Error -> errorCount++
                        }
                    }
                }
            } else {
                // Foreground mode: process sequentially with UI updates
                mangaDirs.forEachIndexed { index, mangaDirName ->
                    try {
                        val result = processMangaImport(mangaDirName, LOCAL_SOURCE_ID, defaultCategoryId)
                        when (result) {
                            is ImportResult.Imported -> importedCount++
                            is ImportResult.Skipped -> skippedCount++
                            is ImportResult.Error -> errorCount++
                        }
                        _importState.value = ImportState.Importing(
                            index + 1,
                            mangaDirs.size,
                            when (result) {
                                is ImportResult.Imported -> "Imported: $mangaDirName"
                                is ImportResult.Skipped -> "Skipped: $mangaDirName"
                                is ImportResult.Error -> "Error: $mangaDirName - ${result.message}"
                            }
                        )
                    } catch (e: Exception) {
                        errorCount++
                        _importState.value = ImportState.Importing(
                            index + 1,
                            mangaDirs.size,
                            "Error: $mangaDirName - ${e.message}"
                        )
                    }
                }
            }
            // KMK <--

            _importState.value = ImportState.Completed(importedCount, skippedCount, errorCount)
            
            // KMK -->: Log completion for background import (notification handled by caller)
            if (background) {
                logcat(LogPriority.INFO) { "Background local import completed: $importedCount imported, $skippedCount skipped, $errorCount errors" }
            }
            // KMK <--
        } catch (e: Exception) {
            logcat(LogPriority.ERROR, e) { "Local import failed" }
            _importState.value = ImportState.Error(e.message ?: "Unknown error occurred")
        }
    }

    // KMK -->: Helper method to process single manga import
    private suspend fun processMangaImport(
        mangaDirName: String,
        sourceId: Long,
        defaultCategoryId: Long?,
    ): ImportResult {
        return try {
            // Check if manga already exists
            val existingManga = getMangaByUrlAndSourceId.await(mangaDirName, sourceId)
            if (existingManga != null) {
                // If not favorite, mark as favorite
                if (!existingManga.favorite) {
                    mangaRepository.update(
                        MangaUpdate(
                            id = existingManga.id,
                            favorite = true,
                        )
                    )
                    // Add to default category if specified
                    if (defaultCategoryId != null) {
                        setMangaCategories.await(existingManga.id, listOf(defaultCategoryId))
                    }
                    ImportResult.Skipped
                } else {
                    ImportResult.Skipped
                }
            } else {
                // Get manga details from local source
                val mangaDetails = getLocalMangaDetails.await(mangaDirName)

                // Extract cover from CBZ file if not available
                var thumbnailUrl = mangaDetails.thumbnail_url
                if (thumbnailUrl.isNullOrBlank()) {
                    thumbnailUrl = localSourceRepository.extractCoverFromArchive(mangaDirName)
                    // Wait a bit to ensure cover file is written
                    delay(100)
                }

                // Create manga entry with local source ID
                val manga = Manga.create().copy(
                    url = mangaDirName,
                    ogTitle = mangaDetails.title,
                    ogAuthor = mangaDetails.author,
                    ogArtist = mangaDetails.artist,
                    ogDescription = mangaDetails.description,
                    ogGenre = mangaDetails.genre?.split(", ")?.filterNot { it.isNullOrBlank() },
                    ogStatus = mangaDetails.status,
                    ogThumbnailUrl = thumbnailUrl,
                    source = sourceId,
                    favorite = true,
                    dateAdded = System.currentTimeMillis(),
                    initialized = true, // Mark as initialized to prevent re-fetching
                )

                // Insert manga into database
                val insertedManga = insertManga(manga)

                // Add to default category if specified
                if (defaultCategoryId != null) {
                    setMangaCategories.await(insertedManga.id, listOf(defaultCategoryId))
                }

                ImportResult.Imported
            }
        } catch (e: Exception) {
            logcat(LogPriority.WARN, e) { "Failed to import $mangaDirName" }
            ImportResult.Error(e.message ?: "Unknown error")
        }
    }

    // KMK -->: Import result sealed class
    private sealed class ImportResult {
        object Imported : ImportResult()
        object Skipped : ImportResult()
        data class Error(val message: String) : ImportResult()
    }

    /**
     * Insert manga into the database.
     */
    private suspend fun insertManga(manga: Manga): Manga {
        val inserted = mangaRepository.insertNetworkManga(listOf(manga))
        return inserted.firstOrNull() ?: throw Exception("Failed to insert manga")
    }

    /**
     * Get the default category ID, if one is set.
     * Returns null if no default category is configured.
     */
    private suspend fun getDefaultCategoryId(): Long? {
        return try {
            val defaultCategoryId = libraryPreferences.defaultCategory().get()
            // -1 means no default category, 0 means "Uncategorized"
            if (defaultCategoryId >= 0) {
                defaultCategoryId.toLong()
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Reset the import state to idle.
     */
    fun reset() {
        _importState.value = ImportState.Idle
    }

    /**
     * Import state sealed class representing different states of the import process.
     */
    sealed class ImportState {
        object Idle : ImportState()
        object Scanning : ImportState()
        data class Importing(
            val current: Int,
            val total: Int,
            val message: String = ""
        ) : ImportState()
        data class Completed(
            val imported: Int,
            val skipped: Int,
            val errorCount: Int,
            val message: String = ""
        ) : ImportState()
        data class Error(val message: String) : ImportState()
    }

    companion object {
        const val LOCAL_SOURCE_ID = 0L
        // KMK -->: Concurrent limit for background imports
        private const val CONCURRENT_LIMIT = 5 // Higher limit for local imports (no network)
    }
}

/**
 * Data class for holding manga details.
 */
data class LocalMangaDetails(
    val title: String,
    val author: String?,
    val artist: String?,
    val description: String?,
    val genre: String?,
    val status: Long,
    val thumbnail_url: String?,
)
