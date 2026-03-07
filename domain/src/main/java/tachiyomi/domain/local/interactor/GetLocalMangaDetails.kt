package tachiyomi.domain.local.interactor

import tachiyomi.domain.local.repository.LocalSourceRepository

/**
 * Interactor for getting manga details from the local source.
 */
class GetLocalMangaDetails(
    private val localSourceRepository: LocalSourceRepository,
) {
    suspend fun await(mangaDirName: String): LocalMangaDetails {
        return localSourceRepository.getMangaDetails(mangaDirName)
    }
}
