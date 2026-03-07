package tachiyomi.domain.local.interactor

import tachiyomi.domain.local.repository.LocalSourceRepository

/**
 * Interactor for scanning the local source directory.
 */
class ScanLocalSource(
    private val localSourceRepository: LocalSourceRepository,
) {
    suspend fun await(): List<String> {
        return localSourceRepository.scanLocalSourceDirectory()
    }
}
