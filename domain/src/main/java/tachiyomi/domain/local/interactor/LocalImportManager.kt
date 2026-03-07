package tachiyomi.domain.local.interactor

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import tachiyomi.domain.category.interactor.GetCategories
import tachiyomi.domain.category.interactor.SetMangaCategories
import tachiyomi.domain.library.service.LibraryPreferences
import tachiyomi.domain.manga.interactor.GetMangaByUrlAndSourceId
import tachiyomi.domain.manga.model.Manga
import tachiyomi.domain.manga.model.MangaUpdate
import tachiyomi.domain.manga.repository.MangaRepository

/**
 * Service for importing local manga from the Local Source directory into the library.
 * Scans the local source folder, creates manga entries, marks them as favorites,
 * and optionally adds them to the default category.
 */
class LocalImportManager(
    private val getMangaByUrlAndSourceId: GetMangaByUrlAndSourceId,
    private val getCategories: GetCategories,
    private val setMangaCategories: SetMangaCategories,
    private val mangaRepository: MangaRepository,
    private val libraryPreferences: LibraryPreferences,
    private val scanLocalSource: ScanLocalSource,
    private val getLocalMangaDetails: GetLocalMangaDetails,
) {

    private val _importState = MutableStateFlow<ImportState>(ImportState.Idle)
    val importState: StateFlow<ImportState> = _importState.asStateFlow()

    /**
     * Scan and import all manga from the local source directory.
     * @param addToDefaultCategory If true, adds imported manga to the default category (if set)
     */
    suspend fun importAll(addToDefaultCategory: Boolean = true) {
        try {
            _importState.value = ImportState.Scanning

            // Get all manga directories
            val mangaDirs = scanLocalSource.await()

            if (mangaDirs.isEmpty()) {
                _importState.value = ImportState.Completed(0, 0, 0, "No local manga folders found")
                return
            }

            _importState.value = ImportState.Importing(0, mangaDirs.size)

            var importedCount = 0
            var skippedCount = 0
            var errorCount = 0

            val defaultCategoryId = if (addToDefaultCategory) {
                getDefaultCategoryId()
            } else {
                null
            }

            mangaDirs.forEachIndexed { index, mangaDirName ->
                try {
                    // Check if manga already exists
                    val existingManga = getMangaByUrlAndSourceId.await(mangaDirName, LOCAL_SOURCE_ID)
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
                            importedCount++
                        } else {
                            skippedCount++
                        }
                        _importState.value = ImportState.Importing(index + 1, mangaDirs.size, "Skipped: $mangaDirName")
                        return@forEachIndexed
                    }

                    // Get manga details from local source
                    val mangaDetails = getLocalMangaDetails.await(mangaDirName)

                    // Create manga entry
                    val manga = Manga.create().copy(
                        url = mangaDirName,
                        ogTitle = mangaDetails.title,
                        ogAuthor = mangaDetails.author,
                        ogArtist = mangaDetails.artist,
                        ogDescription = mangaDetails.description,
                        ogGenre = mangaDetails.genre?.split(", ")?.filterNot { it.isNullOrBlank() },
                        ogStatus = mangaDetails.status,
                        ogThumbnailUrl = mangaDetails.thumbnail_url,
                        source = LOCAL_SOURCE_ID,
                        favorite = true,
                        dateAdded = System.currentTimeMillis(),
                        initialized = true,
                    )

                    // Insert manga into database
                    val insertedManga = insertManga(manga)

                    // Add to default category if specified
                    if (defaultCategoryId != null) {
                        setMangaCategories.await(insertedManga.id, listOf(defaultCategoryId))
                    }

                    importedCount++
                    _importState.value = ImportState.Importing(
                        index + 1,
                        mangaDirs.size,
                        "Imported: $mangaDirName"
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

            _importState.value = ImportState.Completed(importedCount, skippedCount, errorCount)
        } catch (e: Exception) {
            _importState.value = ImportState.Error(e.message ?: "Unknown error occurred")
        }
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
