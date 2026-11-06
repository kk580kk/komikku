import { Chapter, Manga } from '../model/Manga';
import { MangaRepository } from '../data/MangaRepository';
import { ChapterRepository } from '../data/ChapterRepository';
import { Source, SManga, SChapter } from '../source/Source';
import { SourceRegistry } from '../source/SourceRegistry';
import { AppError, fail, ok, Result } from '../util/Result';

/**
 * 用例：把源条目加入书架（拉详情 + 章节 → 落库 → 标记 favorite）。
 *
 * 对应 Android 端 BrowseSourceScreenModel 里 `favoriteManga` 的简化版；
 * 元数据与章节的抓取开关（fetchMetadataOnAdd / fetchChaptersOnAdd）留到 M5 再补。
 */
export class AddToLibrary {
  private mangaRepo: MangaRepository = new MangaRepository();
  private chapterRepo: ChapterRepository = new ChapterRepository();

  async execute(smanga: SManga): Promise<Result<number>> {
    const source: Source | undefined = SourceRegistry.get(smanga.sourceId);
    if (source === undefined) {
      return fail<number>(AppError.network('图源不存在: ' + smanga.sourceId));
    }

    const detailResult = await source.details(smanga);
    if (!detailResult.ok || detailResult.data === undefined) {
      return fail<number>(detailResult.error ?? AppError.parse('拉取详情失败'));
    }
    const detail: SManga = detailResult.data;

    const now: number = Date.now();
    const manga: Manga = new Manga(
      0,
      detail.sourceId,
      detail.url,
      detail.title,
      detail.author,
      detail.artist,
      detail.description,
      detail.genre,
      detail.status,
      detail.thumbnailUrl,
      true,
      0,
      now,
      now,
      ''
    );
    const upsert: Result<number> = await this.mangaRepo.upsert(manga);
    if (!upsert.ok || upsert.data === undefined) {
      return fail<number>(upsert.error ?? AppError.storage('保存条目失败'));
    }
    const mangaId: number = upsert.data;

    const chaptersResult = await source.chapters(detail);
    if (chaptersResult.ok && chaptersResult.data !== undefined) {
      const chapters: Chapter[] = chaptersResult.data.map((c: SChapter, index: number) => {
        return new Chapter(
          0,
          mangaId,
          c.url,
          c.name,
          c.scanlator,
          false,
          false,
          0,
          c.chapterNumber,
          index,
          Date.now(),
          c.dateUpload
        );
      });
      const saved = await this.chapterRepo.upsertAll(mangaId, chapters);
      if (!saved.ok) {
        return fail<number>(saved.error ?? AppError.storage('保存章节失败'));
      }
    }

    const fav = await this.mangaRepo.setFavorite(mangaId, true);
    if (!fav.ok) {
      return fail<number>(fav.error ?? AppError.storage('加入书架失败'));
    }
    return ok(mangaId);
  }
}
