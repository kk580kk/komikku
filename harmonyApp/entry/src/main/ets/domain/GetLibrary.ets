import { LibraryEntry } from '../model/Manga';
import { MangaRepository } from '../data/MangaRepository';
import { Result } from '../util/Result';

/** 用例：读取书架（可选标题关键字）。对应 Android 端 LibraryScreenModel 的查询分支。 */
export class GetLibrary {
  private repo: MangaRepository = new MangaRepository();

  async execute(query: string = ''): Promise<Result<LibraryEntry[]>> {
    return this.repo.library(query);
  }
}
