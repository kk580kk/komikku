package exh.ui.autoimport

import android.content.Context
import eu.kanade.domain.chapter.interactor.SyncChaptersWithSource
import eu.kanade.domain.manga.interactor.GetManga
import eu.kanade.domain.manga.interactor.GetMangaByUrlAndSourceId
import eu.kanade.domain.manga.interactor.NetworkToLocalManga
import eu.kanade.domain.manga.interactor.UpdateManga
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import tachiyomi.core.common.preference.Preference
import tachiyomi.domain.library.service.LibraryPreferences
import tachiyomi.domain.local.interactor.ScanLocalSource
import tachiyomi.domain.manga.model.Manga
import tachiyomi.domain.source.service.SourceManager

/**
 * 自动导入功能单元测试：
 * - 完整标题解析 (parseTitles)
 * - 关键词检索 (extractKeywords)
 * - 后台执行 (background import state)
 * - 多标题并发处理 (state / summary)
 */
class AutoImportScreenModelTest {

    private lateinit var model: AutoImportScreenModel
    private lateinit var sourceManager: SourceManager
    private lateinit var getManga: GetManga
    private lateinit var getMangaByUrlAndSourceId: GetMangaByUrlAndSourceId
    private lateinit var networkToLocalManga: NetworkToLocalManga
    private lateinit var updateManga: UpdateManga
    private lateinit var syncChaptersWithSource: SyncChaptersWithSource
    private lateinit var scanLocalSource: ScanLocalSource
    private lateinit var libraryPreferences: LibraryPreferences
    private lateinit var context: Context
    private lateinit var defaultCategoryPreference: Preference<Int>

    @BeforeEach
    fun setUp() {
        sourceManager = mockk(relaxed = true)
        getManga = mockk(relaxed = true)
        getMangaByUrlAndSourceId = mockk(relaxed = true)
        networkToLocalManga = mockk(relaxed = true)
        updateManga = mockk(relaxed = true)
        syncChaptersWithSource = mockk(relaxed = true)
        scanLocalSource = mockk(relaxed = true)
        libraryPreferences = mockk(relaxed = true)
        context = mockk(relaxed = true)
        defaultCategoryPreference = mockk(relaxed = true)
        every { libraryPreferences.defaultCategory() } returns defaultCategoryPreference
        every { defaultCategoryPreference.get() } returns -1

        model = AutoImportScreenModel(
            sourceManager = sourceManager,
            getManga = getManga,
            getMangaByUrlAndSourceId = getMangaByUrlAndSourceId,
            networkToLocalManga = networkToLocalManga,
            updateManga = updateManga,
            syncChaptersWithSource = syncChaptersWithSource,
            scanLocalSource = scanLocalSource,
            libraryPreferences = libraryPreferences,
        )
    }

    // ---------- 完整标题解析 (parseTitles) ----------

    @Test
    fun `parseTitles - empty string returns empty list`() {
        model.parseTitles("") shouldBe emptyList()
    }

    @Test
    fun `parseTitles - single line returns one title`() {
        model.parseTitles("One Title") shouldBe listOf("One Title")
    }

    @Test
    fun `parseTitles - newline separated returns distinct titles`() {
        model.parseTitles("A\nB\nC").shouldContainExactly("A", "B", "C")
    }

    @Test
    fun `parseTitles - comma separated returns distinct titles`() {
        model.parseTitles("A, B, C").shouldContainExactly("A", "B", "C")
    }

    @Test
    fun `parseTitles - mixed newline and comma with trim and distinct`() {
        val result = model.parseTitles("  X  \n Y , Z\nX ")
        result shouldBe listOf("X", "Y", "Z")
    }

    // ---------- 关键词检索 (extractKeywords) ----------

    @Test
    fun `extractKeywords - extracts text in square brackets`() {
        val keywords = model.extractKeywords("[Author Name] Some Title")
        keywords shouldBe listOf("Author Name")
    }

    @Test
    fun `extractKeywords - extracts multiple bracket keywords`() {
        val keywords = model.extractKeywords("[Artist] [Tag] Title Here")
        keywords shouldContain "Artist"
        keywords shouldContain "Tag"
    }

    @Test
    fun `extractKeywords - extracts first part of main title when long enough`() {
        val keywords = model.extractKeywords("Very Long Manga Title Here 2024")
        keywords.any { it.length in 3..10 } shouldBe true
    }

    @Test
    fun `extractKeywords - extracts text in parentheses`() {
        val keywords = model.extractKeywords("Title (Subtitle 2024)")
        keywords shouldContain "Subtitle 2024"
    }

    @Test
    fun `extractKeywords - short title returns empty or minimal keywords`() {
        val keywords = model.extractKeywords("Ab")
        keywords.size shouldBe 0
    }

    @Test
    fun `extractKeywords - full format returns distinct keywords`() {
        val keywords = model.extractKeywords("[Author] Main Title Part (Subtitle)")
        keywords shouldContain "Author"
        keywords shouldContain "Subtitle"
    }

    // ---------- 后台执行 (background import) ----------

    @Test
    fun `startImport with no titles shows NoTitlesSpecified dialog`() = runTest {
        every { sourceManager.getVisibleCatalogueSources() } returns emptyList()
        model.updateTitles("")
        model.startImport(context, background = false)

        model.state.value.dialog shouldBe AutoImportScreenModel.AutoImportDialog.NoTitlesSpecified
    }

    @Test
    fun `startImport with no sources shows NoSourcesEnabled dialog`() = runTest {
        every { sourceManager.getVisibleCatalogueSources() } returns emptyList()
        model.updateTitles("One Title")
        model.startImport(context, background = false)

        model.state.value.dialog shouldBe AutoImportScreenModel.AutoImportDialog.NoSourcesEnabled
    }

    @Test
    fun `startImport in background sets isBackgroundRunning and progressTotal`() = runTest {
        val mockSource = mockk<eu.kanade.tachiyomi.source.CatalogueSource>(relaxed = true)
        every { sourceManager.getVisibleCatalogueSources() } returns listOf(mockSource)
        model.updateTitles("ExistingManga")
        val existingManga = Manga.create().copy(
            id = 1L,
            url = "ExistingManga",
            ogTitle = "Existing Manga",
            source = 0L,
            favorite = true,
        )
        coEvery { getMangaByUrlAndSourceId.await("ExistingManga", 0L) } returns existingManga

        model.startImport(context, background = true)

        model.state.value.isBackgroundRunning shouldBe true
        model.state.value.progressTotal shouldBe 1
    }

    // ---------- 并发/多标题处理 ----------

    @Test
    fun `startImport with multiple titles sets progressTotal`() = runTest {
        val mockSource = mockk<eu.kanade.tachiyomi.source.CatalogueSource>(relaxed = true)
        every { sourceManager.getVisibleCatalogueSources() } returns listOf(mockSource)
        model.updateTitles("Title1\nTitle2\nTitle3")
        coEvery { getMangaByUrlAndSourceId.await(any(), 0L) } returns null

        model.startImport(context, background = true)

        model.state.value.progressTotal shouldBe 3
    }
}
