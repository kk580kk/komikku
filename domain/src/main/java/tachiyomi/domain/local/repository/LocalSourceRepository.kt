package tachiyomi.domain.local.repository

import com.hippo.unifile.UniFile
import tachiyomi.domain.local.interactor.LocalMangaDetails

/**
 * Repository interface for local source operations.
 */
interface LocalSourceRepository {

    /**
     * Scan the local source directory and return a list of manga directory names.
     */
    suspend fun scanLocalSourceDirectory(): List<String>

    /**
     * Get manga details from a local manga directory.
     */
    suspend fun getMangaDetails(mangaDirName: String): LocalMangaDetails

    /**
     * Get the UniFile for a manga directory.
     */
    suspend fun getMangaDirectory(mangaDirName: String): UniFile?

    /**
     * Extract cover image from the first CBZ/archive file in the manga directory.
     * Returns the URI of the extracted cover image, or null if extraction fails.
     */
    suspend fun extractCoverFromArchive(mangaDirName: String): String?
}
