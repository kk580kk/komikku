package tachiyomi.domain.local.interactor

import io.kotest.matchers.shouldBe
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import tachiyomi.domain.category.interactor.GetCategories
import tachiyomi.domain.category.interactor.SetMangaCategories
import tachiyomi.domain.library.service.LibraryPreferences
import tachiyomi.domain.manga.interactor.GetMangaByUrlAndSourceId
import tachiyomi.domain.manga.model.Manga
import tachiyomi.domain.manga.repository.MangaRepository
import tachiyomi.core.common.preference.Preference
import tachiyomi.domain.local.repository.LocalSourceRepository

/**
 * Unit tests for [LocalImportManager] local import (foreground) and auto import (background) flows.
 */
class LocalImportManagerTest {

    private lateinit var manager: LocalImportManager
    private lateinit var getMangaByUrlAndSourceId: GetMangaByUrlAndSourceId
    private lateinit var getCategories: GetCategories
    private lateinit var setMangaCategories: SetMangaCategories
    private lateinit var mangaRepository: MangaRepository
    private lateinit var libraryPreferences: LibraryPreferences
    private lateinit var scanLocalSource: ScanLocalSource
    private lateinit var getLocalMangaDetails: GetLocalMangaDetails
    private lateinit var localSourceRepository: LocalSourceRepository

    private lateinit var defaultCategoryPreference: Preference<Int>

    @BeforeEach
    fun setUp() {
        getMangaByUrlAndSourceId = mockk()
        getCategories = mockk(relaxed = true)
        setMangaCategories = mockk(relaxed = true)
        mangaRepository = mockk()
        libraryPreferences = mockk()
        scanLocalSource = mockk()
        getLocalMangaDetails = mockk()
        localSourceRepository = mockk(relaxed = true)

        defaultCategoryPreference = mockk()
        every { libraryPreferences.defaultCategory() } returns defaultCategoryPreference
        every { defaultCategoryPreference.get() } returns -1

        manager = LocalImportManager(
            getMangaByUrlAndSourceId = getMangaByUrlAndSourceId,
            getCategories = getCategories,
            setMangaCategories = setMangaCategories,
            mangaRepository = mangaRepository,
            libraryPreferences = libraryPreferences,
            scanLocalSource = scanLocalSource,
            getLocalMangaDetails = getLocalMangaDetails,
            localSourceRepository = localSourceRepository,
        )
    }

    // ---------- 本地导入 (Local import) ----------

    @Test
    fun `local import - when no manga dirs then state is Completed with zero counts`() = runTest {
        coEvery { scanLocalSource.await() } returns emptyList()

        manager.importAll(addToDefaultCategory = true, background = false)

        val state = manager.importState.value
        state shouldBe LocalImportManager.ImportState.Completed(0, 0, 0, "No local manga folders found")
    }

    @Test
    fun `local import - when one new manga dir then imported and Completed 1 0 0`() = runTest {
        val dirs = listOf("MangaOne")
        coEvery { scanLocalSource.await() } returns dirs
        coEvery { getMangaByUrlAndSourceId.await("MangaOne", LocalImportManager.LOCAL_SOURCE_ID) } returns null
        coEvery { getLocalMangaDetails.await("MangaOne") } returns LocalMangaDetails(
            title = "Title",
            author = "Author",
            artist = null,
            description = null,
            genre = null,
            status = 0L,
            thumbnail_url = null,
        )
        val insertedManga = Manga.create().copy(id = 1L, url = "MangaOne", ogTitle = "Title")
        coEvery { mangaRepository.insertNetworkManga(any()) } returns listOf(insertedManga)

        manager.importAll(addToDefaultCategory = false, background = false)

        val state = manager.importState.value
        (state as? LocalImportManager.ImportState.Completed)?.let {
            it.imported shouldBe 1
            it.skipped shouldBe 0
            it.errorCount shouldBe 0
        } ?: error("Expected Completed, got $state")
    }

    @Test
    fun `local import - when manga already exists and favorite then skipped`() = runTest {
        val dirs = listOf("ExistingManga")
        val existingManga = Manga.create().copy(id = 42L, url = "ExistingManga", favorite = true)
        coEvery { scanLocalSource.await() } returns dirs
        coEvery { getMangaByUrlAndSourceId.await("ExistingManga", LocalImportManager.LOCAL_SOURCE_ID) } returns existingManga

        manager.importAll(addToDefaultCategory = false, background = false)

        val state = manager.importState.value
        (state as? LocalImportManager.ImportState.Completed)?.let {
            it.imported shouldBe 0
            it.skipped shouldBe 1
            it.errorCount shouldBe 0
        } ?: error("Expected Completed, got $state")
        coVerify(exactly = 0) { mangaRepository.insertNetworkManga(any()) }
    }

    @Test
    fun `local import - when addToDefaultCategory and default category set then setMangaCategories called`() = runTest {
        every { defaultCategoryPreference.get() } returns 5
        val dirs = listOf("NewManga")
        coEvery { scanLocalSource.await() } returns dirs
        coEvery { getMangaByUrlAndSourceId.await("NewManga", LocalImportManager.LOCAL_SOURCE_ID) } returns null
        coEvery { getLocalMangaDetails.await("NewManga") } returns LocalMangaDetails(
            title = "T",
            author = null,
            artist = null,
            description = null,
            genre = null,
            status = 0L,
            thumbnail_url = null,
        )
        val insertedManga = Manga.create().copy(id = 10L, url = "NewManga")
        coEvery { mangaRepository.insertNetworkManga(any()) } returns listOf(insertedManga)

        manager.importAll(addToDefaultCategory = true, background = false)

        coVerify { setMangaCategories.await(10L, listOf(5L)) }
    }

    @Test
    fun `local import - reset sets state to Idle`() = runTest {
        coEvery { scanLocalSource.await() } returns emptyList()
        manager.importAll(addToDefaultCategory = false, background = false)
        manager.importState.value shouldBe LocalImportManager.ImportState.Completed(0, 0, 0, "No local manga folders found")

        manager.reset()
        manager.importState.value shouldBe LocalImportManager.ImportState.Idle
    }

    // ---------- 自动导入 (Auto import / background) ----------

    @Test
    fun `auto import background - when no manga dirs then Completed 0 0 0`() = runTest {
        coEvery { scanLocalSource.await() } returns emptyList()

        manager.importAll(addToDefaultCategory = true, background = true)

        val state = manager.importState.value
        state shouldBe LocalImportManager.ImportState.Completed(0, 0, 0, "No local manga folders found")
    }

    @Test
    fun `auto import background - when multiple dirs then all processed and counts correct`() = runTest {
        val dirs = listOf("Dir1", "Dir2", "Dir3")
        coEvery { scanLocalSource.await() } returns dirs
        coEvery { getMangaByUrlAndSourceId.await(any(), LocalImportManager.LOCAL_SOURCE_ID) } returns null
        coEvery { getLocalMangaDetails.await(any()) } returns LocalMangaDetails(
            title = "T",
            author = null,
            artist = null,
            description = null,
            genre = null,
            status = 0L,
            thumbnail_url = null,
        )
        coEvery { mangaRepository.insertNetworkManga(any()) } answers {
            val list = firstArg<List<Manga>>()
            list.mapIndexed { index, m -> m.copy(id = (index + 1).toLong()) }
        }

        manager.importAll(addToDefaultCategory = false, background = true)

        val state = manager.importState.value
        (state as? LocalImportManager.ImportState.Completed)?.let {
            it.imported shouldBe 3
            it.skipped shouldBe 0
            it.errorCount shouldBe 0
        } ?: error("Expected Completed, got $state")
    }

    @Test
    fun `auto import background - when one dir fails then errorCount incremented`() = runTest {
        val dirs = listOf("Good", "Bad")
        coEvery { scanLocalSource.await() } returns dirs
        coEvery { getMangaByUrlAndSourceId.await("Good", LocalImportManager.LOCAL_SOURCE_ID) } returns null
        coEvery { getMangaByUrlAndSourceId.await("Bad", LocalImportManager.LOCAL_SOURCE_ID) } returns null
        coEvery { getLocalMangaDetails.await("Good") } returns LocalMangaDetails(
            title = "T", author = null, artist = null, description = null, genre = null, status = 0L, thumbnail_url = null,
        )
        coEvery { getLocalMangaDetails.await("Bad") } throws RuntimeException("scan error")
        coEvery { mangaRepository.insertNetworkManga(any()) } returns listOf(Manga.create().copy(id = 1L))

        manager.importAll(addToDefaultCategory = false, background = true)

        val state = manager.importState.value
        (state as? LocalImportManager.ImportState.Completed)?.let {
            it.imported shouldBe 1
            it.skipped shouldBe 0
            it.errorCount shouldBe 1
        } ?: error("Expected Completed, got $state")
    }
}
