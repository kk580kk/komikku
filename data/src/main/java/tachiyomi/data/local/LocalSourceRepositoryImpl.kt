package tachiyomi.data.local

import android.content.Context
import eu.kanade.tachiyomi.source.model.SManga
import tachiyomi.domain.local.interactor.LocalMangaDetails
import tachiyomi.domain.local.repository.LocalSourceRepository
import tachiyomi.source.local.LocalSource
import tachiyomi.source.local.io.LocalSourceFileSystem

/**
 * Implementation of LocalSourceRepository.
 */
class LocalSourceRepositoryImpl(
    private val context: Context,
    private val localSourceFileSystem: LocalSourceFileSystem,
    private val localSource: LocalSource,
) : LocalSourceRepository {

    /**
     * Scan the local source directory and return a list of manga directory names.
     */
    override suspend fun scanLocalSourceDirectory(): List<String> {
        return localSourceFileSystem.getFilesInBaseDirectory()
            .filter { it.isDirectory && !it.name.orEmpty().startsWith('.') }
            .mapNotNull { it.name }
            .distinct()
    }

    /**
     * Get manga details from a local manga directory.
     */
    override suspend fun getMangaDetails(mangaDirName: String): LocalMangaDetails {
        val manga = SManga.create().apply {
            title = mangaDirName
            url = mangaDirName
        }

        try {
            localSource.getMangaDetails(manga)
        } catch (e: Exception) {
            // Continue with basic info if metadata loading fails
        }

        return LocalMangaDetails(
            title = manga.title,
            author = manga.author,
            artist = manga.artist,
            description = manga.description,
            genre = manga.genre,
            status = manga.status.toLong(),
            thumbnail_url = manga.thumbnail_url,
        )
    }
}
