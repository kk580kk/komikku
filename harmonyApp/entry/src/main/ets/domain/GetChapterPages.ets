import { Chapter, Manga } from '../model/Manga';
import { ChapterRepository } from '../data/ChapterRepository';
import { MangaRepository } from '../data/MangaRepository';
import { Page, SChapter, Source } from '../source/Source';
import { SourceRegistry } from '../source/SourceRegistry';
import { AppError, fail, ok, Result } from '../util/Result';

/** 阅读器数据：章节 + 页列表（页是可直接下载的图片地址）。 */
export class ChapterPages {
  chapter: Chapter;
  manga: Manga;
  pages: Page[];

  constructor(chapter: Chapter, manga: Manga, pages: Page[]) {
    this.chapter = chapter;
    this.manga = manga;
    this.pages = pages;
  }
}

/** 用例：打开一章 → 读库里的章节/条目 → 让源解析出页面列表。 */
export class GetChapterPages {
  private chapterRepo: ChapterRepository = new ChapterRepository();
  private mangaRepo: MangaRepository = new MangaRepository();

  async execute(chapterId: number): Promise<Result<ChapterPages>> {
    const chapterResult = await this.chapterRepo.byId(chapterId);
    if (!chapterResult.ok || chapterResult.data === undefined) {
      return fail<ChapterPages>(chapterResult.error ?? AppError.storage('章节不存在'));
    }
    const chapter: Chapter = chapterResult.data;

    const mangaResult = await this.mangaRepo.get(chapter.mangaId);
    if (!mangaResult.ok || mangaResult.data === undefined) {
      return fail<ChapterPages>(mangaResult.error ?? AppError.storage('条目不存在'));
    }
    const manga: Manga = mangaResult.data;

    const source: Source | undefined = SourceRegistry.get(manga.sourceId);
    if (source === undefined) {
      return fail<ChapterPages>(AppError.network('图源未注册: ' + manga.sourceId));
    }

    const sChapter: SChapter = new SChapter(
      chapter.url, chapter.name, chapter.chapterNumber, chapter.scanlator, chapter.dateUpload, chapter.sourceOrder);
    const pagesResult = await source.pages(sChapter);
    if (!pagesResult.ok || pagesResult.data === undefined) {
      return fail<ChapterPages>(pagesResult.error ?? AppError.parse('获取页面失败'));
    }
    return ok<ChapterPages>(new ChapterPages(chapter, manga, pagesResult.data));
  }
}
