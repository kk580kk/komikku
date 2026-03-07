package tachiyomi.domain.local.repository

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
}
