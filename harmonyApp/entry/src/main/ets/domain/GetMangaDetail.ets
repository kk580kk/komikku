import { Chapter, Manga, MangaDetail } from '../model/Manga';
import { MangaRepository } from '../data/MangaRepository';
import { ChapterRepository } from '../data/ChapterRepository';
import { AppError, fail, ok, Result } from '../util/Result';

/** 用例：读取详情页数据（条目 + 章节）。 */
export class GetMangaDetail {
  private mangaRepo: MangaRepository = new MangaRepository();
  private chapterRepo: ChapterRepository = new ChapterRepository();

  async execute(mangaId: number): Promise<Result<MangaDetail>> {
    const mangaResult = await this.mangaRepo.get(mangaId);
    if (!mangaResult.ok || mangaResult.data === undefined) {
      return fail<MangaDetail>(mangaResult.error ?? AppError.storage('条目不存在'));
    }
    const chaptersResult = await this.chapterRepo.byManga(mangaId);
    if (!chaptersResult.ok || chaptersResult.data === undefined) {
      return fail<MangaDetail>(chaptersResult.error ?? AppError.storage('读取章节失败'));
    }
    const manga: Manga = mangaResult.data;
    const chapters: Chapter[] = chaptersResult.data;
    return ok(new MangaDetail(manga, chapters));
  }
}
