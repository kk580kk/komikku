package tachiyomi.data.local

import android.content.Context
import com.hippo.unifile.UniFile
import eu.kanade.tachiyomi.source.model.SManga
import logcat.LogPriority
import tachiyomi.core.common.storage.extension
import tachiyomi.core.common.util.system.ImageUtil
import tachiyomi.core.common.util.system.logcat
import tachiyomi.domain.local.interactor.LocalMangaDetails
import tachiyomi.domain.local.repository.LocalSourceRepository
import tachiyomi.source.local.LocalSource
import tachiyomi.source.local.io.Archive
import tachiyomi.source.local.io.LocalSourceFileSystem
import java.io.File

/**
 * Implementation of LocalSourceRepository.
 */
class LocalSourceRepositoryImpl(
    private val context: Context,
    private val localSourceFileSystem: LocalSourceFileSystem,
    private val localSource: LocalSource,
) : LocalSourceRepository {

    /**
     * Scan the downloads directory and return a list of manga directory names.
     * Scans subdirectories like downloads/E-Hentai (ZH), downloads/E-Hentai (ALL), downloads/ExHentai (ZH), etc.
     */
    override suspend fun scanLocalSourceDirectory(): List<String> {
        val mangaDirs = mutableListOf<String>()
        
        // Scan downloads directory and its subdirectories
        val downloadDirs = localSourceFileSystem.getFilesInDownloadsDirectory()
            .filter { it.isDirectory && !it.name.orEmpty().startsWith('.') }
            .flatMap { categoryDir ->
                // Scan each category subdirectory (e.g., E-Hentai (ZH), ExHentai (ZH), etc.)
                categoryDir.listFiles().orEmpty()
                    .filter { it.isDirectory && !it.name.orEmpty().startsWith('.') }
                    .mapNotNull { mangaDir ->
                        // Return path as "downloads/category/mangaName" format
                        "downloads/${categoryDir.name}/${mangaDir.name}"
                    }
            }
        mangaDirs.addAll(downloadDirs)
        
        return mangaDirs.distinct()
    }

    /**
     * Get manga details from a local manga directory.
     * Supports both direct directories (e.g., "MangaName") and nested paths (e.g., "downloads/E-Hentai/MangaName").
     */
    override suspend fun getMangaDetails(mangaDirName: String): LocalMangaDetails {
        val manga = SManga.create().apply {
            // Use the last part of the path as the title
            title = mangaDirName.substringAfterLast('/')
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

    override suspend fun getMangaDirectory(mangaDirName: String): UniFile? {
        // Handle nested paths like "downloads/E-Hentai (ZH)/MangaName"
        val pathParts = mangaDirName.split('/')
        
        return if (pathParts.size >= 3 && pathParts[0] == "downloads") {
            // Nested path: downloads/category/mangaName
            val categoryName = pathParts[1]
            val mangaName = pathParts.drop(2).joinToString("/")
            val downloadDir = localSourceFileSystem.getFilesInDownloadsDirectory()
                .find { it.name == categoryName }
            downloadDir?.listFiles()?.find { it.name == mangaName }
        } else {
            // Direct path: just mangaName
            localSourceFileSystem.getFilesInBaseDirectory()
                .find { it.name == mangaDirName }
        }
    }

    override suspend fun extractCoverFromArchive(mangaDirName: String): String? {
        // Extract first image from first CBZ/archive in manga directory as cover
        return localSource.extractCoverFromFirstArchive(mangaDirName)
    }
}
